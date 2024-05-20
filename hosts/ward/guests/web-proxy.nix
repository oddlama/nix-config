{config, ...}: let
  inherit (config.repo.secrets.local) acme;
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

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;
}
