{
  config,
  globals,
  pkgs,
  lib,
  ...
}:
let
  openWebuiDomain = "chat.${globals.domains.me}";
in
{
  imports = [
    ../../../config/hardware/nvidia.nix
  ];

  environment.systemPackages = [ pkgs.llama-cpp ];

  hardware.nvidia.nvidiaPersistenced = true;

  systemd.targets.nvidia-ready = {
    description = "NVIDIA driver initialized and ready";
    wantedBy = [ "multi-user.target" ];
  };
  systemd.services.nvidia-ready = {
    description = "Wait until NVIDIA GPUs are usable";

    before = [ "nvidia-ready.target" ];
    wantedBy = [ "nvidia-ready.target" ];

    after = [ "systemd-modules-load.service" ];
    wants = [ "systemd-modules-load.service" ];

    path = [
      config.hardware.nvidia.package
      pkgs.gnugrep
    ];

    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "120";
      RestartSec = "60";
    };

    script = ''
      echo "Waiting for NVIDIA GPUs..."

      EXPECTED_UUIDS=(
        "GPU-36edecae-1d42-dca5-ab0f-89f7287743dd"
        "GPU-a29946ab-ad82-62bc-6c5a-a06bab6bb799"
      )

      for i in $(seq 1 60); do
        # Get currently visible UUIDs
        FOUND_UUIDS=$(nvidia-smi -L | grep -o 'GPU-[0-9a-f-]*')

        # Check if all expected UUIDs are present
        ALL_PRESENT=1
        for uuid in "''${EXPECTED_UUIDS[@]}"; do
          if ! grep -q "$uuid" <<< "$FOUND_UUIDS"; then
            ALL_PRESENT=0
            break
          fi
        done

        if [[ "$ALL_PRESENT" -eq 1 ]]; then
          echo "All expected GPUs detected:"
          echo "$FOUND_UUIDS"
          exit 0
        fi

        sleep 2
      done

      echo "Timed out waiting for GPUs."
      exit 1
    '';
  };

  systemd.services.nvidia-power-limit = {
    description = "Set NVIDIA GPU Power Limit";

    wantedBy = [ "nvidia-ready.target" ];
    requires = [ "nvidia-ready.target" ];
    after = [ "nvidia-ready.target" ];

    path = [ config.hardware.nvidia.package ];

    script = ''
      nvidia-smi -pl 250
    '';

    serviceConfig.Type = "oneshot";
  };

  systemd.services.ollama = {
    wantedBy = lib.mkForce [ "nvidia-ready.target" ];

    requires = [ "nvidia-ready.target" ];
    after = [ "nvidia-ready.target" ];
  };

  microvm.mem = 1024 * 48;
  microvm.vcpu = 24;
  microvm.devices = [
    {
      bus = "pci";
      path = "0000:43:00.0";
    }
    {
      bus = "pci";
      path = "0000:43:00.1";
    }
    {
      bus = "pci";
      path = "0000:07:00.0";
    }
    {
      bus = "pci";
      path = "0000:07:00.1";
    }
  ];

  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [
      config.services.open-webui.port
    ];

  networking.firewall.allowedTCPPorts = [ config.services.ollama.port ];

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
    package = pkgs.ollama-cuda;
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
        servers."${
          globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
        }:${toString config.services.open-webui.port}" =
          { };
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
          allowedGroups = [ "access_openwebui" ];
          X-Email = "\${upstream_http_x_auth_request_preferred_username}@${globals.domains.personal}";
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
