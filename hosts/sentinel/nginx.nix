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

  services.nginx = let
    authDomain = nodes.ward-nginx.config.services.kanidm.serverSettings.domain;
    authPort = lib.last (lib.splitString ":" nodes.ward-nginx.config.services.kanidm.serverSettings.bindaddress);
    grafanaDomain = nodes.ward-test.config.services.grafana.settings.server.domain;
    grafanaPort = toString nodes.ward-test.config.services.grafana.settings.server.http_port;
    lokiDomain = "loki.${personalDomain}";
    lokiPort = toString nodes.ward-loki.config.services.loki.settings.server.http_port;
  in {
    enable = true;

    # TODO move subconfigs to the relevant hosts instead.
    # -> have something like merged config nodes.<name>....

    upstreams.kanidm = {
      servers."${nodes.ward-nginx.config.extra.wireguard.proxy-sentinel.ipv4}:${authPort}" = {};
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

    upstreams.grafana = {
      servers."${nodes.ward-test.config.extra.wireguard.proxy-sentinel.ipv4}:${grafanaPort}" = {};
      extraConfig = ''
        zone grafana 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${grafanaDomain} = {
      forceSSL = true;
      useACMEHost = config.lib.extra.matchingWildcardCert grafanaDomain;
      locations."/".proxyPass = "http://grafana";
    };

    upstreams.loki = {
      servers."${nodes.ward-loki.config.extra.wireguard.proxy-sentinel.ipv4}:${lokiPort}" = {};
      extraConfig = ''
        zone loki 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${lokiDomain} = {
      forceSSL = true;
      useACMEHost = config.lib.extra.matchingWildcardCert lokiDomain;
      locations."/" = {
        proxyPass = "http://loki";
        proxyWebsockets = true;
        extraConfig = ''
          access_log off;
        '';
      };
      locations."/ready" = {
        proxyPass = "http://loki";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request off;
          access_log off;
        '';
      };
    };
  };
}
