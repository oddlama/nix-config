{
  config,
  lib,
  nodes,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  lokiDomain = "loki.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  extra.promtail = {
    enable = true;
    proxy = "sentinel";
  };

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [config.services.loki.configuration.server.http_listen_port];
  };

  nodes.sentinel = {
    proxiedDomains.loki = lokiDomain;

    age.secrets.loki-basic-auth-hashes = {
      rekeyFile = ./secrets/loki-basic-auth-hashes.age;
      # Copy only the script so the dependencies can be added by the nodes
      # that define passwords (using distributed-config).
      generator.script = config.age.generators.basic-auth.script;
      mode = "440";
      group = "caddy";
    };

    services.caddy.virtualHosts.${lokiDomain} = {
      useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert lokiDomain;
      extraConfig = ''
        import common
        skip_log
        basicauth {
          import ${sentinelCfg.age.secrets.loki-basic-auth-hashes.path}
        }
        reverse_proxy {
          to http://${config.services.loki.configuration.server.http_listen_address}:${toString config.services.loki.configuration.server.http_listen_port}
          header_up X-Real-IP {remote_host}
        }
      '';
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
        http_listen_address = config.extra.wireguard.proxy-sentinel.ipv4;
        http_listen_port = 3100;
        log_level = "warn";
      };

      ingester = {
        lifecycler = {
          interface_names = ["proxy-sentinel"];
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

  systemd.services.loki.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
}
