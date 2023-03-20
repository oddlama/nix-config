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
        logLevel = 0;
        ssid = "🍯🐝💨";
        hwMode = "g";
        countryCode = "DE";
        channel = 13; # Automatic Channel Selection (ACS) is unfortunately not implemented for mt7612u.
        macAcl = "deny";
        apIsolate = true;
        authentication = {
          saePasswordsFile = config.rekey.secrets.wifi-clients.path;
          saeAddToMacAllow = true;
        };
        wifi4.capabilities = ["LDPC" "HT40+" "HT40-" "GF" "SHORT-GI-20" "SHORT-GI-40" "TX-STBC" "RX-STBC1"];
      };
    };
  };
}
