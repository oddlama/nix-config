{
  config,
  lib,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  netbirdDomain = "netbird.${config.repo.secrets.global.domains.me}";
in {
  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [3000 3001];
  };

  # Mirror the original coturn password
  age.secrets.coturn-password-netbird = {
    inherit (sentinelCfg.age.secrets.coturn-password-netbird) rekeyFile;
  };

  age.secrets.coturn-secret = {
    generator.script = "alnum";
  };

  age.secrets.netbird-data-store-encryption-key = {
    generator.script = {pkgs, ...}: ''
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

      dashboard.settings.AUTH_AUTHORITY = "https://${sentinelCfg.networking.providedDomains.kanidm}/oauth2/openid/netbird";

      management = {
        port = 3000;
        dnsDomain = "internal.${config.repo.secrets.global.domains.me}";
        singleAccountModeDomain = "home.lan";
        oidcConfigEndpoint = "https://${sentinelCfg.networking.providedDomains.kanidm}/oauth2/openid/netbird/.well-known/openid-configuration";
        turnDomain = sentinelCfg.networking.providedDomains.coturn;
        turnPort = sentinelCfg.services.coturn.tls-listening-port;
        settings = {
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

  nodes.sentinel = {
    networking.providedDomains.netbird = netbirdDomain;

    services.nginx = {
      upstreams.netbird = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:80" = {};
        extraConfig = ''
          zone netbird 64k;
          keepalive 5;
        '';
      };
      upstreams.netbird-mgmt = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:3000" = {};
        extraConfig = ''
          zone netbird 64k;
          keepalive 5;
        '';
      };
      upstreams.netbird-signal = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:3001" = {};
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
            grpc_read_timeout 1d;
            grpc_send_timeout 1d;
            grpc_socket_keepalive on;
          '';

          "/api".proxyPass = "http://netbird-mgmt";

          "/management.ManagementService/".extraConfig = ''
            grpc_pass grpc://netbird-mgmt;
            grpc_read_timeout 1d;
            grpc_send_timeout 1d;
            grpc_socket_keepalive on;
          '';
        };

        extraConfig = ''
          client_max_body_size 500M ;
          client_header_timeout 1d;
          client_body_timeout 1d;
        '';
      };
    };
  };

  systemd.services.netbird-signal.serviceConfig.RestartSec = "60"; # Retry every minute
  systemd.services.netbird-management.serviceConfig.RestartSec = "60"; # Retry every minute
}
