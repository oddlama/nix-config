{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ bluetui ];
  environment.persistence."/persist".directories = [
    "/var/lib/bluetooth"
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    disabledPlugins = [ "sap" ];
    settings = {
      General = {
        FastConnectable = "true";
        JustWorksRepairing = "always";
        MultiProfile = "multiple";
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };

  hardware.pulseaudio = {
    package = pkgs.pulseaudio.override { bluetoothSupport = true; };
    extraConfig = ''
      load-module module-bluetooth-discover
      load-module module-bluetooth-policy
      load-module module-switch-on-connect
    '';
    extraModules = with pkgs; [ pulseaudio-modules-bt ];
  };
}
