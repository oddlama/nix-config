{
  config,
  inputs,
  pkgs,
  globals,
  lib,
  ...
}:
let
  llamacppDomain = "llm.${globals.domains.me}";
  omnivoiceDomain = "tts.${globals.domains.me}";
in
{
  imports = [
    ../../config/hardware/nvidia.nix
    # Provides services.omnivoice and pkgs.omnivoice{,-cuda}
    inputs.omnivoice-rs.nixosModules.default
  ];

  hardware.nvidia.nvidiaPersistenced = true;

  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/private/llama-cpp";
      mode = "0700";
    }
  ];

  # Model weights are downloaded from huggingface on first start.
  environment.persistence."/persist".directories = [
    {
      directory = config.services.omnivoice.dataDir;
      inherit (config.services.omnivoice) user group;
      mode = "0750";
    }
  ];

  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode = {
    ward-web-proxy.allowedTCPPorts = [
      config.services.llama-cpp.settings.port
      config.services.omnivoice.port
    ];
    # Home Assistant talks to the wyoming endpoint directly, it isn't proxied.
    sausebiene.allowedTCPPorts = [ config.services.omnivoice.wyoming.port ];
  };
  globals.wireguard.proxy-sentinel.hosts.${config.node.name}.firewallRuleForNode.sentinel.allowedTCPPorts =
    [
      config.services.llama-cpp.settings.port
      config.services.omnivoice.port
    ];

  # one key per line, no comments allowed
  age.secrets.llama-cpp-api-keys = {
    rekeyFile = ./secrets/llama-cpp-api-keys.age;
    mode = "400";
  };

  age.secrets.omnivoice-api-key = {
    rekeyFile = ./secrets/omnivoice-api-key.age;
    generator.script = "alnum";
    mode = "400";
  };

  environment.systemPackages = [ pkgs.llama-cpp ];
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = false;
    settings = {
      port = 11434;
      host = "0.0.0.0";
      model = "/persist/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q8_K_XL.gguf";
      gpu-layers = 999;
      ctx-size = 222144;
      temp = "1.0";
      top-p = "0.95";
      top-k = 20;
      min-p = "0.0";
      mmproj = "/persist/unsloth/Qwen3.8-27B-GGUF/mmproj-BF16.gguf";
      reasoning = "off";
    };
  };

  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ "nvidia-ready.target" ];

    requires = [ "nvidia-ready.target" ];
    after = [ "nvidia-ready.target" ];

    # Both 3090s, the 2080 Ti (index 1) is reserved for omnivoice.
    environment = {
      CUDA_DEVICE_ORDER = "PCI_BUS_ID";
      CUDA_VISIBLE_DEVICES = "0,2";
    };

    serviceConfig.LoadCredential = [ "api-keys.txt:${config.age.secrets.llama-cpp-api-keys.path}" ];
    serviceConfig.ExecStart =
      let
        cfg = config.services.llama-cpp;
      in
      lib.mkForce (toString [
        (lib.getExe' cfg.package "llama-server")
        "--api-key-file %d/api-keys.txt"
        (lib.cli.toCommandLine (optionName: {
          option = if builtins.stringLength optionName > 1 then "--${optionName}" else "-${optionName}";
          sep = " ";
          explicitBool = false;
          formatArg = lib.generators.mkValueStringDefault { };
        }) cfg.settings)
      ]);
  };

  services.omnivoice = {
    enable = true;
    # cudaCapability 7.5 == the RTX 2080 Ti. The kernels are compiled to PTX for
    # exactly this capability and PTX is only forward compatible, so this build
    # would also run on the 3090s, but not the other way around.
    package = pkgs.omnivoice-cuda.override { cudaCapability = "75"; };
    host = "0.0.0.0";
    port = 11435;
    openFirewall = false;
    device = "cuda";
    # Leave both 3090s (index 0 and 2 in PCI bus order) to llama-cpp.
    cuda.visibleDevices = [ "1" ];
    apiKeyFile = config.age.secrets.omnivoice-api-key.path;
    wyoming = {
      enable = true;
      openFirewall = false;
    };
    voicesConfigFile = "/var/lib/omnivoice/voices.toml";
  };

  systemd.services.omnivoice-server = {
    wantedBy = lib.mkForce [ "nvidia-ready.target" ];

    requires = [ "nvidia-ready.target" ];
    after = [ "nvidia-ready.target" ];
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
  globals.services.omnivoice.domain = omnivoiceDomain;

  nodes.ward-web-proxy.services.nginx = {
    upstreams.llama-cpp = {
      servers."${
        globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4
      }:${toString config.services.llama-cpp.settings.port}" =
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

    upstreams.omnivoice = {
      servers."${
        globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4
      }:${toString config.services.omnivoice.port}" =
        { };
      extraConfig = ''
        zone omnivoice 64k;
        keepalive 2;
      '';
      monitoring = {
        enable = true;
        path = "/health";
        expectedBodyRegex = ''"status": ?"ok"'';
      };
    };
    virtualHosts.${omnivoiceDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      extraConfig = ''
        client_max_body_size ${toString config.services.omnivoice.maxBodyMb}M;
        # Synthesis of long inputs can take a while.
        proxy_read_timeout ${toString config.services.omnivoice.requestTimeout}s;
        proxy_send_timeout ${toString config.services.omnivoice.requestTimeout}s;
      '';
      locations."/" = {
        proxyPass = "http://omnivoice";
        proxyWebsockets = true;
        X-Frame-Options = "SAMEORIGIN";
      };
    };
  };

  nodes.sentinel.services.nginx = {
    upstreams.llama-cpp = {
      servers."${
        globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
      }:${toString config.services.llama-cpp.settings.port}" =
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

    upstreams.omnivoice = {
      servers."${
        globals.wireguard.proxy-sentinel.hosts.${config.node.name}.ipv4
      }:${toString config.services.omnivoice.port}" =
        { };
      extraConfig = ''
        zone omnivoice 64k;
        keepalive 2;
      '';
      monitoring = {
        enable = true;
        path = "/health";
        expectedBodyRegex = ''"status": ?"ok"'';
      };
    };
    virtualHosts.${omnivoiceDomain} = {
      forceSSL = true;
      useACMEWildcardHost = true;
      extraConfig = ''
        client_max_body_size ${toString config.services.omnivoice.maxBodyMb}M;
        # Synthesis of long inputs can take a while.
        proxy_read_timeout ${toString config.services.omnivoice.requestTimeout}s;
        proxy_send_timeout ${toString config.services.omnivoice.requestTimeout}s;
      '';
      locations."/" = {
        proxyPass = "http://omnivoice";
        proxyWebsockets = true;
        X-Frame-Options = "SAMEORIGIN";
      };
    };
  };
}
