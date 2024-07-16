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

  hardware.pulseaudio.enable = lib.mkForce false;
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
  };

  environment.systemPackages = with pkgs; [pulseaudio pulsemixer];
}
