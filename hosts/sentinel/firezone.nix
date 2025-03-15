{
  config,
  globals,
  lib,
  ...
}:
let
  firezoneDomain = "firezone.${globals.domains.me}";
  homeDomains = [
    globals.services.grafana.domain
    globals.services.immich.domain
    globals.services.influxdb.domain
    globals.services.loki.domain
    globals.services.paperless.domain
    globals.services.esphome.domain
    globals.services.home-assistant.domain
    "fritzbox.${globals.domains.personal}"
  ];

  allow = group: resource: {
    "${group}@${resource}" = {
      inherit group resource;
      description = "Allow ${group} access to ${resource}";
    };
  };
in
{
  age.secrets.firezone-smtp-password = {
    generator.script = "alnum";
    mode = "440";
    group = "firezone";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/firezone";
      mode = "0700";
    }
  ];

  globals.services.firezone.domain = firezoneDomain;
  globals.monitoring.http.firezone = {
    url = "https://${firezoneDomain}/";
    network = "internet";
    expectedBodyRegex = "Welcome to Firezone";
  };

  services.firezone.server = {
    enable = true;
    enableLocalDB = true;

    smtp = {
      inherit (config.repo.secrets.local.firezone.mail) from host username;
      port = 465;
      implicitTls = true;
      passwordFile = config.age.secrets.firezone-smtp-password.file;
    };

    provision = {
      enable = true;
      accounts.main = {
        name = "Home";
        relayGroups.relays.name = "Relays";
        gatewayGroups.home.name = "Home";
        actors.admin = {
          type = "account_admin_user";
          name = "Admin";
          email = "admin@${globals.domains.me}";
        };

        # FIXME: dont hardcode, filter global service domains by internal state
        # FIXME: new entry here? make new adguardhome entry too.
        resources =
          lib.genAttrs homeDomains (domain: {
            type = "dns";
            name = domain;
            address = domain;
            gatewayGroups = [ "home" ];
            filters = [
              { protocol = "icmp"; }
              {
                protocol = "tcp";
                ports = [
                  443
                  80
                ];
              }
              {
                protocol = "udp";
                ports = [ 443 ];
              }
            ];
          })
          // {
            "home.vlan-services.v4" = {
              type = "cidr";
              name = "home.vlan-services.v4";
              address = globals.net.home-lan.vlans.services.cidrv4;
              gatewayGroups = [ "home" ];
            };
            "home.vlan-services.v6" = {
              type = "cidr";
              name = "home.vlan-services.v6";
              address = globals.net.home-lan.vlans.services.cidrv6;
              gatewayGroups = [ "home" ];
            };
          };

        policies =
          { }
          // allow "everyone" "home.vlan-services.v4"
          // allow "everyone" "home.vlan-services.v6"
          // lib.genAttrs homeDomains (domain: allow "everyone" domain);
      };
    };

    api.externalUrl = "https://${firezoneDomain}/api/";
    web.externalUrl = "https://${firezoneDomain}/";
  };

  services.nginx = {
    upstreams.firezone = {
      servers."127.0.0.1:${toString config.services.firezone.server.web.port}" = { };
      extraConfig = ''
        zone firezone 64k;
        keepalive 2;
      '';
      monitoring = {
        enable = true;
        expectedBodyRegex = "Welcome to Firezone";
      };
    };
    upstreams.firezone-api = {
      servers."127.0.0.1:${toString config.services.firezone.server.api.port}" = { };
      extraConfig = ''
        zone firezone 64k;
        keepalive 2;
      '';
      monitoring = {
        enable = true;
        expectedStatus = 404;
        expectedBodyRegex = ''{"error":{"reason":"Not Found"}}'';
      };
    };
    virtualHosts.${firezoneDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      locations."/" = {
        # The trailing slash is important to strip the location prefix from the request
        proxyPass = "http://firezone/";
        proxyWebsockets = true;
      };
      locations."/api/" = {
        # The trailing slash is important to strip the location prefix from the request
        proxyPass = "http://firezone-api/";
        proxyWebsockets = true;
      };
    };
  };
}
