{
  config,
  lib,
  nodes,
  pkgs,
  utils,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  kanidmDomain = "auth.${sentinelCfg.repo.secrets.local.personalDomain}";
in {
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

  nodes.sentinel = {
    proxiedDomains.kanidm = kanidmDomain;

    services.caddy.virtualHosts.${kanidmDomain} = {
      useACMEHost = sentinelCfg.lib.extra.matchingWildcardCert kanidmDomain;
      extraConfig = ''
        encode zstd gzip
        reverse_proxy {
          to https://${config.services.kanidm.serverSettings.bindaddress}
          transport http {
            tls_insecure_skip_verify
          }
        }
      '';
    };
  };

  services.kanidm = {
    enableServer = true;
    # enablePAM = true;
    serverSettings = {
      domain = kanidmDomain;
      origin = "https://${kanidmDomain}";
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
