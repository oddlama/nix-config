{
  config,
  lib,
  nodes,
  pkgs,
  ...
}: let
  inherit (config.repo.secrets.local) acme personalDomain;
in {
  users.groups.acme.members = ["caddy"];

  services.caddy = let
    authDomain = nodes.ward-nginx.config.services.kanidm.serverSettings.domain;
    authPort = lib.last (lib.splitString ":" nodes.ward-nginx.config.services.kanidm.serverSettings.bindaddress);
    grafanaDomain = nodes.ward-test.config.services.grafana.settings.server.domain;
    grafanaPort = toString nodes.ward-test.config.services.grafana.settings.server.http_port;
    lokiDomain = "loki.${personalDomain}";
    lokiPort = toString nodes.ward-loki.config.services.loki.configuration.server.http_listen_port;
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

    globalConfig = ''
      servers {
        metrics
      }
    '';

    # TODO move subconfigs to the relevant hosts instead.
    # -> have something like merged config nodes.<name>....

    virtualHosts.${authDomain} = {
      useACMEHost = config.lib.extra.matchingWildcardCert authDomain;
      extraConfig = ''
        encode zstd gzip
        reverse_proxy * {
          to https://${nodes.ward-nginx.config.extra.wireguard.proxy-sentinel.ipv4}:${authPort}
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';
    };

    virtualHosts.${grafanaDomain} = {
      useACMEHost = config.lib.extra.matchingWildcardCert grafanaDomain;
      extraConfig = ''
        encode zstd gzip
        reverse_proxy * {
          to http://${nodes.ward-test.config.extra.wireguard.proxy-sentinel.ipv4}:${grafanaPort}
        }
      '';
    };

    virtualHosts.${lokiDomain} = {
      useACMEHost = config.lib.extra.matchingWildcardCert lokiDomain;
      # TODO disable access log
      # TODO auth
      # TODO no auth for /ready
      extraConfig = ''
        encode zstd gzip
        reverse_proxy * {
          to http://${nodes.ward-loki.config.extra.wireguard.proxy-sentinel.ipv4}:${lokiPort}
          websocket
        }
      '';
    };
  };
}
