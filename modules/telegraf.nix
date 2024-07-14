{
  config,
  globals,
  lib,
  minimal,
  nodes,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatLists
    elem
    flip
    forEach
    mapAttrsToList
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalAttrs
    optionals
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

    secrets = mkOption {
      type = types.attrsOf types.path;
      default = {};
      example = {
        "@INFLUX_TOKEN@" = "/run/agenix/influx-token";
      };
      description = "Additional secrets to replace in pre-start. The attr name will be searched and replaced in the config with the value read from the given file.";
    };

    globalMonitoring = {
      enable = mkEnableOption "monitor the global infrastructure from this node.";
      availableNetworks = mkOption {
        type = types.listOf types.str;
        example = ["internet"];
        description = ''
          The networks that can be reached from this node.
          Only global entries with a matching network will be monitored from here.
        '';
      };
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
      mode = "440";
      group = "telegraf";
    };

    meta.telegraf.secrets."@INFLUX_TOKEN@" = config.age.secrets.telegraf-influxdb-token.path;

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
            token = "@INFLUX_TOKEN@";
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
          }
          // optionalAttrs cfg.globalMonitoring.enable {
            ping = concatLists (flip mapAttrsToList globals.monitoring.ping (
              name: pingCfg:
                optionals (elem pingCfg.network cfg.globalMonitoring.availableNetworks) (
                  concatLists (forEach ["hostv4" "hostv6"] (
                    attr:
                      optional (pingCfg.${attr} != null) {
                        method = "native";
                        urls = [pingCfg.${attr}];
                        ipv4 = attr == "hostv4";
                        ipv6 = attr == "hostv6";
                        tags = {
                          inherit name;
                          inherit (pingCfg) location network;
                          ip_version =
                            if attr == "hostv4"
                            then "v4"
                            else "v6";
                        };
                        fieldpass = [
                          "percent_packet_loss"
                          "average_response_ms"
                        ];
                      }
                  ))
                )
            ));

            http_response = concatLists (flip mapAttrsToList globals.monitoring.http (
              name: httpCfg:
                optional (elem httpCfg.network cfg.globalMonitoring.availableNetworks) {
                  urls = [httpCfg.url];
                  method = "GET";
                  response_status_code = httpCfg.expectedStatus;
                  response_string_match = mkIf (httpCfg.expectedBodyRegex != null) httpCfg.expectedBodyRegex;
                  tags = {
                    inherit name;
                    inherit (httpCfg) location network;
                  };
                }
            ));

            dns_query = concatLists (flip mapAttrsToList globals.monitoring.dns (
              name: dnsCfg:
                optional (elem dnsCfg.network cfg.globalMonitoring.availableNetworks) {
                  servers = [dnsCfg.server];
                  domains = [dnsCfg.domain];
                  record_type = dnsCfg.record-type;
                  tags = {
                    inherit name;
                    inherit (dnsCfg) location network;
                  };
                }
            ));

            net_response = concatLists (flip mapAttrsToList globals.monitoring.tcp (
              name: tcpCfg:
                optional (elem tcpCfg.network cfg.globalMonitoring.availableNetworks) {
                  address = "${tcpCfg.host}:${toString tcpCfg.port}";
                  protocol = "tcp";
                  tags = {
                    inherit name;
                    inherit (tcpCfg) location network;
                  };
                  fieldexclude = ["result_type" "string_found"];
                }
            ));
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
        ExecStartPre = mkAfter [
          (
            pkgs.writeShellScript "pre-start-token" (lib.concatLines (
              lib.flip lib.mapAttrsToList config.meta.telegraf.secrets (
                key: secret: ''
                  ${lib.getExe pkgs.replace-secret} \
                    ${lib.escapeShellArg key} \
                    ${lib.escapeShellArg secret} \
                    /var/run/telegraf/config.toml
                ''
              )
            ))
          )
        ];
        # For wireguard statistics
        AmbientCapabilities = ["CAP_NET_ADMIN"];
        RestartSec = "60"; # Retry every minute
      };
    };
  };
}
