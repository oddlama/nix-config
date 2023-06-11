{
  extra.microvms.vms.kanidm = {
    system = "x86_64-linux";
    autostart = true;
    zfs = {
      enable = true;
      pool = "rpool";
    };
  };

  microvm.vms.kanidm.config = {
    config,
    lib,
    nodes,
    pkgs,
    utils,
    ...
  }: {
    age.rekey.hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2TxWynLb8V9SP45kFqsoCWhe/dG8N1xWNuJG5VQndq";

    extra.wireguard.proxy-sentinel.client.via = "sentinel";

    # TODO this as includable module?
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
          allowedTCPPorts = [8300];
        };
      };
    };

    age.secrets."kanidm-self-signed.crt" = {
      rekeyFile = ./secrets/kanidm-self-signed.crt.age;
      mode = "440";
      group = "kanidm";
    };

    age.secrets."kanidm-self-signed.key" = {
      rekeyFile = ./secrets/kanidm-self-signed.key.age;
      mode = "440";
      group = "kanidm";
    };

    services.kanidm = {
      enableServer = true;
      # enablePAM = true;
      serverSettings = {
        domain = "auth.${nodes.sentinel.config.repo.secrets.local.personalDomain}";
        origin = "https://${config.services.kanidm.serverSettings.domain}";
        tls_chain = config.age.secrets."kanidm-self-signed.crt".path;
        tls_key = config.age.secrets."kanidm-self-signed.key".path;
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

    systemd.services.kanidm.after = ["sys-subsystem-net-devices-${utils.escapeSystemdPath "proxy-sentinel"}.device"];
  };
}