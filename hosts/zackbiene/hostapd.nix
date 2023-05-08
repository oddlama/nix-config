{
  lib,
  config,
  pkgs,
  nodeSecrets,
  ...
}: {
  imports = [../../modules/hostapd.nix];
  disabledModules = ["services/networking/hostapd.nix"];

  # Associates each known client to a unique password
  rekey.secrets.wifi-clients.file = ./secrets/wifi-clients.age;

  services.hostapd = {
    enable = true;
    radios.wlan1 = {
      hwMode = "g";
      countryCode = "DE";
      channel = 13; # Automatic Channel Selection (ACS) is unfortunately not implemented for mt7612u.
      wifi4.capabilities = ["LDPC" "HT40+" "HT40-" "GF" "SHORT-GI-20" "SHORT-GI-40" "TX-STBC" "RX-STBC1"];
      networks.wlan1 = {
        inherit (nodeSecrets.hostapd) ssid;
        macAcl = "allow";
        apIsolate = true;
        authentication = {
          saePasswordsFile = config.rekey.secrets.wifi-clients.path;
          saeAddToMacAllow = true;
          enableRecommendedPairwiseCiphers = true;
        };
        bssid = "00:c0:ca:b1:4f:9f";
      };
      #networks.wlan1-2 = {
      #  inherit (nodeSecrets.hostapd) ssid;
      #  authentication.mode = "none";
      #  bssid = "02:c0:ca:b1:4f:9f";
      #};
    };
  };
}
