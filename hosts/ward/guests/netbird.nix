{
  config,
  globals,
  lib,
  nodes,
  ...
}:
let
  sentinelCfg = nodes.sentinel.config;
  netbirdDomain = "netbird.${globals.domains.me}";
in
{
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [
      config.services.netbird.server.management.port
      config.services.netbird.server.signal.port
    ];
  };

  # Mirror the original coturn password
  age.secrets.coturn-password-netbird = {
    inherit (sentinelCfg.age.secrets.coturn-password-netbird) rekeyFile;
  };

  age.secrets.coturn-secret = {
    generator.script = "alnum";
  };

  age.secrets.netbird-data-store-encryption-key = {
    generator.script =
      { pkgs, ... }:
      ''
        ${lib.getExe pkgs.openssl} rand -base64 32
      '';
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/netbird-mgmt";
      mode = "640";
      user = "netbird";
      group = "netbird";
    }
  ];

  services.netbird = {
    server = {
      enable = true;
      domain = netbirdDomain;

      dashboard.settings.AUTH_AUTHORITY = "https://${globals.services.kanidm.domain}/oauth2/openid/netbird";

      management = {
        singleAccountModeDomain = "internal.${globals.domains.me}";
        dnsDomain = "internal.${globals.domains.me}";
        disableAnonymousMetrics = true;
        oidcConfigEndpoint = "https://${globals.services.kanidm.domain}/oauth2/openid/netbird/.well-known/openid-configuration";
        turnDomain = globals.services.coturn.domain;
        turnPort = sentinelCfg.services.coturn.tls-listening-port;
        settings = {
          HttpConfig = {
            # Audience must be set here, otherwise the grpc server will not initialize the jwt validator causing:
            # failed validating JWT token sent from peer [...] no jwt validator set
            AuthAudience = "netbird";
          };
          TURNConfig = {
            Secret._secret = config.age.secrets.coturn-secret.path;
            Turns = [
              {
                Proto = "udp";
                URI = "turn:${config.services.netbird.server.management.turnDomain}:${builtins.toString config.services.netbird.server.management.turnPort}";
                Username = "netbird";
                Password._secret = config.age.secrets.coturn-password-netbird.path;
              }
            ];
          };
          DataStoreEncryptionKey._secret = config.age.secrets.netbird-data-store-encryption-key.path;
        };
      };
    };
  };

  globals.services.netbird.domain = netbirdDomain;
  globals.monitoring.http.netbird = {
    url = "https://${netbirdDomain}/api/users";
    expectedStatus = 401;
    expectedBodyRegex = "no valid authentication";
    network = "internet";
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.netbird-mgmt = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${builtins.toString config.services.netbird.server.management.port}" =
          { };
        extraConfig = ''
          zone netbird 64k;
          keepalive 5;
        '';
        monitoring = {
          enable = true;
          path = "/api/users";
          expectedStatus = 401;
          expectedBodyRegex = "no valid authentication";
        };
      };

      upstreams.netbird-signal = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${builtins.toString config.services.netbird.server.signal.port}" =
          { };
        extraConfig = ''
          zone netbird 64k;
          keepalive 5;
        '';
      };

      virtualHosts.${netbirdDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;

        locations = {
          "/" = {
            root = config.services.netbird.server.dashboard.finalDrv;
            tryFiles = "$uri $uri.html $uri/ =404";
            X-Frame-Options = "SAMEORIGIN";
          };

          "/signalexchange.SignalExchange/".extraConfig = ''
            grpc_pass grpc://netbird-signal;
            grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            grpc_read_timeout 1d;
            grpc_send_timeout 1d;
            grpc_socket_keepalive on;
          '';

          "/api".proxyPass = "http://netbird-mgmt";

          "/management.ManagementService/".extraConfig = ''
            grpc_pass grpc://netbird-mgmt;
            grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            grpc_read_timeout 1d;
            grpc_send_timeout 1d;
            grpc_socket_keepalive on;
          '';
        };

        # client_body_timeout is necessary so that grpc connections do not get closed early, see https://stackoverflow.com/a/67805465
        extraConfig = ''
          client_header_timeout 1d;
          client_body_timeout 1d;
          client_max_body_size 512M;
        '';
      };
    };
  };

  systemd.services.netbird-signal.serviceConfig.RestartSec = "60"; # Retry every minute
  systemd.services.netbird-management.serviceConfig.RestartSec = "60"; # Retry every minute
}
