{
  config,
  globals,
  lib,
  nodes,
  pkgs,
  ...
}: let
  forgejoDomain = "git.${config.repo.secrets.global.domains.me}";
in {
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.forgejo.settings.server.HTTP_PORT];
  };

  age.secrets.forgejo-mailer-password = {
    rekeyFile = config.node.secretsDir + "/forgejo-mailer-password.age";
    mode = "440";
    inherit (config.services.forgejo) group;
  };

  # Mirror the original oauth2 secret
  age.secrets.forgejo-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-forgejo) rekeyFile;
    mode = "440";
    inherit (config.services.forgejo) group;
  };

  globals.services.forgejo.domain = forgejoDomain;
  nodes.sentinel = {
    # Rewrite destination addr with dnat on incoming connections
    # and masquerade responses to make them look like they originate from this host.
    # - 9922 (wan) -> 22 (proxy-sentinel)
    networking.nftables.chains = {
      postrouting.to-forgejo = {
        after = ["hook"];
        rules = [
          "iifname wan ip daddr ${config.wireguard.proxy-sentinel.ipv4} tcp dport 22 masquerade random"
          "iifname wan ip6 daddr ${config.wireguard.proxy-sentinel.ipv6} tcp dport 22 masquerade random"
        ];
      };
      prerouting.to-forgejo = {
        after = ["hook"];
        rules = [
          "iifname wan tcp dport 9922 dnat ip to ${config.wireguard.proxy-sentinel.ipv4}:22"
          "iifname wan tcp dport 9922 dnat ip6 to ${config.wireguard.proxy-sentinel.ipv6}:22"
        ];
      };
    };

    services.nginx = {
      upstreams.forgejo = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.forgejo.settings.server.HTTP_PORT}" = {};
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

  users.groups.git = {};
  users.users.git = {
    isSystemUser = true;
    useDefaultShell = true;
    group = "git";
    home = config.services.forgejo.stateDir;
  };

  services.openssh = {
    authorizedKeysFiles = lib.mkForce [
      "${config.services.forgejo.stateDir}/.ssh/authorized_keys"
    ];
    # Recommended by forgejo: https://forgejo.org/docs/latest/admin/recommendations/#git-over-ssh
    settings.AcceptEnv = "GIT_PROTOCOL";
  };

  environment.persistence."/persist".directories = [
    {
      directory = config.services.forgejo.stateDir;
      inherit (config.services.forgejo) user group;
      mode = "0700";
    }
  ];

  services.forgejo = {
    enable = true;
    # TODO db backups
    # dump.enable = true;
    user = "git";
    group = "git";
    lfs.enable = true;
    mailerPasswordFile = config.age.secrets.forgejo-mailer-password.path;
    settings = {
      DEFAULT.APP_NAME = "Redlew Git"; # tungsten inert gas?
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
        SMTP_ADDR = config.repo.secrets.local.forgejo.mail.host;
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
        # Never use auto account linking with this, otherwise users cannot change
        # their new user name and they could potentially overtake other users accounts
        # by setting their email address to an existing account.
        # With "login" linking the user must choose a non-existing username first or login
        # with the existing account to link.
        ACCOUNT_LINKING = "login";
        USERNAME = "nickname";
        # This does not mean that you cannot register via oauth, but just that there should
        # be a confirmation dialog shown to the user before the account is actually created.
        # This dialog allows changing user name and email address before creating the account.
        ENABLE_AUTO_REGISTRATION = false;
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
        SSH_USER = "git";
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

  systemd.services.forgejo = {
    serviceConfig.RestartSec = "60"; # Retry every minute
    preStart = let
      exe = lib.getExe config.services.forgejo.package;
      providerName = "kanidm";
      clientId = "forgejo";
      args = lib.escapeShellArgs (lib.concatLists [
        ["--name" providerName]
        ["--provider" "openidConnect"]
        ["--key" clientId]
        ["--auto-discover-url" "https://${globals.services.kanidm.domain}/oauth2/openid/${clientId}/.well-known/openid-configuration"]
        ["--scopes" "email"]
        ["--scopes" "profile"]
        ["--group-claim-name" "groups"]
        ["--admin-group" "admin"]
        ["--skip-local-2fa"]
      ]);
    in
      lib.mkAfter ''
        provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
        SECRET="$(< ${config.age.secrets.forgejo-oauth2-client-secret.path})"
        if [[ -z "$provider_id" ]]; then
          ${exe} admin auth add-oauth ${args} --secret "$SECRET"
        else
          ${exe} admin auth update-oauth --id "$provider_id" ${args} --secret "$SECRET"
        fi
      '';
  };
}
