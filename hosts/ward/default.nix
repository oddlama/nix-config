{
  config,
  nixos-hardware,
  pkgs,
  ...
}: let
  # TODO byebyebye
  # TODO byebyebye
  # TODO byebyebye
  # TODO byebyebye
  # TODO byebyebye
  # TODO byebyebye
  # TODO byebyebye
  # TODO byebyebye
  # TODO byebyebye
  inherit (config.repo.secrets.local) acme;
  auth.domain = config.repo.secrets.local.auth.domain;
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
    rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBXXjI6uB26xOF0DPy/QyLladoGIKfAtofyqPgIkCH/g";
  };

  microvm.vms.nginx.config = {
    lib,
    config,
    parentNodeName,
    ...
  }: {
    rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2TxWynLb8V9SP45kFqsoCWhe/dG8N1xWNuJG5VQndq";

    rekey.secrets."dhparams.pem" = {
      # TODO make own?
      file = ../zackbiene/secrets/dhparams.pem.age;
      mode = "440";
      group = "nginx";
    };

    rekey.secrets.acme-credentials = {
      file = ./secrets/acme-credentials.age;
      mode = "440";
      group = "acme";
    };

    security.acme = {
      acceptTerms = true;
      defaults = {
        inherit (acme) email;
        credentialsFile = config.rekey.secrets.acme-credentials.path;
        dnsProvider = "cloudflare";
        dnsPropagationCheck = true;
        reloadServices = ["nginx"];
      };
    };
    extra.acme.wildcardDomains = acme.domains;
    users.groups.acme.members = ["nginx"];
    services.nginx.enable = true;

    services.nginx = {
      upstreams."kanidm" = {
        servers."${config.extra.wireguard."${parentNodeName}-local-vms".ipv4}:8300" = {};
        extraConfig = ''
          zone kanidm 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${auth.domain} = {
        forceSSL = true;
        useACMEHost = config.lib.extra.matchingWildcardCert auth.domain;
        locations."/".proxyPass = "https://kanidm";
        # Allow using self-signed certs to satisfy kanidm's requirement
        # for TLS connections. (This is over wireguard anyway)
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };

    networking.nftables.firewall = {
      zones = lib.mkForce {
        local-vms.interfaces = ["local-vms"];
      };

      rules = lib.mkForce {
        local-vms-to-local = {
          from = ["local-vms"];
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
        inherit (auth) domain;
        origin = "https://${config.services.kanidm.serverSettings.domain}";
        #tls_chain = "/run/credentials/kanidm.service/fullchain.pem";
        #tls_key = "/run/credentials/kanidm.service/key.pem";
        tls_chain = config.rekey.secrets."kanidm-self-signed.crt".path;
        tls_key = config.rekey.secrets."kanidm-self-signed.key".path;
        bindaddress = "${config.extra.wireguard."${parentNodeName}-local-vms".ipv4}:8300";
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
