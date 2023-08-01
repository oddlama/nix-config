{
  config,
  lib,
  nodes,
  pkgs,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  forgejoDomain = "git.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  # TODO forward ssh port
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [
    config.services.gitea.settings.server.HTTP_PORT
  ];

  age.secrets.forgejo-mailer-password = {
    rekeyFile = config.node.secretsDir + "/forgejo-mailer-password.age";
    mode = "400";
    group = "forgejo";
  };

  nodes.sentinel = {
    networking.providedDomains.forgejo = forgejoDomain;

    services.nginx = {
      upstreams.forgejo = {
        servers."${config.services.gitea.settings.server.HTTP_ADDR}:${toString config.services.gitea.settings.server.HTTP_PORT}" = {};
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

  # XXX: TODO ssh if not using internal
  # AcceptEnv GIT_PROTOCOL

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
        DEFAULT_ACTIONS_URL = "https://gitea.com";
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
        DEFAULT_PRIVATE = false;
        ENABLE_PUSH_CREATE_USER = true;
        ENABLE_PUSH_CREATE_ORG = true;
      };
      server = {
        HTTP_ADDR = config.meta.wireguard.proxy-sentinel.ipv4;
        HTTP_PORT = 3000;
        DOMAIN = forgejoDomain;
        ROOT_URL = "https://${forgejoDomain}/";
        LANDING_PAGE = "/explore/repos";
        SSH_PORT = 9922;
      };
      service = {
        DISABLE_REGISTRATION = false;
        ALLOW_ONLY_INTERNAL_REGISTRATION = false;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
        REGISTER_EMAIL_CONFIRM = false;
        ENABLE_NOTIFY_MAIL = true;
        REQUIRE_SIGNIN_VIEW = false;
      };
      session.COOKIE_SECURE = true;
      ui.DEFAULT_THEME = "forgejo-auto";
      "ui.meta" = {
        AUTHOR = "Redlew Git";
        DESCRIPTION = "Tungsten Inert Gas?";
      };
    };
  };

  systemd.services.gitea = {
    after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
    serviceConfig.RestartSec = "600"; # Retry every 10 minutes
    #preStart = let
    #  exe = lib.getExe config.services.gitea.package;
    #  providerName = "PrivateVoidAccount";
    #  args = lib.escapeShellArgs [
    #    "--name" providerName
    #    "--provider" "openidConnect"
    #    "--key" "net.privatevoid.forge1"
    #    "--auto-discover-url" "https://login.${domain}/auth/realms/master/.well-known/openid-configuration"
    #    "--group-claim-name" "groups"
    #    "--admin-group" "/forge_admins@${domain}"
    #    "--skip-local-2fa"
    #  ];
    #in lib.mkAfter /* bash */ ''
    #  provider_id=$(${exe} admin auth list | ${pkgs.gnugrep}/bin/grep -w '${providerName}' | cut -f1)
    #  if [[ -z "$provider_id" ]]; then
    #    FORGEJO_ADMIN_OAUTH2_SECRET="$(< ${secrets.forgejoOidcSecret.path})" ${exe} admin auth add-oauth ${args}
    #  else
    #    FORGEJO_ADMIN_OAUTH2_SECRET="$(< ${secrets.forgejoOidcSecret.path})" ${exe} admin auth update-oauth --id "$provider_id" ${args}
    #  fi
    #'';
  };
}
