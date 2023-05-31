{
  config,
  nodes,
  ...
}: let
  inherit (config.repo.secrets.local) acme personalDomain;
in {
  networking.domain = personalDomain;

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

  rekey.secrets."dhparams.pem" = {
    file = ./secrets/dhparams.pem.age;
    mode = "440";
    group = "nginx";
  };

  services.nginx = let
    authDomain = nodes.ward-nginx.config.services.kanidm.serverSettings.domain;
  in {
    enable = true;
    upstreams."kanidm" = {
      servers."${nodes.ward-nginx.config.extra.wireguard.proxy-sentinel.ipv4}:8300" = {};
      extraConfig = ''
        zone kanidm 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${authDomain} = {
      forceSSL = true;
      useACMEHost = config.lib.extra.matchingWildcardCert authDomain;
      locations."/".proxyPass = "https://kanidm";
      # Allow using self-signed certs to satisfy kanidm's requirement
      # for TLS connections. (This is over wireguard anyway)
      # TODO can we get rid of this?
      extraConfig = ''
        proxy_ssl_verify off;
      '';
    };
  };
}
