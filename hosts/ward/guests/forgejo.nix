{
  config,
  lib,
  nodes,
  pkgs,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  # XXX: other domain on other proxy?
  forgejoDomain = "git.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  # TODO forward ssh port
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [
    config.services.gitea.settings.server.HTTP_PORT
  ];

  age.secrets.forgejo-mailer-password = {
    rekeyFile = config.node.secretsDir + "/forgejo-mailer-password.age";
    mode = "440";
    inherit (config.services.gitea) group;
  };

  # Mirror the original oauth2 secret
  age.secrets.forgejo-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-forgejo) rekeyFile;
    mode = "440";
    inherit (config.services.gitea) group;
  };

  nodes.sentinel = {
    networking.providedDomains.forgejo = forgejoDomain;

    # Make sure to masquerade 9922 (wan) -> 22 (proxy-sentinel)
    networking.nftables.chains = {
      forward.dnat = {
        after = ["conntrack"];
        rules = ["ct status dnat accept"];
      };
      postrouting.to-forgejo = {
        after = ["hook"];
        rules = [
          "iifname wan ip daddr ${config.meta.wireguard.proxy-sentinel.ipv4} tcp dport 22 masquerade random"
          "iifname wan ip6 daddr ${config.meta.wireguard.proxy-sentinel.ipv6} tcp dport 22 masquerade random"
        ];
      };
      prerouting.to-forgejo = {
        after = ["hook"];
        rules = [
          "iifname wan tcp dport 9922 dnat ip to ${config.meta.wireguard.proxy-sentinel.ipv4}:22"
          "iifname wan tcp dport 9922 dnat ip6 to ${config.meta.wireguard.proxy-sentinel.ipv6}:22"
        ];
      };
    };

    services.nginx = {
      upstreams.forgejo = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.gitea.settings.server.HTTP_PORT}" = {};
        extraConfig = ''
          zone forgejo 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${forgejoDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 512M;
        '';
        locations."/".proxyPass = "http://forgejo";
        locations."/metrics" = {
          proxyPass = "http://forgejo/metrics";
          extraConfig = ''
            allow 127.0.0.0/8;
            allow ::1;
            deny all;
            access_log off;
          '';
        };
      };
    };
  };

  # Recommended by forgejo: https://forgejo.org/docs/latest/admin/recommendations/#git-over-ssh
  services.openssh.settings.AcceptEnv = "GIT_PROTOCOL";

  environment.persistence."/persist".directories = [
    {
      directory = config.services.gitea.stateDir;
      user = "gitea";
      group = "gitea";
      mode = "0700";
    }
  ];

  services.gitea = {
    enable = true;
    package = pkgs.forgejo;
    appName = "Redlew Git"; # tungsten inert gas?
    stateDir = "/var/lib/forgejo";
    # TODO db backups
    # dump.enable = true;
    lfs.enable = true;
    mailerPasswordFile = config.age.secrets.forgejo-mailer-password.path;
    settings = {
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
      database = {
        SQLITE_JOURNAL_MODE = "WAL";
        LOG_SQL = false; # Leaks secrets
      };
      # federation.ENABLED = true;
      mailer = {
        ENABLED = true;
        HOST = config.repo.secrets.local.forgejo.mail.host;
        FROM = config.repo.secrets.local.forgejo.mail.from;
        USER = config.repo.secrets.local.forgejo.mail.user;
        SEND_AS_PLAIN_TEXT = true;
      };
      metrics = {
        # XXX: query with local telegraf
        ENABLED = true;
        ENABLED_ISSUE_BY_REPOSITORY = true;
        ENABLED_ISSUE_BY_LABEL = true;
      };
      oauth2_client = {
        ACCOUNT_LINKING = "auto";
        ENABLE_AUTO_REGISTRATION = true;
        OPENID_CONNECT_SCOPES = "email profile";
        REGISTER_EMAIL_CONFIRM = false;
        UPDATE_AVATAR = true;
      };
      # packages.ENABLED = true;
      repository = {
        DEFAULT_PRIVATE = "private";
        ENABLE_PUSH_CREATE_USER = true;
        ENABLE_PUSH_CREATE_ORG = true;
      };
      server = {
        HTTP_ADDR = "0.0.0.0";
        HTTP_PORT = 3000;
        DOMAIN = forgejoDomain;
        ROOT_URL = "https://${forgejoDomain}/";
        LANDING_PAGE = "login";
        SSH_PORT = 9922;
      };
      service = {
        DISABLE_REGISTRATION = false;
        ALLOW_ONLY_INTERNAL_REGISTRATION = false;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
        REGISTER_EMAIL_CONFIRM = false;
        ENABLE_NOTIFY_MAIL = true;
      };
      session.COOKIE_SECURE = true;
      ui.DEFAULT_THEME = "forgejo-auto";
      "ui.meta" = {
        AUTHOR = "Redlew Git";
        DESCRIPTION = "Tungsten Inert Gas?";
      };
    };
  };

  # XXX: PKCE is currently not supported by gitea/forgejo,
  # see https://github.com/go-gitea/gitea/issues/21376.
  # Disable PKCE manually in kanidm for now.
  # `kanidm system oauth2 warning-insecure-client-disable-pkce forgejo`
  systemd.services.gitea = {
    serviceConfig.RestartSec = "600"; # Retry every 10 minutes
    preStart = let
      exe = lib.getExe config.services.gitea.package;
      providerName = "kanidm";
      clientId = "forgejo";
      args = lib.escapeShellArgs [
        "--name"
        providerName
        "--provider"
        "openidConnect"
        "--key"
        clientId
        "--auto-discover-url"
        "https://${sentinelCfg.networking.providedDomains.kanidm}/oauth2/openid/${clientId}/.well-known/openid-configuration"
        #"--required-claim-name" "groups"
        #"--group-claim-name" "groups"
        #"--admin-group" "/forge_admins@${domain}"
        "--skip-local-2fa"
      ];
    in
      lib.mkAfter ''
        provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
        if [[ -z "$provider_id" ]]; then
          FORGEJO_ADMIN_OAUTH2_SECRET="$(< ${config.age.secrets.forgejo-oauth2-client-secret.path})" ${exe} admin auth add-oauth ${args}
        else
          FORGEJO_ADMIN_OAUTH2_SECRET="$(< ${config.age.secrets.forgejo-oauth2-client-secret.path})" ${exe} admin auth update-oauth --id "$provider_id" ${args}
        fi
      '';
  };
}
