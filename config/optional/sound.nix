{
  lib,
  minimal,
  pkgs,
  ...
}:
lib.optionalAttrs (!minimal) {
  # Helpful utilities:
  # Show pipewire devices and application overview or specifics
  # > wpctl status; wpctl inspect <id>
  # View real time node and device statistics
  # > pw-top
  # Show actual used playback stream settings
  # > cat /proc/asound/card*/pcm*p/sub*/hw_params
  # Compare resamplers on: https://src.infinitewave.ca/

  services.pulseaudio.enable = lib.mkForce false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
    extraConfig.pipewire."99-allowed-rates"."context.properties"."default.clock.allowed-rates" = [
      44100
      48000
      88200
      96000
      176400
      192000
    ];

    extraLadspaPackages = [ pkgs.deepfilternet ];
    extraConfig.pipewire = {
      "92-quantum"."context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 512;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 512;
      };
      "99-input-denoising" = {
        "context.properties" = {
          "link.max-buffers" = 16;
          "core.daemon" = true;
          "core.name" = "pipewire-0";
          "module.x11.bell" = false;
          "module.access" = true;
          "module.jackdbus-detect" = false;
        };

        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = "DeepFilter Noise Canceling source";
              "media.name" = "DeepFilter Noise Canceling source";

              "filter.graph".nodes = [
                {
                  type = "ladspa";
                  name = "DeepFilter Mono";
                  plugin = "libdeep_filter_ladspa";
                  label = "deep_filter_mono";
                  control."Attenuation Limit (dB)" = 100;
                }
              ];

              "audio.rate" = 48000;
              "audio.position" = "[MONO]";

              "capture.props"."node.passive" = true;
              "playback.props"."media.class" = "Audio/Source";
            };
          }
        ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    pulseaudio
    pulsemixer
  ];
}
