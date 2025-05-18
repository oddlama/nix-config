{
  config,
  globals,
  nodes,
  ...
}:
let
  mealieDomain = "mealie.${globals.domains.personal}";
in
{
  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [ config.services.mealie.port ];
  };

  # Mirror the original oauth2 secret
  age.secrets.mealie-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-mealie) rekeyFile;
    mode = "440";
  };

  globals.services.mealie.domain = mealieDomain;
  globals.monitoring.http.mealie = {
    url = "https://${mealieDomain}";
    # FIXME: todooooooooooo
    expectedBodyRegex = "TODO";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/mealie";
      mode = "0700";
    }
  ];

  services.mealie = {
    enable = true;
    settings = rec {
      ALLOW_SIGNUP = "false";
      BASE_URL = "https://${mealieDomain}";
      TZ = config.time.timeZone;

      TOKEN_TIME = 87600; # 10 years session time - this is only internal so who cares
      OIDC_AUTH_ENABLED = "true";
      OIDC_AUTO_REDIRECT = "true";
      OIDC_CLIENT_ID = "mealie";
      OIDC_CONFIGURATION_URL = "https://${globals.services.kanidm.domain}/oauth2/openid/${OIDC_CLIENT_ID}/.well-known/openid-configuration";
      OIDC_SIGNUP_ENABLED = "true";
      OIDC_USER_GROUP = "user";
      OIDC_ADMIN_GROUP = "admin";
    };
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.mealie = {
        servers."${config.wireguard.proxy-home.ipv4}:${config.services.mealie.port}" = { };
        extraConfig = ''
          zone mealie 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          # FIXME: todooooooooooo
          expectedBodyRegex = "TODO";
        };
      };
      virtualHosts.${mealieDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        extraConfig = ''
          client_max_body_size 128M;
        '';
        locations."/".proxyPass = "http://mealie";
      };
    };
  };
}
