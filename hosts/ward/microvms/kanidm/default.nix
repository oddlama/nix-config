{
  config,
  lib,
  nodes,
  pkgs,
  utils,
  ...
}: {
  imports = [
    ../../../../modules/proxy-via-sentinel.nix
  ];

  networking.nftables.firewall.rules = lib.mkForce {
    sentinel-to-local.allowedTCPPorts = [8300];
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
      domain = nodes.sentinel.config.proxiedDomains.kanidm;
      origin = "https://${nodes.sentinel.config.proxiedDomains.kanidm}";
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
}
