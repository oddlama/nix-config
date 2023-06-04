{
  config,
  nodes,
  nixos-hardware,
  pkgs,
  ...
}: let
  inherit (nodes.sentinel.config.repo.secrets.local) personalDomain;
  authDomain = "auth.${personalDomain}";
  grafanaDomain = "grafana.${personalDomain}";
  lokiDir = "/var/lib/loki";
in {
  imports = [
    nixos-hardware.common-cpu-intel
    nixos-hardware.common-pc-ssd

    ../common/core
    ../common/hardware/intel.nix
    ../common/hardware/physical.nix
    ../common/initrd-ssh.nix
    ../common/efi.nix
    ../common/zfs.nix

    ./fs.nix
    ./net.nix
  ];

  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" "r8169"];

  extra.microvms.vms = let
    defineVm = {
      system = "x86_64-linux";
      autostart = true;
      zfs = {
        enable = true;
        pool = "rpool";
      };
    };
  in {
    test = defineVm;
    #ddclient = defineVm;
    nginx = defineVm;
    loki = defineVm;
    #kanidm = defineVm;
    #gitea/forgejo = defineVm;
    #vaultwarden = defineVm;
    #samba+wsdd = defineVm;
    #fasten-health = defineVm;
    #immich = defineVm;
    #paperless = defineVm;
    #radicale = defineVm;
    #minecraft = defineVm;

    #grafana
    #loki

    #maddy = defineVm;
    #anonaddy = defineVm;

    #automatic1111 = defineVm;
    #invokeai = defineVm;
  };

  microvm.vms.test.config = {
    lib,
    config,
    parentNodeName,
    ...
  }: {
    rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBXXjI6uB26xOF0DPy/QyLladoGIKfAtofyqPgIkCH/g";

    extra.wireguard.proxy-sentinel.client.via = "sentinel";

    networking.nftables.firewall = {
      zones = lib.mkForce {
        proxy-sentinel.interfaces = ["proxy-sentinel"];
        sentinel = {
          parent = "proxy-sentinel";
          ipv4Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv4];
          ipv6Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv6];
        };
      };

      rules = lib.mkForce {
        sentinel-to-local = {
          from = ["sentinel"];
          to = ["local"];
          allowedTCPPorts = [3001];
        };
      };
    };

    rekey.secrets.grafana-secret-key = {
      file = ./secrets/grafana-secret-key.age;
      mode = "440";
      group = "grafana";
    };

    services.grafana = {
      enable = true;
      settings = {
        analytics.reporting_enabled = false;
        users.allow_sign_up = false;

        server = {
          domain = grafanaDomain;
          root_url = "https://${config.services.grafana.settings.server.domain}";
          enforce_domain = true;
          enable_gzip = true;
          http_addr = config.extra.wireguard.proxy-sentinel.ipv4;
          http_port = 3001;
          # cert_key = /etc/grafana/grafana.key;
          # cert_file = /etc/grafana/grafana.crt;
          # protocol = "https"
        };

        security = {
          disable_initial_admin_creation = true;
          secret_key = "$__file{${config.rekey.secrets.grafana-secret-key.path}}";
          cookie_secure = true;
          disable_gravatar = true;
          hide_version = true;
        };

        auth.disable_login_form = true;
        "auth.generic_oauth" = {
          enabled = true;
          name = "Kanidm";
          icon = "signin";
          allow_sign_up = true;
          auto_login = true;
          client_id = "grafana";
          #client_secret = "$__file{${config.rekey.secrets.grafana-oauth-client-secret.path}}";
          client_secret = "r6Yk5PPSXFfYDPpK6TRCzXK8y1rTrfcb8F7wvNC5rZpyHTMF"; # TODO temporary test not a real secret
          scopes = "openid profile email";
          login_attribute_path = "prefered_username";
          auth_url = "https://${authDomain}/ui/oauth2";
          token_url = "https://${authDomain}/oauth2/token";
          api_url = "https://${authDomain}/oauth2/openid/grafana/userinfo";
          use_pkce = true;
          # Allow mapping oauth2 roles to server admin
          allow_assign_grafana_admin = true;
          role_attribute_path = "contains(scopes[*], 'server_admin') && 'GrafanaAdmin' || contains(scopes[*], 'admin') && 'Admin' || contains(scopes[*], 'editor') && 'Editor' || 'Viewer'";
        };
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          #{
          #  name = "Prometheus";
          #  type = "prometheus";
          #  url = "http://127.0.0.1:9090";
          #  orgId = 1;
          #}
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://${nodes."${parentNodeName}-loki".config.extra.wireguard."${parentNodeName}-local-vms".ipv4}:3100";
            orgId = 1;
          }
        ];
      };
    };
  };

  microvm.vms.nginx.config = {
    lib,
    config,
    ...
  }: {
    rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2TxWynLb8V9SP45kFqsoCWhe/dG8N1xWNuJG5VQndq";

    extra.wireguard.proxy-sentinel.client.via = "sentinel";

    networking.nftables.firewall = {
      zones = lib.mkForce {
        #local-vms.interfaces = ["local-vms"];
        proxy-sentinel.interfaces = ["proxy-sentinel"];
        sentinel = {
          parent = "proxy-sentinel";
          ipv4Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv4];
          ipv6Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv6];
        };
      };

      rules = lib.mkForce {
        sentinel-to-local = {
          from = ["sentinel"];
          to = ["local"];
          allowedTCPPorts = [8300];
        };
      };
    };

    rekey.secrets."kanidm-self-signed.crt" = {
      file = ./secrets/kanidm-self-signed.crt.age;
      mode = "440";
      group = "kanidm";
    };
    rekey.secrets."kanidm-self-signed.key" = {
      file = ./secrets/kanidm-self-signed.key.age;
      mode = "440";
      group = "kanidm";
    };

    services.kanidm = {
      enableServer = true;
      # enablePAM = true;
      serverSettings = {
        domain = authDomain;
        origin = "https://${config.services.kanidm.serverSettings.domain}";
        tls_chain = config.rekey.secrets."kanidm-self-signed.crt".path;
        tls_key = config.rekey.secrets."kanidm-self-signed.key".path;
        bindaddress = "${config.extra.wireguard.proxy-sentinel.ipv4}:8300";
        trust_x_forward_for = true;
      };
    };

    environment.systemPackages = [pkgs.kanidm];

    services.kanidm = {
      enableClient = true;
      clientSettings = {
        uri = config.services.kanidm.serverSettings.origin;
        verify_ca = true;
        verify_hostnames = true;
      };
    };
  };

  microvm.vms.loki.config = {
    lib,
    config,
    parentNodeName,
    utils,
    ...
  }: {
    rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDDvvF3+KwfoZrPAUAt2HS7y5FM9S5Mr1iRkBUqoXno";

    networking.nftables.firewall = {
      zones = lib.mkForce {
        #local-vms.interfaces = ["local-vms"];
        proxy-sentinel.interfaces = ["proxy-sentinel"];
        sentinel = {
          parent = "proxy-sentinel";
          ipv4Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv4];
          ipv6Addresses = [nodes.sentinel.config.extra.wireguard.proxy-sentinel.ipv6];
        };
      };

      rules = lib.mkForce {
        sentinel-to-local = {
          from = ["sentinel"];
          to = ["local"];
          allowedTCPPorts = [3100];
        };
      };
    };

    services.loki = {
      enable = true;
      configuration = {
        analytics.reporting_enabled = false;
        auth_enabled = false;

        server = {
          http_listen_address = config.extra.wireguard."${parentNodeName}-local-vms".ipv4;
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

    # TODO this for other vms and services too?
    systemd.services.loki.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "local-vms"}.device"];
  };
}
