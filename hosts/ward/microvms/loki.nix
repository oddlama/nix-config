{
  config,
  nodes,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  lokiDomain = "loki.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [config.services.loki.configuration.server.http_listen_port];

  nodes.sentinel = {
    networking.providedDomains.loki = lokiDomain;

    age.secrets.loki-basic-auth-hashes = {
      generator.script = "basic-auth";
      mode = "440";
      group = "nginx";
    };

    services.nginx = {
      upstreams.loki = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString config.services.loki.configuration.server.http_listen_port}" = {};
        extraConfig = ''
          zone loki 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${lokiDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://loki";
          proxyWebsockets = true;
          extraConfig = ''
            auth_basic "Authentication required";
            auth_basic_user_file ${sentinelCfg.age.secrets.loki-basic-auth-hashes.path};

            proxy_read_timeout 1800s;
            proxy_connect_timeout 1600s;

            access_log off;
          '';
        };
        locations."= /ready" = {
          proxyPass = "http://loki";
          extraConfig = ''
            auth_basic off;
            access_log off;
          '';
        };
      };
    };
  };

  services.loki = let
    lokiDir = "/var/lib/loki";
  in {
    enable = true;
    configuration = {
      analytics.reporting_enabled = false;
      auth_enabled = false;

      server = {
        http_listen_address = "0.0.0.0";
        http_listen_port = 3100;
        log_level = "warn";
      };

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
          final_sleep = "0s";
        };
        chunk_idle_period = "5m";
        chunk_retain_period = "30s";
      };

      schema_config.configs = [
        {
          from = "2023-06-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v12";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "${lokiDir}/tsdb-index";
          cache_location = "${lokiDir}/tsdb-cache";
          cache_ttl = "24h";
          shared_store = "filesystem";
        };
        filesystem.directory = "${lokiDir}/chunks";
      };

      # Do not accept new logs that are ingressed when they are actually already old.
      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };

      # Do not delete old logs automatically
      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = lokiDir;
        shared_store = "filesystem";
        compactor_ring.kvstore.store = "inmemory";
      };
    };
  };

  systemd.services.loki.serviceConfig.RestartSec = "600"; # Retry every 10 minutes
}
