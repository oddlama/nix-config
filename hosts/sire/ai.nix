{
  config,
  inputs,
  pkgs,
  globals,
  lib,
  ...
}:
let
  qwenModelDir = "/persist/bartowski/orcarouter_Qwen3.8-27B-Uncensored-GGUF";
in
{
  imports = [
    ../../config/hardware/nvidia.nix
    ./antirion.nix
    ./somark-oxr.nix
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

  # Wyoming is deliberately separate from the HTTP gateway and its accounting.
  globals.wireguard.proxy-home.hosts.${config.node.name}.firewallRuleForNode.sausebiene.allowedTCPPorts =
    [ config.services.omnivoice.wyoming.port ];

  environment.systemPackages = [ pkgs.llama-cpp ];
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    openFirewall = false;
    settings = {
      port = 11434;
      host = "127.0.0.1";
      model = "${qwenModelDir}/orcarouter_Qwen3.8-27B-Uncensored-IQ4_XS.gguf";
      mmproj = "${qwenModelDir}/mmproj-orcarouter_Qwen3.8-27B-Uncensored-f16.gguf";
      alias = "orcarouter-qwen38-27b";

      # Language model and vision projector stay on the first 3090.
      gpu-layers = 999;
      split-mode = "none";
      device = "CUDA0";
      fit = "off";
      mmproj-offload = true;
      image-max-tokens = 4096;

      # Shared total, including images/output: 2 x 50K or 1 x 150K, not 2 x 150K.
      # Measured on b10273 with only ~700 MiB VRAM spare; recheck after upgrades.
      ctx-size = 155648;
      parallel = 2;
      kv-unified = true;
      cont-batching = true;
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      flash-attn = "on";
      batch-size = 4096;
      ubatch-size = 512;
      threads = 8;
      threads-batch = 16;

      spec-type = "draft-mtp";
      spec-draft-n-max = 2;
      spec-draft-type-k = "q8_0";
      spec-draft-type-v = "q8_0";

      # RAM cache for idle conversations; checkpoints allow recent-turn edits.
      cache-ram = 4096;
      ctx-checkpoints = 4;
      cache-prompt = true;
      no-context-shift = true;

      temp = "1.0";
      top-p = "0.95";
      top-k = 20;
      min-p = "0.0";
      reasoning = "off";
      metrics = true;
      offline = true;
      # no-webui = true;
    };
  };

  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ "nvidia-ready.target" ];

    requires = [ "nvidia-ready.target" ];
    after = [ "nvidia-ready.target" ];

    # First 3090 for Qwen; reserve the other 3090 for OXR and the 2080 Ti for speech.
    environment = {
      CUDA_DEVICE_ORDER = "PCI_BUS_ID";
      CUDA_VISIBLE_DEVICES = "GPU-a29946ab-ad82-62bc-6c5a-a06bab6bb799";
    };
  };

  services.omnivoice = {
    enable = true;
    # cudaCapability 7.5 == the RTX 2080 Ti. The kernels are compiled to PTX for
    # exactly this capability and PTX is only forward compatible, so this build
    # would also run on the 3090s, but not the other way around.
    package =
      (pkgs.omnivoice-cuda.override {
        cudaCapability = "75";
        # cudarc 0.19.4 supports at most CUDA 13.2; nixpkgs defaults to 13.4.
        cudaPackages = pkgs.cudaPackages_13_2;
      }).overrideAttrs
        (old: {
          patches = (old.patches or [ ]) ++ [ ../../pkgs/omnivoice-loopback-no-auth.patch ];
        });
    host = "127.0.0.1";
    port = 11435;
    openFirewall = false;
    device = "cuda";
    # Keep the 2080 Ti dedicated to speech; the 3090s are for Qwen and OXR.
    cuda.visibleDevices = [ "1" ];
    # Upstream's module insists on a credential source. An empty EnvironmentFile
    # satisfies that assertion without loading/sending any token. The local patch
    # makes --no-auth explicit and refuses non-loopback HTTP bind addresses.
    environmentFile = "/dev/null";
    extraArgs = [ "--no-auth" ];
    wyoming = {
      enable = true;
      host = globals.wireguard.proxy-home.hosts.${config.node.name}.ipv4;
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
}
