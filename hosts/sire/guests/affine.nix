{
  config,
  globals,
  nodes,
  ...
}:
let
  affineDomain = "notes.${globals.domains.me}";
in
{
  microvm.mem = 1024 * 4;
  microvm.vcpu = 8;

  # Mirror the original oauth2 secret
  age.secrets.affine-oauth2-client-secret = {
    inherit (nodes.ward-kanidm.config.age.secrets.kanidm-oauth2-affine) rekeyFile;
    mode = "440";
    group = "affine";
  };

  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [ 3010 ];
  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.ward-web-proxy.allowedTCPPorts =
    [ 3010 ];

  globals.services.affine.domain = affineDomain;
  globals.monitoring.http.affine = {
    url = "https://${affineDomain}";
    expectedBodyRegex = "<title>AFFiNE";
    network = "internet";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/affine";
      user = "affine";
      group = "affine";
      mode = "0750";
    }
  ];

  services.affine = {
    enable = true;
    enableLocalDB = true;
    settings = {
      auth = {
        allowSignup = false;
        allowSignupForOauth = true;
        "session.ttl" = 365 * 86400; # ~1 year
      };
      oauth."providers.oidc" = {
        clientId = "affine";
        clientSecret._secret = config.age.secrets.affine-oauth2-client-secret.path;
        issuer = "https://${globals.services.kanidm.domain}";
        args = {
          scope = "openid profile email";
          claim_id = "preferred_username";
          claim_name = "name";
          claim_email = "email";
        };
      };
      server = {
        name = "Panzerbeere";
        host = "0.0.0.0";
        https = true;
        hosts = [
          globals.wireguard.proxy-sentinel.hosts.sentinel.ipv4
          globals.wireguard.proxy-home.hosts.ward-web-proxy.ipv4
        ];
        externalUrl = "https://${affineDomain}";
      };
    };
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.affine = {
        servers."${globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4}:3010" = { };
        extraConfig = ''
          zone affine 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "<title>AFFiNE";
        };
      };
      virtualHosts.${affineDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://affine";
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
      upstreams.affine = {
        servers."${globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4}:3010" = { };
        extraConfig = ''
          zone affine 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "<title>AFFiNE";
        };
      };
      virtualHosts.${affineDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        locations."/" = {
          proxyPass = "http://affine";
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
    subuser = "affine";
    paths = [ "/var/lib/affine" ];
  };
}
