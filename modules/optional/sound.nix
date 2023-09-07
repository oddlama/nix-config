{
  lib,
  pkgs,
  ...
}: {
  # Helpful utilities:
  # Show pipewire devices and application overview or specifics
  # > wpctl status; wpctl inspect <id>
  # View real time node and device statistics
  # > pw-top
  # Show actual used playback stream settings
  # > cat /proc/asound/card*/pcm*p/sub*/hw_params

  sound.enable = false; # ALSA
  hardware.pulseaudio.enable = lib.mkForce false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  environment.systemPackages = with pkgs; [pulseaudio pulsemixer];
  environment.etc = {
    # Allow pipewire to dynamically adjust the rate sent to the devices based on the playback stream
    "pipewire/pipewire.conf.d/99-allowed-rates.conf".text = builtins.toJSON {
      "context.properties"."default.clock.allowed-rates" = [
        44100
        48000
        88200
        96000
        176400
        192000
      ];
    };
    # If resampling is required, use a higher quality. 15 is overkill and too cpu expensive without any obvious audible advantage
    "pipewire/pipewire-pulse.conf.d/99-resample.conf".text = builtins.toJSON {
      "stream.properties"."resample.quality" = 10;
    };
    "pipewire/client.conf.d/99-resample.conf".text = builtins.toJSON {
      "stream.properties"."resample.quality" = 10;
    };
    "pipewire/client-rt.conf.d/99-resample.conf".text = builtins.toJSON {
      "stream.properties"."resample.quality" = 10;
    };
  };
}
