{
  lib,
  config,
  pkgs,
  ...
}: {
  services.hostapd = {
    enable = true;
    interface = "wlan1";
    ssid = "🍯🐝💨";
    wpa = 3;
    # Use 2.4GHz, this network is ment for dumb embedded devices
    hwMode = "g";
    # Automatic Channel Selection (ACS) is unfortunately not implemented for mt7612u.
    channel = 13;
    # Respect the local regulations
    countryCode = "DE";
    # TODO away
    logLevel = 0;
  };
  # TODO dont adverttise!
  #wpa_psk_file=${config.rekey.secrets.wifi-clients.path}

  # Associates each known client to a unique password
  rekey.secrets.wifi-clients.file = ./secrets/wifi-clients.age;
  systemd.services.hostapd = {
    # Filter the clients to get a list of all known MAC addresses, which we
    # then use for MAC access control. Afterwards, add the password for each
    # client to the hostapd config.
    preStart = lib.mkBefore ''
      grep -o '^..:..:..:..:..:..' ${config.rekey.secrets.wifi-clients.path} > /run/hostapd/client-macs
      hostapd_conf=$(cat ''${systemd.services.hostapd.serviceConfig.ExecStart})
      sae_passwords=$(echo -e "sae_password=aa|mac=13:13:13:13:13:13\nsae_password=aa|mac=12:12:12:12:12:12")
      hostapd_conf=''${hostapd_conf//"{{SAE_PASSWORDS}}"/$sae_passwords}
      echo "$hostapd_conf" > /run/hostapd/config
    '';
    # Add some missing options to the upstream config
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.hostapd}/bin/hostapd /run/hostapd/config";
      ExecReload = "/bin/kill -HUP $MAINPID";
      RuntimeDirectory = "hostapd";

      # Hardening
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      DevicePolicy = "closed";
      DeviceAllow = "/dev/rfkill rw";
      NoNewPrivileges = true;
      PrivateUsers = false; # hostapd requires real system root access.
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectSystem = "strict";
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
