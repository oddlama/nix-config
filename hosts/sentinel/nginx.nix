{config, ...}: let
  inherit (config.repo.secrets.local) acme personalDomain;
in {
  networking.domain = personalDomain;

  rekey.secrets."dhparams.pem" = {
    file = ./secrets/dhparams.pem.age;
    mode = "440";
    group = "nginx";
  };

  rekey.secrets.acme-credentials = {
    file = ./secrets/acme-credentials.age;
    mode = "440";
    group = "acme";
  };

  #security.acme = {
  #  acceptTerms = true;
  #  defaults = {
  #    inherit (acme) email;
  #    credentialsFile = config.rekey.secrets.acme-credentials.path;
  #    dnsProvider = "cloudflare";
  #    dnsPropagationCheck = true;
  #    reloadServices = ["nginx"];
  #  };
  #};
  #extra.acme.wildcardDomains = acme.domains;
  #users.groups.acme.members = ["nginx"];

  #services.nginx = {
  #  enable = true;
  #  upstreams."kanidm" = {
  #    servers."${config.extra.wireguard."${parentNodeName}-local-vms".ipv4}:8300" = {};
  #    extraConfig = ''
  #      zone kanidm 64k;
  #      keepalive 2;
  #    '';
  #  };
  #  virtualHosts.${authDomain} = {
  #    forceSSL = true;
  #    useACMEHost = config.lib.extra.matchingWildcardCert authDomain;
  #    locations."/".proxyPass = "https://kanidm";
  #    # Allow using self-signed certs to satisfy kanidm's requirement
  #    # for TLS connections. (This is over wireguard anyway)
  #    extraConfig = ''
  #      proxy_ssl_verify off;
  #    '';
  #  };
  #};
}
