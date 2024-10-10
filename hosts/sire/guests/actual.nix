{
  config,
  globals,
  nodes,
  ...
}: let
  actualDomain = "finance.${globals.domains.me}";
in {
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.actual.settings.port];
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/actual";
      mode = "0700";
      user = "actual";
      group = "actual";
    }
  ];

  services.actual = {
    enable = true;
    settings.trustedProxies = [nodes.sentinel.config.wireguard.proxy-sentinel.ipv4];
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
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.actual.settings.port}" = {};
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
