{config, ...}: let
  inherit (config.repo.secrets.local) acme;
in {
  age.secrets.acme-credentials = {
    rekeyFile = ./secrets/acme-credentials.age;
    mode = "440";
    group = "acme";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      inherit (acme) email;
      credentialsFile = config.age.secrets.acme-credentials.path;
      dnsProvider = "cloudflare";
      dnsPropagationCheck = true;
      reloadServices = ["nginx"];
    };
  };
  security.acme.wildcardDomains = acme.domains;
}
