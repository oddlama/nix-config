{
  config,
  globals,
  nodes,
  ...
}:
let
  mealieDomain = "mealie.${globals.domains.me}";
in
{
  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [ config.services.mealie.port ];
  };

  # Mirror the original oauth2 secret, but prepend OIDC_CLIENT_SECRET=
  # so it can be used as an EnvironmentFile
  age.secrets.oauth2-client-secret = {
    generator.dependencies = [
      nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-mealie
    ];
    generator.script =
      {
        lib,
        decrypt,
        deps,
        ...
      }:
      ''
        echo -n "OIDC_CLIENT_SECRET="
        ${decrypt} ${lib.escapeShellArg (lib.head deps).file}
      '';
    mode = "440";
  };

  globals.services.mealie.domain = mealieDomain;
  # FIXME: internal monitoring not possible because DNS resolves to sentinel
  # since adguardhome is not active in server's dns
  # globals.monitoring.http.mealie = {
  #   url = "https://${mealieDomain}";
  #   expectedBodyRegex = ''<title>Mealie'';
  #   network = "home-lan.vlans.services";
  # };

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
      OIDC_SIGNUP_ENABLED = "true";
      OIDC_AUTO_REDIRECT = "true";
      OIDC_REMEMBER_ME = "true";

      OIDC_CLIENT_ID = "mealie";
      OIDC_SIGNING_ALGORITHM = "ES256";
      OIDC_USER_CLAIM = "preferred_username";
      OIDC_PROVIDER_NAME = "Kanidm";
      OIDC_CONFIGURATION_URL = "https://${globals.services.kanidm.domain}/oauth2/openid/${OIDC_CLIENT_ID}/.well-known/openid-configuration";
      OIDC_USER_GROUP = "user";
      OIDC_ADMIN_GROUP = "admin";
    };
    credentialsFile = config.age.secrets.oauth2-client-secret.path;
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.mealie = {
        servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.mealie.port}" = { };
        extraConfig = ''
          zone mealie 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedStatus = 200;
          expectedBodyRegex = ''<title>Mealie'';
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
