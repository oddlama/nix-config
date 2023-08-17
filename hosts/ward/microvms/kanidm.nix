{
  config,
  lib,
  nodes,
  pkgs,
  ...
}: let
  sentinelCfg = nodes.sentinel.config;
  kanidmDomain = "auth.${sentinelCfg.repo.secrets.local.personalDomain}";
  kanidmPort = 8300;
in {
  meta.wireguard-proxy.sentinel.allowedTCPPorts = [kanidmPort];

  age.secrets."kanidm-self-signed.crt" = {
    rekeyFile = config.node.secretsDir + "/kanidm-self-signed.crt.age";
    mode = "440";
    group = "kanidm";
  };

  age.secrets."kanidm-self-signed.key" = {
    rekeyFile = config.node.secretsDir + "/kanidm-self-signed.key.age";
    mode = "440";
    group = "kanidm";
  };

  nodes.sentinel = {
    networking.providedDomains.kanidm = kanidmDomain;

    services.nginx = {
      upstreams.kanidm = {
        servers."${config.meta.wireguard.proxy-sentinel.ipv4}:${toString kanidmPort}" = {};
        extraConfig = ''
          zone kanidm 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${kanidmDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/".proxyPass = "https://kanidm";
        # Allow using self-signed certs to satisfy kanidm's requirement
        # for TLS connections. (Although this is over wireguard anyway)
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
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
      bindaddress = "0.0.0.0:${toString kanidmPort}";
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

  systemd.services.grafana.serviceConfig.RestartSec = "60"; # Retry every minute
}
