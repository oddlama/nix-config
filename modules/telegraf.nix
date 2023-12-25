{
  config,
  lib,
  minimal,
  nodes,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.meta.telegraf;
in {
  options.meta.telegraf = {
    enable = mkEnableOption "telegraf to push metrics to influx.";

    scrapeSensors = mkOption {
      type = types.bool;
      default = true;
      description = "Scrape sensors with lm_sensors. You should disable this for virtualized hosts.";
    };

    influxdb2 = {
      domain = mkOption {
        type = types.str;
        example = "influxdb.example.com";
        description = "The influxdb v2 database to push to. https will be enforced.";
      };

      organization = mkOption {
        type = types.str;
        description = "The organization to push to.";
      };

      bucket = mkOption {
        type = types.str;
        description = "The bucket to push to.";
      };

      user = mkOption {
        type = types.str;
        default = "admin";
        description = "The user for which the api key should be created.";
      };

      node = mkOption {
        type = types.str;
        description = "The node which hosts the influxdb service (used to provision an api token).";
      };
    };
  };

  config = mkIf (!minimal && cfg.enable) {
    assertions = [
      {
        assertion = !config.boot.isContainer;
        message = "Containers don't support telegraf because memlock is not enabled.";
      }
    ];

    nodes.${cfg.influxdb2.node} = {
      # Mirror the original secret on the influx host
      age.secrets."telegraf-influxdb-token-${config.node.name}" = {
        inherit (config.age.secrets.telegraf-influxdb-token) rekeyFile;
        mode = "440";
        group = "influxdb2";
      };

      services.influxdb2.provision.organizations.machines.auths."telegraf (${config.node.name})" = {
        readBuckets = ["telegraf"];
        writeBuckets = ["telegraf"];
        tokenFile = nodes.${cfg.influxdb2.node}.config.age.secrets."telegraf-influxdb-token-${config.node.name}".path;
      };
    };

    age.secrets.telegraf-influxdb-token = {
      generator.script = "alnum";
      generator.tags = ["influxdb"];
      mode = "440";
      group = "telegraf";
    };

    security.elewrap.telegraf-sensors = mkIf cfg.scrapeSensors {
      command = ["${pkgs.lm_sensors}/bin/sensors" "-A" "-u"];
      targetUser = "root";
      allowedUsers = ["telegraf"];
    };

    security.elewrap.telegraf-nvme = mkIf config.services.smartd.enable {
      command = ["${pkgs.nvme-cli}/bin/nvme"];
      targetUser = "root";
      allowedUsers = ["telegraf"];
      passArguments = true;
    };

    security.elewrap.telegraf-smartctl = mkIf config.services.smartd.enable {
      command = ["${pkgs.smartmontools}/bin/smartctl"];
      targetUser = "root";
      allowedUsers = ["telegraf"];
      passArguments = true;
    };

    services.telegraf = {
      enable = true;
      environmentFiles = ["/dev/null"]; # Needed so the config file is copied to /run/telegraf
      extraConfig = {
        agent = {
          interval = "10s";
          round_interval = true; # Always collect on :00,:10,...
          metric_batch_size = 5000;
          metric_buffer_limit = 50000;
          collection_jitter = "0s";
          flush_interval = "20s";
          flush_jitter = "5s";
          precision = "1ms";
          hostname = config.node.name;
          omit_hostname = false;
        };
        outputs = {
          influxdb_v2 = {
            urls = ["https://${cfg.influxdb2.domain}"];
            token = "$INFLUX_TOKEN";
            inherit (cfg.influxdb2) organization bucket;
          };
        };
        inputs =
          {
            conntrack = {};
            cpu = {};
            disk = {};
            diskio = {};
            internal = {};
            interrupts = {};
            kernel = {};
            kernel_vmstat = {};
            linux_sysctl_fs = {};
            mem = {};
            net = {
              ignore_protocol_stats = true;
            };
            netstat = {};
            nstat = {};
            processes = {};
            swap = {};
            system = {};
            systemd_units = {
              unittype = "service";
            };
            temp = {};
            wireguard = {};
            # http_response = { urls = [ "http://localhost/" ]; };
            # ping = { urls = [ "9.9.9.9" ]; };
          }
          // optionalAttrs config.services.smartd.enable {
            sensors = {};
            smart = {
              attributes = true;
              path_nvme = config.security.elewrap.telegraf-nvme.path;
              path_smartctl = config.security.elewrap.telegraf-smartctl.path;
              use_sudo = false;
            };
          }
          // optionalAttrs config.services.nginx.enable {
            nginx.urls = ["http://localhost/nginx_status"];
          }
          // optionalAttrs (config.networking.wireless.enable || config.networking.wireless.iwd.enable) {
            wireless = {};
          };
      };
    };

    services.nginx.virtualHosts = mkIf config.services.nginx.enable {
      localhost.listenAddresses = ["127.0.0.1" "[::1]"];
      localhost.locations."= /nginx_status".extraConfig = ''
        allow 127.0.0.0/8;
        allow ::1;
        deny all;
        stub_status;
        access_log off;
      '';
    };

    environment.persistence."/persist".directories = [
      {
        directory = "/var/lib/telegraf";
        user = "telegraf";
        group = "telegraf";
        mode = "0700";
      }
    ];

    systemd.services.telegraf = {
      path = [
        # Make sensors refer to the correct wrapper
        (mkIf cfg.scrapeSensors
          (pkgs.writeShellScriptBin "sensors" config.security.elewrap.telegraf-sensors.path))
      ];
      serviceConfig = {
        Environment = "INFLUX_TOKEN=\$INFLUX_TOKEN"; # Required so the first envsubst in the original module doesn't change it
        ExecStartPre = mkAfter [
          (pkgs.writeShellScript "pre-start-token" ''
            export INFLUX_TOKEN=$(< ${config.age.secrets.telegraf-influxdb-token.path})
            ${pkgs.envsubst}/bin/envsubst -i /var/run/telegraf/config.toml -o /var/run/telegraf/config.toml
          '')
        ];
        # For wireguard statistics
        AmbientCapabilities = ["CAP_NET_ADMIN"];
        RestartSec = "600"; # Retry every 10 minutes
      };
    };
  };
}
