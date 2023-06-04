{config, ...}: let
  inherit (config.repo.secrets.local) acme;
in {
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
}
