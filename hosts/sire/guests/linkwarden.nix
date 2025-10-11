{
  config,
  globals,
  nodes,
  ...
}:
let
  linkwardenDomain = "links.${globals.domains.me}";
in
{
  microvm.mem = 1024 * 4;
  microvm.vcpu = 8;

  age.secrets.linkwarden-nextauth-secret = {
    rekeyFile = config.node.secretsDir + "/linkwarden-nextauth-secret.age";
    generator.script = "base64";
    mode = "440";
    group = "linkwarden";
  };

  # Mirror the original oauth2 secret
  age.secrets.linkwarden-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-linkwarden) rekeyFile;
    mode = "440";
    group = "linkwarden";
  };

  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [ 3000 ];
  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.ward-web-proxy.allowedTCPPorts =
    [ 3000 ];

  globals.services.linkwarden.domain = linkwardenDomain;
  globals.monitoring.http.linkwarden = {
    url = "https://${linkwardenDomain}";
    expectedBodyRegex = "<title>Linkwarden";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/linkwarden";
      user = "linkwarden";
      group = "linkwarden";
      mode = "0750";
    }
  ];

  services.linkwarden = {
    enable = true;
    host = "0.0.0.0";
    database.createLocally = true;
    enableRegistration = false;

    secretFiles.NEXTAUTH_SECRET = config.age.secrets.linkwarden-nextauth-secret.path;
    secretFiles.AUTHENTIK_CLIENT_SECRET = config.age.secrets.linkwarden-oauth2-client-secret.path;

    # NOTE: Well yes - it does not support generic OIDC so we piggyback on the AUTHENTIK provider
    environment = rec {
      RE_ARCHIVE_LIMIT = "0";
      NEXTAUTH_URL = "https://${linkwardenDomain}/api/v1/auth";
      NEXT_PUBLIC_CREDENTIALS_ENABLED = "false"; # disables username / pass authentication
      NEXT_PUBLIC_AUTHENTIK_ENABLED = "true";
      AUTHENTIK_ISSUER = "https://${globals.services.kanidm.domain}/oauth2/openid/${AUTHENTIK_CLIENT_ID}";
      AUTHENTIK_CLIENT_ID = "linkwarden";
      AUTHENTIK_CUSTOM_NAME = "Kanidm (SSO)";
    };
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.linkwarden = {
        servers."${globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4}:3000" = { };
        extraConfig = ''
          zone linkwarden 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "<title>Linkwarden";
        };
      };
      virtualHosts.${linkwardenDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://linkwarden";
          proxyWebsockets = true;
        };
        extraConfig = ''
          client_max_body_size 128M;
        '';
      };
    };
  };

  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.linkwarden = {
        servers."${globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4}:3000" = { };
        extraConfig = ''
          zone linkwarden 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "<title>Linkwarden";
        };
      };
      virtualHosts.${linkwardenDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://linkwarden";
          proxyWebsockets = true;
        };
        extraConfig = ''
          client_max_body_size 128M;
          allow ${globals.net.home-lan.vlans.home.cidrv4};
          allow ${globals.net.home-lan.vlans.home.cidrv6};
          # Firezone traffic
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv4};
          allow ${globals.net.home-lan.vlans.services.hosts.ward.ipv6};
          deny all;
        '';
      };
    };
  };

  backups.storageBoxes.dusk = {
    subuser = "linkwarden";
    paths = [ "/var/lib/linkwarden" ];
    withPostgres = true;
  };
}
