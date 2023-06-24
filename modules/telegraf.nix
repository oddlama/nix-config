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
    proxy = mkOption {
      type = types.str;
      description = mdDoc "The node name of the proxy server which provides the influx api endpoint.";
    };
  };

  config = mkIf cfg.enable {
    # Connect safely via wireguard to skip authentication
    networking.hosts.${nodes.${cfg.proxy}.config.extra.wireguard."proxy-${cfg.proxy}".ipv4} = [nodes.${cfg.proxy}.config.proxiedDomains.influxdb];

    age.secrets.telegraf-influxdb-token = {
      rekeyFile = nodePath + "/secrets/telegraf-influxdb-token.age";
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
            urls = ["https://${nodes.${cfg.proxy}.config.proxiedDomains.influxdb}"];
            token = "$INFLUX_TOKEN";
            organization = "servers";
            bucket = "telegraf";
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
      # For wireguard statistics
      serviceConfig.AmbientCapabilities = ["CAP_NET_ADMIN"];
    };
  };
}
