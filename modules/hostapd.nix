{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
with lib; let
  disabledModules = ["services/networking/hostapd.nix"];

  cfg = config.services.hostapd;

  escapedInterface = utils.escapeSystemdPath cfg.interface;

  configFile = pkgs.writeText "hostapd.conf" ''
    # logging (debug level)
    logger_syslog=-1
    logger_syslog_level=${toString cfg.logLevel}
    logger_stdout=-1
    logger_stdout_level=${toString cfg.logLevel}

    ctrl_interface=/run/hostapd
    ctrl_interface_group=${cfg.group}

    interface=${cfg.interface}
    driver=${cfg.driver}
    utf8_ssid=1
    ssid=${cfg.ssid}
    hw_mode=${cfg.hwMode}
    channel=${toString cfg.channel}

    ${optionalString cfg.wpa ''
      wpa=2
      wpa_pairwise=CCMP
      wpa_passphrase=${cfg.wpaPassphrase}
    ''}
    ${optionalString cfg.noScan "noscan=1"}

    # Enable QoS, required for 802.11n/ac/ax
    wmm_enabled=1

    ${optionalString (cfg.countryCode != null) ''
      # DFS (IEEE 802.11d, IEEE 802.11h)
      # Limit to frequencies allowed in country
      ieee80211d=1
      country_code=${cfg.countryCode}
      # Ensure TX Power and frequencies compliance with local regulatory requirements
      ieee80211h=1
    ''}

    # IEEE 802.11ac (WiFi 4) - MIMO and channel bonding support
    ieee80211n=1
    ht_capab=[LDPC][HT40+][HT40-][GF][SHORT-GI-20][SHORT-GI-40][TX-STBC][RX-STBC1]

    # IEEE 802.11ac (WiFi 5) - adds wider channel-width support and MU-MIMO (multi user MIMO)
    ieee80211ac=1
    #vht_capab=[SHORT-GI-80][TX-STBC-2BY1][RX-STBC-1][RX-ANTENNA-PATTERN][TX-ANTENNA-PATTERN]
    #vht_oper_chwidth=1

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
    # SAE passwords can be set via wpa_passphrase but not via wpa_psk_file. This sucks
    # and means we have to add the passwords in pre-start to prevent them being visible here
    {{SAE_PASSWORDS}}

    # Use a MAC-address access control list
    macaddr_acl=1
    ${optionalString (cfg.macaddrAcl != null) ''
      accept_mac_file=${cfg.macaddrAcl}
    ''}

    # Hide network and require devices to know the ssid in advance
    #ignore_broadcast_ssid=${cfg.ignoreBroadcastSsid}
    # Don't allow clients to communicate with each other
    ap_isolate=${cfg.apIsolate}

    ${cfg.extraConfig}
  '';
in {
  # TODO assert interfaces >= 1

  options = with types; {
    services.hostapd = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = lib.mdDoc ''
          Whether to enable hostapd. hostapd is a user space daemon for access point and
          authentication servers. It implements IEEE 802.11 access point management,
          IEEE 802.1X/WPA/WPA2/EAP Authenticators, RADIUS client, EAP server, and RADIUS
          authentication server.
        '';
      };

      interfaces = mkOption {
        default = {};
        example = literalExpression ''
          {
            # WiFi 4 - 2.4GHz
            "wlp2s0" = {
              ssid = "";
            };
            # WiFi 5 - 5GHz
            "wlp3s0" = {
            };
          }
        '';
        description = lib.mdDoc ''
          This option allows you to define APs for one or multiple interfaces.
          Each attribute specifies a interface and associates it to its configuration.
          At least one interface must be specified.
        '';
        type = attrsOf (submodule {
          options = {
            noScan = mkOption {
              type = types.bool;
              default = false;
              description = lib.mdDoc ''
                Disables scan for overlapping BSSs in HT40+/- mode.
                Caution: turning this on will likely violate regulatory requirements!
              '';
            };

            driver = mkOption {
              default = "nl80211";
              example = "none";
              type = types.str;
              description = lib.mdDoc ''
                The driver {command}`hostapd` will use.
                {var}`nl80211` is used with all Linux mac80211 drivers.
                {var}`none` is used if building a standalone RADIUS server that does
                not control any wireless/wired driver.
                Most applications will probably use the default.
              '';
            };
          };
        });
      };

      ssid = mkOption {
        default = config.system.nixos.distroId;
        defaultText = literalExpression "config.system.nixos.distroId";
        example = "mySpecialSSID";
        type = types.str;
        description = lib.mdDoc "SSID to be used in IEEE 802.11 management frames.";
      };

      hwMode = mkOption {
        default = "g";
        type = types.enum ["a" "b" "g"];
        description = lib.mdDoc ''
          Operation mode.
          (a = IEEE 802.11a, b = IEEE 802.11b, g = IEEE 802.11g).
        '';
      };

      channel = mkOption {
        default = 7;
        example = 11;
        type = types.int;
        description = lib.mdDoc ''
          Channel number (IEEE 802.11)
          Please note that some drivers do not use this value from
          {command}`hostapd` and the channel will need to be configured
          separately with {command}`iwconfig`.
        '';
      };

      group = mkOption {
        default = "wheel";
        example = "network";
        type = types.str;
        description = lib.mdDoc ''
          Members of this group can control {command}`hostapd`.
        '';
      };

      wpa = mkOption {
        type = types.bool;
        default = true;
        description = lib.mdDoc ''
          Enable WPA (IEEE 802.11i/D3.0) to authenticate with the access point.
        '';
      };

      wpaPassphrase = mkOption {
        default = "my_sekret";
        example = "any_64_char_string";
        type = types.str;
        description = lib.mdDoc ''
          WPA-PSK (pre-shared-key) passphrase. Clients will need this
          passphrase to associate with this access point.
          Warning: This passphrase will get put into a world-readable file in
          the Nix store!
        '';
      };

      logLevel = mkOption {
        default = 2;
        type = types.int;
        description = lib.mdDoc ''
          Levels (minimum value for logged events):
          0 = verbose debugging
          1 = debugging
          2 = informational messages
          3 = notification
          4 = warning
        '';
      };

      countryCode = mkOption {
        default = null;
        example = "US";
        type = with types; nullOr str;
        description = lib.mdDoc ''
          Country code (ISO/IEC 3166-1). Used to set regulatory domain.
          Set as needed to indicate country in which device is operating.
          This can limit available channels and transmit power.
          These two octets are used as the first two octets of the Country String
          (dot11CountryString).
          If set this enables IEEE 802.11d. This advertises the countryCode and
          the set of allowed channels and transmit power levels based on the
          regulatory limits.
        '';
      };

      extraConfig = mkOption {
        default = "";
        example = ''
          auth_algo=0
          ieee80211n=1
          ht_capab=[HT40-][SHORT-GI-40][DSSS_CCK-40]
        '';
        type = types.lines;
        description = lib.mdDoc "Extra configuration options to put in hostapd.conf.";
      };
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.hostapd];

    services.udev.packages = optionals (cfg.countryCode != null) [pkgs.crda];

    systemd.services.hostapd = {
      description = "hostapd wireless AP";

      path = [pkgs.hostapd];
      after = ["sys-subsystem-net-devices-${escapedInterface}.device"];
      bindsTo = ["sys-subsystem-net-devices-${escapedInterface}.device"];
      requiredBy = ["network-link-${cfg.interface}.service"];
      wantedBy = ["multi-user.target"];

      preStart = lib.mkBefore ''
        grep -o '^..:..:..:..:..:..' ${config.rekey.secrets.wifi-clients.path} > /run/hostapd/client-macs
        hostapd_conf=$(cat ''${systemd.services.hostapd.serviceConfig.ExecStart})
        sae_passwords=$(echo -e "sae_password=aa|mac=13:13:13:13:13:13\nsae_password=aa|mac=12:12:12:12:12:12")
        hostapd_conf=''${hostapd_conf//"{{SAE_PASSWORDS}}"/$sae_passwords}
        echo "$hostapd_conf" > /run/hostapd/config/$interface
      '';

      serviceConfig = {
        ExecStart = "${pkgs.hostapd}/bin/hostapd ${configFile}";
        Restart = "always";
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
  };
}
