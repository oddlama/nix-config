{config, ...}: let
  openWebuiDomain = "chat.${config.repo.secrets.global.domains.me}";
in {
  microvm.mem = 1024 * 16;
  microvm.vcpu = 20;

  wireguard.proxy-home = {
    client.via = "ward";
    firewallRuleForNode.ward-web-proxy.allowedTCPPorts = [
      config.services.open-webui.port
    ];
  };

  networking.firewall.allowedTCPPorts = [config.services.ollama.port];

  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/private/ollama";
      mode = "0700";
    }
    {
      directory = "/var/lib/private/open-webui";
      mode = "0700";
    }
  ];

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 11222;
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";

      WEBUI_AUTH = "False";
      ENABLE_SIGNUP = "False";

      OLLAMA_BASE_URL = "http://localhgost:11434";
      TRANSFORMERS_CACHE = "/var/lib/open-webui/.cache/huggingface";
    };
  };

  globals.services.open-webui.domain = openWebuiDomain;
  nodes.ward-web-proxy = {
    services.nginx = {
      upstreams.open-webui = {
        servers."${config.wireguard.proxy-home.ipv4}:${toString config.services.open-webui.port}" = {};
        extraConfig = ''
          zone open-webui 64k;
          keepalive 2;
        '';
      };
      virtualHosts.${openWebuiDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2.enable = true;
        oauth2.allowedGroups = ["access_openwebui"];
        # FIXME: refer to lan 192.168... and fd10:: via globals
        extraConfig = ''
          client_max_body_size 512M;
          allow 192.168.1.0/24;
          allow fd10::/64;
          deny all;
        '';
        locations."/" = {
          proxyPass = "http://open-webui";
          proxyWebsockets = true;
          X-Frame-Options = "SAMEORIGIN";
        };
      };
    };
  };
}
