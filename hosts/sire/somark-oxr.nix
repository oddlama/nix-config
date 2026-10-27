{
  config,
  inputs,
  lib,
  minimal,
  ...
}:
let
  cfg = config.services.somark-oxr;
  components = [
    "layout"
    "recognition"
    "api"
    "watchdog"
  ];
in
{
  imports = [ inputs.somark-oxr.nixosModules.default ];

  services.somark-oxr = {
    enable = !minimal;
    # Second RTX 3090; leave Qwen on the first and OmniVoice on the 2080 Ti.
    gpu = "GPU-36edecae-1d42-dca5-ab0f-89f7287743dd";

    # Validated standalone 3090 profile; native GPU qualification is still needed.
    gpuMemoryUtilization = 0.65;
    maxModelLen = 16384;
    maxNumSeqs = 4;

    # OXR does not authenticate API keys. Only Antirion exposes its API/artifacts;
    # all three listeners remain local and have no firewall openings.
    listenAddress = "127.0.0.1";
    layoutPort = 11436;
    recognitionPort = 11437;
    port = 11438;
  };

  # Gate the first backend, not just the enclosing target: its dependencies
  # could otherwise start before the driver's readiness check has completed.
  # Require the check itself so a failed check also fails OXR activation.
  systemd.services.somark-oxr-layout = lib.mkIf cfg.enable {
    requires = [ "nvidia-ready.service" ];
    after = [ "nvidia-ready.service" ];
  };

  # Retain JIT caches and unexpired artifacts across the ephemeral root's
  # rollback, but do not back up disposable data. Async task history stays in RAM.
  environment.persistence."/state".directories = lib.mkIf cfg.enable (
    [
      {
        directory = "/var/lib/${cfg.stateDirectory}";
        user = "somark-oxr-api";
        group = "somark-oxr-api";
        mode = "0700";
      }
    ]
    ++ map (component: {
      directory = "/var/cache/${cfg.cacheDirectory}/${component}";
      user = "somark-oxr-${component}";
      group = "somark-oxr-${component}";
      mode = "0700";
    }) components
  );
}
