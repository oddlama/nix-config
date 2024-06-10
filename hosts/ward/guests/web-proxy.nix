{
  config,
  globals,
  ...
}: let
  inherit (config.repo.secrets.local) acme;
  fritzboxDomain = "fritzbox.${config.repo.secrets.global.domains.me}";
in {
  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForAll.allowedTCPPorts = [80 443];
  };

  age.secrets.acme-cloudflare-dns-token = {
    rekeyFile = config.node.secretsDir + "/acme-cloudflare-dns-token.age";
    mode = "440";
    group = "acme";
  };

  age.secrets.acme-cloudflare-zone-token = {
    rekeyFile = config.node.secretsDir + "/acme-cloudflare-zone-token.age";
    mode = "440";
    group = "acme";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      credentialFiles = {
        CF_DNS_API_TOKEN_FILE = config.age.secrets.acme-cloudflare-dns-token.path;
        CF_ZONE_API_TOKEN_FILE = config.age.secrets.acme-cloudflare-zone-token.path;
      };
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      reloadServices = ["nginx"];
    };
    inherit (acme) certs wildcardDomains;
  };

  services.nginx = {
    upstreams.fritzbox = {
      servers.${globals.net.home-wan.hosts.fritzbox.ipv4} = {};
      extraConfig = ''
        zone grafana 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${fritzboxDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      locations."/" = {
        proxyPass = "http://fritzbox";
        proxyWebsockets = true;
      };
      # Allow using self-signed certs. We just want to make sure the connection
      # is over TLS.
      extraConfig = ''
        proxy_ssl_verify off;
        allow ${globals.net.home-lan.cidrv4};
        allow ${globals.net.home-lan.cidrv6};
        deny all;
      '';
    };
  };

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;
}
