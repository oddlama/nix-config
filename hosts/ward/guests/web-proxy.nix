{config, ...}: let
  inherit (config.repo.secrets.local) acme;
  fritzboxDomain = "fritzbox.${config.repo.secrets.global.domains.me}";
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

  age.secrets.github-access-token = {
    rekeyFile = config.node.secretsDir + "/github-access-token.age";
    mode = "440";
    group = "telegraf";
  };

  meta.telegraf.secrets."@GITHUB_ACCESS_TOKEN@" = config.age.secrets.github-access-token.path;
  services.telegraf.extraConfig.inputs = {
    ping = [
      {
        method = "native";
        urls = [
          "192.168.178.1"
          "192.168.1.1"
        ];
        tags.type = "internal";
        fieldpass = [
          "percent_packet_loss"
          "average_response_ms"
          "standard_deviation_ms"
          "reply_received"
          "percent_reply_loss"
        ];
      }
      {
        method = "native";
        urls = [
          "1.1.1.1"
          "8.8.8.8"
          config.repo.secrets.global.domains.me
          config.repo.secrets.global.domains.personal
        ];
        tags.type = "external";
        fieldpass = [
          "percent_packet_loss"
          "average_response_ms"
          "standard_deviation_ms"
          "reply_received"
          "percent_reply_loss"
        ];
      }
    ];

    # FIXME: pls define this on the relevant hosts. Then we can ping it from multiple other hosts
    #http_response = [
    #  {
    #    urls = [
    #    ];
    #    response_string_match = "Index of /";
    #    response_status_code = 200;
    #  }
    #];

    github = {
      access_token = "@GITHUB_ACCESS_TOKEN@";
      repositories = [
        "oddlama/agenix-rekey"
        "oddlama/autokernel"
        "oddlama/gentoo-install"
        "oddlama/nix-config"
        "oddlama/nix-topology"
        "oddlama/vane"
      ];
    };
  };

  services.nginx = {
    upstreams.fritzbox = {
      servers."192.168.178.1" = {};
      extraConfig = ''
        zone grafana 64k;
        keepalive 2;
      '';
    };
    virtualHosts.${fritzboxDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      locations."/" = {
        proxyPass = "http://fritzbox";
        proxyWebsockets = true;
      };
      # Allow using self-signed certs. We just want to make sure the connection
      # is over TLS.
      # FIXME: refer to lan 192.168... and fd10:: via globals
      extraConfig = ''
        proxy_ssl_verify off;
        allow 192.168.1.0/24;
        allow fd10::/64;
        deny all;
      '';
    };
  };

  users.groups.acme.members = ["nginx"];
  services.nginx.enable = true;
  services.nginx.recommendedSetup = true;
}
