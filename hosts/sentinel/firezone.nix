{
  config,
  globals,
  lib,
  nodes,
  ...
}:
let
  firezoneDomain = "firezone.${globals.domains.me}";
  # FIXME: dont hardcode, filter global service domains by internal state
  # FIXME: new entry here? make new adguardhome entry too.
  # FIXME: new entry here? make new firezone gateway on ward entry too.
  homeDomains = [
    globals.services.grafana.domain
    globals.services.ente.domain
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
  age.secrets.firezone-smtp-password.generator.script = "alnum";

  # NOTE: state: this token is from a manually created service account
  age.secrets.firezone-relay-token = {
    rekeyFile = config.node.secretsDir + "/firezone-relay-token.age";
  };

  # Mirror the original oauth2 secret
  age.secrets.firezone-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-firezone) rekeyFile;
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
      passwordFile = config.age.secrets.firezone-smtp-password.path;
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

        auth.oidc =
          let
            client_id = "firezone";
          in
          {
            name = "Kanidm";
            adapter = "openid_connect";
            adapter_config = {
              scope = "openid email profile";
              response_type = "code";
              inherit client_id;
              discovery_document_uri = "https://${globals.services.kanidm.domain}/oauth2/openid/${client_id}/.well-known/openid-configuration";
              clientSecretFile = config.age.secrets.firezone-oauth2-client-secret.path;
            };
          };

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
          // lib.mergeAttrsList (map (domain: allow "everyone" domain) homeDomains);
      };
    };

    domain.settings.ERLANG_DISTRIBUTION_PORT = 9003;
    api.externalUrl = "https://${firezoneDomain}/api/";
    web.externalUrl = "https://${firezoneDomain}/";
  };

  services.firezone.relay = {
    enable = true;
    name = "sentinel";
    apiUrl = "wss://${firezoneDomain}/api/";
    tokenFile = config.age.secrets.firezone-relay-token.path;
    publicIpv4 = lib.net.cidr.ip config.repo.secrets.local.networking.interfaces.wan.hostCidrv4;
    publicIpv6 = lib.net.cidr.ip config.repo.secrets.local.networking.interfaces.wan.hostCidrv6;
    openFirewall = true;
  };

  systemd.services.firezone-relay.environment.HEALTH_CHECK_ADDR = "127.0.0.1:17999";

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
