{
  lib,
  config,
  ...
}: {
  services.hostapd = {
    enable = true;
    interface = "wlan1";
    ssid = "🍯🐝💨";
    # We'll set the options ourselves
    wpa = false;
    # Use 2.4GHz, this network is ment for dumb embedded devices
    hwMode = "g";
    # Automatically select channel at runtime using acs_survey
    channel = 0;
    # Respect the local regulations
    countryCode = "DE";

    # This is made for a Mediatek mt7612u based device (ALFA AWUS036ACM)
    extraConfig = ''
      utf8_ssid=1
      # Enable QoS, required for 802.11n/ac/ax
      wmm_enabled=1

      # DFS (IEEE 802.11d, IEEE 802.11h)
      # Limit to frequencies allowed in country
      ieee80211d=1
      # Ensure TX Power and frequencies compliance with local regulatory requirements
      ieee80211h=1

      # IEEE 802.11ac (WiFi 4)
      # MIMO and channel bonding support
      ieee80211n=1
      # Add wider channel-width support and MU-MIMO (multi user MIMO)

      # IEEE 802.11ac (WiFi 5)
      ieee80211ac=1
      ht_capab=[HT40+][HT40-][GF][SHORT-GI-20][SHORT-GI-40]
      vht_capab=[RXLDPC][SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][MAX-A-MPDU-LEN-EXP3][RX-ANTENNA-PATTERN][TX-ANTENNA-PATTERN]
      vht_oper_chwidth=1

      # WPA3
      wpa=2
      wpa_pairwise=CCMP CCMP-256
      rsn_pairwise=CCMP CCMP-256
      wpa_key_mgmt=SAE
      # Require WPA, disable WEP
      auth_algs=1
      # Encrypt management frames to protect against deauthentication and similar attacks
      ieee80211w=2
      # Force WPA3-Personal without transition
      transition_disable=0x01
      # Derive PWE using both hunting-and-pecking loop and hash-to-element
      sae_pwe=2
      # SAE can also use wpa_psk, which allows us to use a separate file,
      # but it restricts the password length to [2,63] which is ok.
      # This conatins a list of passwords for each client MAC.
      wpa_psk_file=${config.rekey.secrets.wifi-clients.path}

      # Use a MAC-address access control list
      macaddr_acl=1
      accept_mac_file=/run/hostapd/client-macs

      # Hide network and require devices to know the ssid in advance
      ignore_broadcast_ssid=1
      # Don't allow clients to communicate with each other
      ap_isolate=1
    '';
  };

  # Associates each known client to a unique password
  rekey.secrets.wifi-clients.file = ./secrets/wifi-clients.age;
  systemd.services.hostapd = {
    # Filter the clients to get a list of all known MAC addresses,
    # which we then use for MAC access control.
    preStart = lib.mkBefore ''
      grep -o '^..:..:..:..:..:..' ${config.rekey.secrets.wifi-clients.path} > /run/hostapd/client-macs
    '';
    # Add some missing options to the upstream config
    serviceConfig = {
      ExecReload = "/bin/kill -HUP $MAINPID";
      RuntimeDirectory = "hostapd";

      # Hardening
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = false; # Needs /dev/rfkill
      PrivateUsers = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = false; # Needs write-access to /sys/class/net/...
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = false;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = ["@system-service" "~@privileged" "@chown"];
      UMask = "0077";
    };
  };
}
