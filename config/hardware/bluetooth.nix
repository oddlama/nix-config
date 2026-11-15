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
      };
    };
  };
}
