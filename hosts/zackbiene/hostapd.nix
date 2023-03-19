{
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [../../modules/hostapd.nix];
  disabledModules = ["services/networking/hostapd.nix"];

  # Associates each known client to a unique password
  rekey.secrets.wifi-clients.file = ./secrets/wifi-clients.age;

  services.hostapd = {
    enable = true;
    interfaces = {
      "wlan1" = {
        ssid = "🍯🐝💨";
        hwMode = "g";
        #wifi4.enable = true;
        #wifi5.enable = true;
        countryCode = "DE";
        # Automatic Channel Selection (ACS) is unfortunately not implemented for mt7612u.
        channel = 13;

        #wpa = 3;
        # TODO dont adverttise!

        # TODO away
        logLevel = 0;
      };
    };
  };
}
