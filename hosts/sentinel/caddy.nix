{
  config,
  lib,
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

  services.caddy = let
    authDomain = nodes.ward-nginx.config.services.kanidm.serverSettings.domain;
    authPort = lib.last (lib.splitString ":" nodes.ward-nginx.config.services.kanidm.serverSettings.bindaddress);
    grafanaDomain = nodes.ward-test.config.services.grafana.settings.server.domain;
    grafanaPort = toString nodes.ward-test.config.services.grafana.settings.server.http_port;
    lokiDomain = "loki.${personalDomain}";
    lokiPort = toString nodes.ward-loki.config.services.loki.settings.server.http_port;
  in {
  };
}
