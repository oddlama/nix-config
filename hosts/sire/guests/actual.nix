{
  config,
  globals,
  lib,
  pkgs,
  nodes,
  ...
}:
let
  actualDomain = "finance.${globals.domains.me}";
  client_id = "actual";
in
{
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [ config.services.actual.settings.port ];
  };

  # Mirror the original oauth2 secret
  age.secrets.actual-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-actual) rekeyFile;
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/actual";
      mode = "0700";
    }
  ];

  services.actual = {
    enable = true;
    settings.trustedProxies = [ nodes.sentinel.config.wireguard.proxy-sentinel.ipv4 ];
  };

  # NOTE: state: to enable openid, we need to call their enable-openid script once
  # which COPIES this data to the database :( so changing these values later will
  # require manual intervention.
  systemd.services.actual = {
    serviceConfig.ExecStart = lib.mkForce [
      (pkgs.writeShellScript "start-actual" ''
        export ACTUAL_OPENID_CLIENT_SECRET=$(< "$CREDENTIALS_DIRECTORY"/oauth2-client-secret)
        exec ${lib.getExe config.services.actual.package}
      '')
    ];
    serviceConfig.LoadCredential = [
      "oauth2-client-secret:${config.age.secrets.actual-oauth2-client-secret.path}"
    ];
    environment = {
      ACTUAL_OPENID_ENFORCE = "true";
      ACTUAL_TOKEN_EXPIRATION = "openid-provider";

      ACTUAL_OPENID_DISCOVERY_URL = "https://${globals.services.kanidm.domain}/oauth2/openid/${client_id}/.well-known/openid-configuration";
      ACTUAL_OPENID_CLIENT_ID = client_id;
      ACTUAL_OPENID_SERVER_HOSTNAME = "https://${actualDomain}";
    };
  };

  globals.services.actual.domain = actualDomain;
  globals.monitoring.http.actual = {
    url = "https://${actualDomain}/";
    expectedBodyRegex = "Actual";
    network = "internet";
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.actual = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.actual.settings.port}" =
          { };
        extraConfig = ''
          zone actual 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "Actual";
        };
      };
      virtualHosts.${actualDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        # oauth2 = {
        #   enable = true;
        #   allowedGroups = ["access_openwebui"];
        #   X-Email = "\${upstream_http_x_auth_request_preferred_username}@${globals.domains.personal}";
        # };
        extraConfig = ''
          client_max_body_size 256M;
        '';
        locations."/" = {
          proxyPass = "http://actual";
          proxyWebsockets = true;
        };
      };
    };
  };
}
