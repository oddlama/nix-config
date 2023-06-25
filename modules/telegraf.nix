{
  config,
  lib,
  nodeName,
  nodePath,
  nodes,
  pkgs,
  ...
}: let
  inherit
    (lib)
    mdDoc
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    types
    ;

  cfg = config.extra.telegraf;
in {
  options.extra.telegraf = {
    enable = mkEnableOption (mdDoc "telegraf to push metrics to influx.");
    influxdb2 = {
      domain = mkOption {
        type = types.str;
        example = "influxdb.example.com";
        description = mdDoc "The influxdb v2 database to push to. https will be enforced.";
      };

      organization = mkOption {
        type = types.str;
        description = mdDoc "The organization to push to.";
      };

      bucket = mkOption {
        type = types.str;
        description = mdDoc "The bucket to push to.";
      };
    };
  };

  config = mkIf cfg.enable {
    age.secrets.telegraf-influxdb-token = {
      rekeyFile = nodePath + "/secrets/telegraf-influxdb-token.age";
      # TODO generator.script = { pkgs, lib, decrypt, deps, ... }: let
      # TODO   adminBasicAuth = (builtins.head deps).file;
      # TODO   adminToken = (builtins.head deps).file; # TODO ..... filter by name?
      # TODO in ''
      # TODO   echo " -> Provisioning influxdb token for [34mtelegraf[m on [32m${nodeName}[m at [33mhttps://${cfg.influxdb2.domain}[m" >&2
      # TODO   ${decrypt} ${lib.escapeShellArg aba.file} \
      # TODO   INFLUX_HOST=https://${aba.host}+${aba.name}:${PW}@${URL}
      # TODO     | ${pkgs.influxdb2-cli}/bin/influx -niBC 12 ${lib.escapeShellArg host}"+"${lib.escapeShellArg name} \
      # TODO     || die "Failure"
      # TODO '');
      mode = "440";
      group = "telegraf";
    };

    services.telegraf = {
      enable = true;
      environmentFiles = [config.age.secrets.telegraf-influxdb-token.path];
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
          hostname = nodeName;
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
            net = {};
            netstat = {};
            nstat = {};
            processes = {};
            sensors = {};
            swap = {};
            system = {};
            systemd_units = {unittype = "service";};
            temp = {};
            wireguard = {};
            # http_response = { urls = [ "http://localhost/" ]; };
            # ping = { urls = [ "9.9.9.9" ]; };
          }
          // optionalAttrs config.services.smartd.enable {
            smart = {
              path_nvme = "${pkgs.nvme-cli}/bin/nvme";
              path_smartctl = "${pkgs.smartmontools}/bin/smartctl";
              use_sudo = true;
            };
            # TODO } // optionalAttrs config.services.iwd.enable {
            # TODO   wireless = { };
          };
      };
    };

    systemd.services.telegraf = {
      path = [
        "/run/wrappers"
        pkgs.lm_sensors
      ];
      serviceConfig = {
        # For wireguard statistics
        AmbientCapabilities = ["CAP_NET_ADMIN"];
        RestartSec = "600"; # Retry every 10 minutes
      };
    };
  };
}
