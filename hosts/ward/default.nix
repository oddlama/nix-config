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
    defineVm = id: {
      inherit id;
      system = "x86_64-linux";
      autostart = true;
      zfs = {
        enable = true;
        pool = "rpool";
      };
    };
  in {
    test = defineVm 11;
    #ddclient = defineVm 11;
    nginx = defineVm 12;
    #kanidm = defineVm 13;
    #gitea = defineVm 14;
    #vaultwarden = defineVm 15;
    #samba+wsdd = defineVm 16;
    #fasten-health = defineVm 17;
    #immich = defineVm 18;
    #paperless = defineVm 19;
    #radicale = defineVm 20;
    #minecraft = defineVm 21;

    #grafana
    #loki

    #maddy = defineVm 19;
    #anonaddy = defineVm 19;

    #automatic1111 = defineVm 19;
    #invokeai = defineVm 19;
  };

  microvm.vms.test.config = {
    lib,
    config,
    ...
  }: {
    rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBXXjI6uB26xOF0DPy/QyLladoGIKfAtofyqPgIkCH/g";

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

        auth = {
          signout_redirect_url = "https://sso.nycode.dev/if/session-end/grafana/";
          disable_login_form = true;
        };

        "auth.generic_oauth" = {
          enabled = true;
          name = "Kanidm";
          icon = "signin";
          allow_sign_up = true;
          auto_login = false;
          client_id = "grafana";
          client_secret = "$__file{${config.rekey.secrets.grafana-oauth-client-secret.path}}";
          scopes = "openid profile email";
          login_attribute_path = "prefered_username";
          auth_url = "https://${authDomain}/ui/oauth2";
          token_url = "https://${authDomain}/oauth2/token";
          api_url = "https://${authDomain}/oauth2/openid/grafana/userinfo";
          use_pkce = true;
          allow_assign_grafana_admin = true;
        };

        # TODO provision
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

      #rules = lib.mkForce {
      #  local-vms-to-local = {
      #    from = ["local-vms"];
      #    to = ["local"];
      #    allowedTCPPorts = [8300];
      #  };
      #};

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
}
