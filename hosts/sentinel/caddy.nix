{
  config,
  pkgs,
  ...
}: {
  users.groups.acme.members = ["caddy"];

  age.secrets.caddy-env = {
    rekeyFile = ./secrets/caddy-env.age;
    mode = "440";
    group = "caddy";
  };

  services.caddy = let
    proxyAuthDomain = "sentinel.${config.repo.secrets.local.personalDomain}";
  in {
    enable = true;
    package = pkgs.caddy.withPackages {
      plugins = [
        {
          name = "github.com/greenpau/caddy-security";
          version = "v1.1.18";
        }
      ];
      vendorHash = "sha256-RqSXQihtY5+ACaMo7bLdhu1A+qcraexb1W/Ia+aUF1k";
    };

    virtualHosts.${proxyAuthDomain} = {
      useACMEHost = config.lib.extra.matchingWildcardCert proxyAuthDomain;
      extraConfig = ''
        import common
        authenticate with myportal
      '';
    };

    globalConfig = ''
      order authenticate before respond
      order authorize before basicauth

      security {
        oauth identity provider kanidm {
          realm kanidm
          driver generic
          client_id web-sentinel
          client_secret {env.KANIDM_CLIENT_SECRET}
          scopes openid email profile
          base_auth_url https://${config.proxiedDomains.kanidm}/ui/oauth2
          metadata_url https://${config.proxiedDomains.kanidm}/oauth2/openid/sentinel/.well-known/openid-configuration
        }

        authentication portal myportal {
          enable identity provider kanidm
          cookie domain ${config.repo.secrets.local.personalDomain}
          ui {
            links {
              "My Identity" "/whoami" icon "las la-user"
            }
          }

          transform user {
            match realm kanidm
            action add role authp/user
          }

          #transform user {
          #  match realm kanidm
          #  match scope read:access_aguardhome
          #  action add role authp/admin
          #}
        }
    '';
  };

  systemd.services.caddy.serviceConfig.environmentFile = config.age.secrets.caddy-env.path;
}
