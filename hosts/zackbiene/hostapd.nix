{config, ...}: {
  # Associates a mandatory and unique password to each client
  # TODO: autogenerate? via secret generators and derived secrets?
  age.secrets.wifi-clients.rekeyFile = ./secrets/wifi-clients.age;

  hardware.wirelessRegulatoryDatabase = true;

  services.hostapd = {
    enable = true;
    radios.wlan1 = {
      band = "2g";
      countryCode = "DE";
      channel = 13; # Automatic Channel Selection (ACS) is unfortunately not implemented for mt7612u.
      wifi4.capabilities = ["LDPC" "HT40+" "HT40-" "GF" "SHORT-GI-20" "SHORT-GI-40" "TX-STBC" "RX-STBC1"];
      networks.wlan1 = {
        inherit (config.repo.secrets.local.hostapd) ssid;
        macAcl = "allow";
        apIsolate = true;
        authentication = {
          saePasswordsFile = config.age.secrets.wifi-clients.path;
          saeAddToMacAllow = true;
          enableRecommendedPairwiseCiphers = true;
        };
        bssid = "00:c0:ca:b1:4f:9f";
      };
      #networks.wlan1-2 = {
      #  inherit (config.repo.secrets.local.hostapd) ssid;
      #  authentication.mode = "none";
      #  bssid = "02:c0:ca:b1:4f:9f";
      #};
    };
  };
}
