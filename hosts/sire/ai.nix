{
  config,
  pkgs,
  globals,
  lib,
  utils,
  ...
}:
let
  llamacppDomain = "llm.${globals.domains.me}";
in
{
  imports = [
    ../../config/hardware/nvidia.nix
  ];

  hardware.nvidia.nvidiaPersistenced = true;

  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/private/llama-cpp";
      mode = "0700";
    }
  ];

  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.ward-web-proxy.allowedTCPPorts =
    [ config.services.llama-cpp.port ];
  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [ config.services.llama-cpp.port ];

  # one key per line, no comments allowed
  age.secrets.llama-cpp-api-keys = {
    rekeyFile = ./secrets/llama-cpp-api-keys.age;
    mode = "400";
  };

  environment.systemPackages = [ pkgs.llama-cpp ];
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    port = 11434;
    host = "0.0.0.0";
    openFirewall = false;
    model = "/persist/unsloth/Qwen3.5-27B-Uncensored-HauhauCS-Aggressive/Qwen3.5-27B-Uncensored-HauhauCS-Aggressive-Q8_0.gguf";
    extraFlags = [
      "-ngl"
      "999"
      "-np"
      "1"
      "--ctx-size"
      # "262144"
      "131072"
      "--temp"
      "0.6"
      "--top-p"
      "0.95"
      "--top-k"
      "20"
      "--min-p"
      "0.0"
      "--mmproj"
      "/persist/unsloth/Qwen3.5-27B-Uncensored-HauhauCS-Aggressive/mmproj-Qwen3.5-27B-Uncensored-HauhauCS-Aggressive-f16.gguf"
      "--reasoning"
      "off"
    ];
  };

  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ "nvidia-ready.target" ];

    requires = [ "nvidia-ready.target" ];
    after = [ "nvidia-ready.target" ];

    serviceConfig.LoadCredential = [ "api-keys.txt:${config.age.secrets.llama-cpp-api-keys.path}" ];
    serviceConfig.ExecStart =
      let
        cfg = config.services.llama-cpp;
        args = [
          "--host"
          cfg.host
          "--port"
          (toString cfg.port)
        ]
        ++ lib.optionals (cfg.model != null) [
          "-m"
          cfg.model
        ]
        ++ lib.optionals (cfg.modelsDir != null) [
          "--models-dir"
          cfg.modelsDir
        ]
        ++ cfg.extraFlags;
      in
      lib.mkForce "${cfg.package}/bin/llama-server --api-key-file %d/api-keys.txt ${utils.escapeSystemdExecArgs args}";
  };

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

  globals.services.llama-cpp.domain = llamacppDomain;

  nodes.ward-web-proxy.services.nginx = {
    upstreams.llama-cpp = {
      servers."${
        globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4
      }:${toString config.services.llama-cpp.port}" =
        { };
      extraConfig = ''
        zone llama-cpp 64k;
        keepalive 2;
      '';
      monitoring = {
        enable = true;
        path = "/health";
        expectedBodyRegex = ''{"status": ?"ok"}'';
      };
    };
    virtualHosts.${llamacppDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      extraConfig = ''
        client_max_body_size 1G;
      '';
      locations."/" = {
        proxyPass = "http://llama-cpp";
        proxyWebsockets = true;
        X-Frame-Options = "SAMEORIGIN";
      };
    };
  };

  nodes.sentinel.services.nginx = {
    upstreams.llama-cpp = {
      servers."${
        globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
      }:${toString config.services.llama-cpp.port}" =
        { };
      extraConfig = ''
        zone llama-cpp 64k;
        keepalive 2;
      '';
      monitoring = {
        enable = true;
        path = "/health";
        expectedBodyRegex = ''{"status": ?"ok"}'';
      };
    };
    virtualHosts.${llamacppDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      extraConfig = ''
        client_max_body_size 1G;
      '';
      locations."/" = {
        proxyPass = "http://llama-cpp";
        proxyWebsockets = true;
        X-Frame-Options = "SAMEORIGIN";
      };
    };
  };
}
