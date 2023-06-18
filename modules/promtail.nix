{
  config,
  lib,
  nodeName,
  nodePath,
  nodes,
  ...
}: let
  inherit
    (lib)
    mdDoc
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.extra.promtail;
in {
  options.extra.promtail = {
    enable = mkEnableOption (mdDoc "Enable promtail to push logs to a loki instance.");
    proxy = mkOption {
      type = types.str;
      description = mdDoc "The node name of the proxy server which provides the https loki api endpoint.";
    };
  };

  config = mkIf cfg.enable {
    age.secrets.promtail-loki-basic-auth-password = {
      rekeyFile = nodePath + "/secrets/promtail-loki-basic-auth-password.age";
      generator = "alnum";
      mode = "440";
      group = "promtail";
    };

    nodes.${cfg.proxy}.age.secrets.loki-basic-auth-hashes.generator.dependencies = [
      config.age.secrets.promtail-loki-basic-auth-password
    ];

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
          log_level = "warn";
        };

        clients = [
          {
            basic_auth.username = nodeName;
            basic_auth.password_file = config.age.secrets.promtail-loki-basic-auth-password.path;
            url = "https://${nodes.${cfg.proxy}.config.proxiedDomains.loki}/loki/api/v1/push";
          }
        ];

        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              json = true;
              max_age = "24h";
              labels.job = "systemd-journal";
            };
            pipeline_stages = [
              {
                json.expressions = {
                  transport = "_TRANSPORT";
                  unit = "_SYSTEMD_UNIT";
                  msg = "MESSAGE";
                  coredump_cgroup = "COREDUMP_CGROUP";
                  coredump_exe = "COREDUMP_EXE";
                  coredump_cmdline = "COREDUMP_CMDLINE";
                  coredump_uid = "COREDUMP_UID";
                  coredump_gid = "COREDUMP_GID";
                };
              }
              {
                # Set the unit (defaulting to the transport like audit and kernel)
                template = {
                  source = "unit";
                  template = "{{if .unit}}{{.unit}}{{else}}{{.transport}}{{end}}";
                };
              }
              {
                regex = {
                  expression = "(?P<coredump_unit>[^/]+)$";
                  source = "coredump_cgroup";
                };
              }
              {
                template = {
                  source = "msg";
                  template = "{{if .coredump_exe}}{{.coredump_exe}} core dumped (user: {{.coredump_uid}}/{{.coredump_gid}}, command: {{.coredump_cmdline}}){{else}}{{.msg}}{{end}}";
                };
              }
              {
                labels.coredump_unit = "coredump_unit";
              }
              {
                # Normalize session IDs (session-1234.scope -> session.scope) to limit number of label values
                replace = {
                  source = "unit";
                  expression = "^(session-\\d+.scope)$";
                  replace = "session.scope";
                };
              }
              {
                labels.unit = "unit";
              }
              {
                # Write the proper message instead of JSON
                output.source = "msg";
              }
            ];
            relabel_configs = [
              {
                source_labels = ["__journal__hostname"];
                target_label = "host";
              }
              {
                source_labels = ["__journal_priority"];
                target_label = "priority";
              }
              {
                source_labels = ["__journal_priority_keyword"];
                target_label = "level";
              }
              #{
              #  source_labels = ["__journal__systemd_unit"];
              #  target_label = "unit";
              #}
              {
                source_labels = ["__journal__systemd_user_unit"];
                target_label = "user_unit";
              }
              {
                source_labels = ["__journal__boot_id"];
                target_label = "boot_id";
              }
              {
                source_labels = ["__journal__comm"];
                target_label = "command";
              }
            ];
          }
        ];
      };
    };
  };
}
