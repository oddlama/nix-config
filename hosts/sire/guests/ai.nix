{config, ...}: let
  openWebuiDomain = "chat.${config.repo.secrets.global.domains.me}";
in {
  microvm.mem = 1024 * 16;
  microvm.vcpu = 20;

  wireguard.proxy-sentinel = {
    client.via = "sentinel";
    firewallRuleForNode.sentinel.allowedTCPPorts = [config.services.open-webui.port];
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

      ENABLE_COMMUNITY_SHARING = "False";
      ENABLE_ADMIN_EXPORT = "False";

      OLLAMA_BASE_URL = "http://localhost:11434";
      TRANSFORMERS_CACHE = "/var/lib/open-webui/.cache/huggingface";

      WEBUI_AUTH = "False";
      ENABLE_SIGNUP = "False";
      WEBUI_AUTH_TRUSTED_EMAIL_HEADER = "X-Email";
      DEFAULT_USER_ROLE = "user";
    };
  };

  globals.services.open-webui.domain = openWebuiDomain;
  globals.monitoring.http.ollama = {
    url = config.services.open-webui.environment.OLLAMA_BASE_URL;
    expectedBodyRegex = "Ollama is running";
    network = "local-${config.node.name}";
  };

  nodes.sentinel = {
    services.nginx = {
      upstreams.open-webui = {
        servers."${config.wireguard.proxy-sentinel.ipv4}:${toString config.services.open-webui.port}" = {};
        extraConfig = ''
          zone open-webui 64k;
          keepalive 2;
        '';
        monitoring = {
          enable = true;
          expectedBodyRegex = "Open WebUI";
        };
      };
      virtualHosts.${openWebuiDomain} = {
        forceSSL = true;
        useACMEWildcardHost = true;
        oauth2 = {
          enable = true;
          allowedGroups = ["access_openwebui"];
          X-Email = "\${upstream_http_x_auth_request_preferred_username}@${config.repo.secrets.global.domains.personal}";
        };
        extraConfig = ''
          client_max_body_size 128M;
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
