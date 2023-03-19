{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
with lib; let
  # TODO: add multi AP support (aka EasyMesh(TM))
  # TODO DFS as separate setting ?
  disabledModules = ["services/networking/hostapd.nix"];

  cfg = config.services.hostapd;

  # Escapes a string as hex (hello -> 68656c6c6f)
  escapeHex = s: toLower (stringAsChars (x: toHexString (strings.charToInt x)) s);

  # Maps the specified acl mode to values understood by hostapd
  macaddrAclModes = {
    "allow" = 0;
    "deny" = 1;
    "radius" = 2;
  };
  # Maps the specified ignore broadcast ssid mode to values understood by hostapd
  ignoreBroadcastSsidModes = {
    "disabled" = 0;
    "empty" = 1;
    "clear" = 2;
  };
  # Maps the specified vht and he channel widths to values understood by hostapd
  operatingChannelWidth = {
    "20or40" = 0;
    "80" = 1;
    "160" = 2;
    "80+80" = 3;
  };

  configFileForInterface = interface: let
    ifcfg = cfg.interfaces.${interface};
    escapedInterface = utils.escapeSystemdPath interface;
    hasMacAllowList = count ifcfg.macAllow > 0 || ifcfg.macAllowFile != null;
    hasMacDenyList = count ifcfg.macDeny > 0 || ifcfg.macDenyFile != null;
    bool01 = b:
      if b
      then "1"
      else "0";
  in
    pkgs.writeText "hostapd-${escapedInterface}.conf" ''
      logger_syslog=-1
      logger_syslog_level=${toString ifcfg.logLevel}
      logger_stdout=-1
      logger_stdout_level=${toString ifcfg.logLevel}

      interface=${interface}
      driver=${ifcfg.driver}
      ctrl_interface=/run/hostapd
      ctrl_interface_group=${ifcfg.group}

      ##### IEEE 802.11 related configuration #######################################

      ssid2=${escapeHex ifcfg.ssid}
      utf8_ssid=${ifcfg.hwMode}
      ${optionalString (ifcfg.countryCode != null) ''
        country_code=${ifcfg.countryCode}
        # IEEE 802.11d: Limit to frequencies allowed in country
        ieee80211d=1
        # IEEE 802.11h: Enable radar detection and DFS (Dynamic Frequency Selection)
        ieee80211h=1
      ''}
      hw_mode=${ifcfg.hwMode}
      channel=${toString ifcfg.channel}
      ${optionalString ifcfg.noScan "noscan=1"}
      # Set the MAC-address access control mode
      macaddr_acl=${macaddrAclModes.${ifcfg.macAcl}}
      ${optionalString hasMacAllowList ''
        accept_mac_file=/run/hostapd/mac-${escapedInterface}.allow
      ''}
      ${optionalString hasMacDenyList ''
        deny_mac_file=/run/hostapd/mac-${escapedInterface}.deny
      ''}
      # Only allow WPA, disable WEP (insecure)
      auth_algs=1
      # Set ssid broadcasting mode (0=normal, 1=empty, 2=clear)
      ignore_broadcast_ssid=${ignoreBroadcastSsidModes.${ifcfg.ignoreBroadcastSsid}}
      # Always enable QoS, which is required for 802.11n/ac/ax
      wmm_enabled=1
      # Whether to disallow clients to communicate with each other
      ap_isolate=${bool01 ifcfg.apIsolate}

      ##### IEEE 802.11n (WiFi 4) related configuration #######################################
      # MIMO and channel bonding support
      ieee80211n=${bool01 ifcfg.ieee80211n}
      ht_capab=${concatMapStrings (x: "[${x}]") ifcfg.htCapab}
      require_ht=${bool01 ifcfg.requireHt}

      ##### IEEE 802.11ac (WiFi 5) related configuration #####################################

      ieee80211ac=${bool01 ifcfg.ieee80211ac}
      vht_capab=${concatMapStrings (x: "[${x}]") ifcfg.vhtCapab}
      require_vht=${bool01 ifcfg.requireVht}
      vht_oper_chwidth=${operatingChannelWidth.${ifcfg.vhtOperatingChannelWidth}}

      ##### IEEE 802.11ax (WiFi 6) related configuration #####################################

      ieee80211ax=${bool01 ifcfg.ieee80211ax}
      require_he=${bool01 ifcfg.requireHe}
      he_oper_chwidth=${operatingChannelWidth.${ifcfg.heOperatingChannelWidth}}
      he_su_beamformer=${bool01 ifcfg.heSuBeamformer}
      he_su_beamformee=${bool01 ifcfg.heSuBeamformee}
      he_mu_beamformer=${bool01 ifcfg.heMuBeamformer}

      ##### IEEE 802.11be (WiFi 7) related configuration #####################################

      ieee80211be=${bool01 ifcfg.ieee80211be}
      eht_oper_chwidth=${operatingChannelWidth.${ifcfg.ehtOperatingChannelWidth}}
      eht_su_beamformer=${bool01 ifcfg.ehtSuBeamformer}
      eht_su_beamformee=${bool01 ifcfg.ehtSuBeamformee}
      eht_mu_beamformer=${bool01 ifcfg.ehtMuBeamformer}

      ##### WPA/IEEE 802.11i configuration ##########################################

      # WPA3
      wpa=2
      wpa_pairwise=CCMP CCMP-256
      rsn_pairwise=CCMP CCMP-256
      wpa_key_mgmt=SAE
      # Encrypt management frames to protect against deauthentication and similar attacks
      ieee80211w=2
      # Force WPA3-Personal without transition
      transition_disable=0x01
      # Derive PWE using both hunting-and-pecking loop and hash-to-element
      sae_pwe=2
      # SAE passwords can be set via wpa_passphrase but not via wpa_psk_file. This sucks
      # and means we have to add the passwords in pre-start to prevent them being visible here
      {{SAE_PASSWORDS}}

      ${ifcfg.extraConfig}
    '';
in {
  options = {
    services.hostapd = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc ''
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
        description = mdDoc ''
          This option allows you to define APs for one or multiple interfaces.
          Each attribute specifies a interface and associates it to its configuration.
          At least one interface must be specified.

          Each interface can only support a single hardware-mode that is configured via
          ({option}`services.hostapd.interfaces.<name>.hwMode`). To create a dual-band
          or tri-band AP, you will have to use a device that supports configuring multiple APs
          (Refer to valid interface combinations in {command}`iw list`). For each mode hostapd
          requires a separate logical interface (like wlp3s0, wlp3s1, ...). Often this needs
          to be configured manually by utilizing udev rules - details will differ for each device.
          Alternatively, one can also just use distinct devices for each mode.
        '';
        type = types.attrsOf (types.submodule {
          options = {
            noScan = mkOption {
              type = types.bool;
              default = false;
              description = mdDoc ''
                Disables scan for overlapping BSSs in HT40+/- mode.
                Caution: turning this on will likely violate regulatory requirements!
              '';
            };

            driver = mkOption {
              default = "nl80211";
              example = "none";
              type = types.str;
              description = mdDoc ''
                The driver {command}`hostapd` will use.
                {var}`nl80211` is used with all Linux mac80211 drivers.
                {var}`none` is used if building a standalone RADIUS server that does
                not control any wireless/wired driver.
                Most applications will probably use the default.
              '';
            };

            logLevel = mkOption {
              default = 2;
              type = types.int;
              description = mdDoc ''
                Levels (minimum value for logged events):
                0 = verbose debugging
                1 = debugging
                2 = informational messages
                3 = notification
                4 = warning
              '';
            };

            group = mkOption {
              default = "wheel";
              example = "network";
              type = types.str;
              description = mdDoc ''
                Members of this group can access the control socket for this interface.
              '';
            };

            utf8Ssid = mkOption {
              default = true;
              type = types.bool;
              description = mdDoc "Whether the SSID is to be interpreted using UTF-8 encoding";
            };

            ssid = mkOption {
              default = config.system.nixos.distroId;
              defaultText = literalExpression "config.system.nixos.distroId";
              example = "mySpecialSSID";
              type = types.str;
              description = mdDoc "SSID to be used in IEEE 802.11 management frames.";
            };

            countryCode = mkOption {
              default = null;
              example = "US";
              type = types.nullOr types.str;
              description = mdDoc ''
                Country code (ISO/IEC 3166-1). Used to set regulatory domain.
                Set as needed to indicate country in which device is operating.
                This can limit available channels and transmit power.
                These two octets are used as the first two octets of the Country String
                (dot11CountryString).

                Setting this will force you to also enable IEEE 802.11d and IEEE 802.11h.

                IEEE 802.11d: This advertises the countryCode and the set of allowed channels
                and transmit power levels based on the regulatory limits.

                IEEE802.11h: This enables radar detection and DFS (Dynamic Frequency Selection)
                support if available. DFS support is required on outdoor 5 GHz channels in most
                countries of the world.
              '';
            };

            hwMode = mkOption {
              default = "g";
              type = types.enum ["a" "b" "g" "ad" "any"];
              description = mdDoc ''
                Operation mode (a = IEEE 802.11a (5 GHz), b = IEEE 802.11b (2.4 GHz),
                g = IEEE 802.11g (2.4 GHz), ad = IEEE 802.11ad (60 GHz); a/g options are used
                with IEEE 802.11n (HT), too, to specify band). For IEEE 802.11ac (VHT), this
                needs to be set to hw_mode=a. For IEEE 802.11ax (HE) on 6 GHz this needs
                to be set to hw_mode=a. When using ACS (see channel parameter), a
                special value "any" can be used to indicate that any support band can be used.
                This special case is currently supported only with drivers with which
                offloaded ACS is used.

                Most likely you to select a (5GHz & 6GHz a/n/ac/ax) or g (2Ghz b/g/n) here.
              '';
            };

            channel = mkOption {
              default = 7;
              example = 11;
              type = types.int;
              description = mdDoc ''
                The channel to operate on. Use 0 to enable ACS (Automatic Channel Selection).
                Beware that not every device supports ACS in which case {command}`hostapd`
                will fail to start.
              '';
            };

            macAcl = mkOption {
              default = "allow";
              type = types.enum ["allow" "deny" "radius"];
              description = mdDoc ''
                Station MAC address -based authentication. The following modes are available:

                - {var}`"allow"`: Allow unless listed in {option}`macDeny` (default)
                - {var}`"deny"`: Deny unless listed in {option}`macAllow`
                - {var}`"radius"`: Use external radius server, but check both {option}`macAllow` and {option}`macDeny` first

                Please note that this kind of access control requires a driver that uses
                hostapd to take care of management frame processing and as such, this can be
                used with driver=hostap or driver=nl80211, but not with driver=atheros.
              '';
            };

            macAllow = mkOption {
              type = types.listOf types.str;
              default = [];
              example = ["11:22:33:44:55:66"];
              description = mdDoc ''
                Specifies the MAC addresses to allow if {option}`macAcl` is set to {var}`"deny"` or {var}`"radius"`.
                These values will be world-readable in the Nix store. Values will automatically be merged with
                {option}`macAllowFile` if necessary.
              '';
            };

            macAllowFile = mkOption {
              type = types.uniq (types.nullOr types.path);
              default = null;
              description = mdDoc ''
                Specifies a file containing the MAC addresses to allow if {option}`macAcl` is set to {var}`"deny"` or {var}`"radius"`.
                The file should contain exactly one MAC address per line. Comments and empty lines are ignored,
                only lines matching the regex `^..:..:..:..:..:..\b` will be considered.
                Any content after the MAC address is ignored.
              '';
            };

            macDeny = mkOption {
              type = types.listOf types.str;
              default = [];
              example = ["11:22:33:44:55:66"];
              description = mdDoc ''
                Specifies the MAC addresses to deny if {option}`macAcl` is set to {var}`"allow"` or {var}`"radius"`.
                These values will be world-readable in the Nix store. Values will automatically be merged with
                {option}`macDenyFile` if necessary.
              '';
            };

            macDenyFile = mkOption {
              type = types.uniq (types.nullOr types.path);
              default = null;
              description = mdDoc ''
                Specifies a file containing the MAC addresses to allow if {option}`macAcl` is set to {var}`"deny"` or {var}`"radius"`.
                The file should contain exactly one MAC address per line. Comments and empty lines are ignored,
                only lines matching the regex `^..:..:..:..:..:..\b` will be considered.
                Any content after the MAC address is ignored.
              '';
            };

            ignoreBroadcastSsid = mkOption {
              default = "disabled";
              type = types.enum ["disabled" "empty" "clear"];
              description = mdDoc ''
                Send empty SSID in beacons and ignore probe request frames that do not
                specify full SSID, i.e., require stations to know SSID.

                - {var}`"disabled"`: Advertise ssid normally.
                - {var}`"empty"`: send empty (length=0) SSID in beacon and ignore probe request for broadcast SSID
                - {var}`"clear"`: clear SSID (ASCII 0), but keep the original length (this may be required with some
                  legacy clients that do not support empty SSID) and ignore probe requests for broadcast SSID. Only
                  use this if empty does not work with your clients.
              '';
            };

            apIsolate = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc ''
                Isolate traffic between stations (clients) and prevent
                them from communicating with each other.
              '';
            };

            extraConfig = mkOption {
              default = "";
              example = ''
                multi_ap=1
              '';
              type = types.lines;
              description = mdDoc "Extra configuration options to put in hostapd.conf.";
            };

            #### IEEE 802.11n (WiFi 4) related configuration

            ieee80211n = mkOption {
              default = true;
              type = types.bool;
              description = mdDoc "Enables support for IEEE 802.11n (WiFi 4, HT)";
            };

            htCapab = mkOption {
              type = types.listOf types.str;
              default = ["HT40" "HT40-" "SHORT-GI-20" "SHORT-GI-40"];
              example = ["LDPC" "HT40+" "HT40-" "GF" "SHORT-GI-20" "SHORT-GI-40" "TX-STBC" "RX-STBC1"];
              description = mdDoc ''
                HT (High Throughput) capabilities given as a list of flags.
                Please refer to the hostapd documentation for allowed values and
                only set values supported by your physical adapter.

                The default contains common values supported by most adapters.
              '';
            };

            requireHt = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "Require stations (clients) to support WiFi 4 (HT) and disassociate them if they don't.";
            };

            #### IEEE 802.11ac (WiFi 5) related configuration

            ieee80211ac = mkOption {
              default = true;
              type = types.bool;
              description = mdDoc "Enables support for IEEE 802.11ac (WiFi 5, VHT)";
            };

            vhtCapab = mkOption {
              type = types.listOf types.str;
              default = [];
              example = ["SHORT-GI-80" "TX-STBC-2BY1" "RX-STBC-1" "RX-ANTENNA-PATTERN" "TX-ANTENNA-PATTERN"];
              description = mdDoc ''
                VHT (Very High Throughput) capabilities given as a list of flags.
                Please refer to the hostapd documentation for allowed values and
                only set values supported by your physical adapter.
              '';
            };

            requireVht = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "Require stations (clients) to support WiFi 5 (VHT) and disassociate them if they don't.";
            };

            vhtOperatingChannelWidth = mkOption {
              default = "20or40";
              type = types.enum ["20or40" "80" "160" "80+80"];
              description = mdDoc ''
                Determines the operating channel width for VHT.

                - {var}`"20or40"`: 20 or 40 MHz operating channel width
                - {var}`"80"`: 80 MHz channel width
                - {var}`"160"`: 160 MHz channel width
                - {var}`"80+80"`: 80+80 MHz channel width
              '';
            };

            ##### IEEE 802.11ax (WiFi 6) related configuration

            ieee80211ax = mkOption {
              default = true;
              type = types.bool;
              description = mdDoc "Enables support for IEEE 802.11ax (WiFi 6, HE)";
            };

            requireHe = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "Require stations (clients) to support WiFi 6 (HE) and disassociate them if they don't.";
            };

            heSuBeamformer = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "HE single user beamformer support";
            };

            heSuBeamformee = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "HE single user beamformee support";
            };

            heMuBeamformer = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "HE multi user beamformee support";
            };

            heOperatingChannelWidth = mkOption {
              default = "20or40";
              type = types.enum ["20or40" "80" "160" "80+80"];
              description = mdDoc ''
                Determines the operating channel width for HE.

                - {var}`"20or40"`: 20 or 40 MHz operating channel width
                - {var}`"80"`: 80 MHz channel width
                - {var}`"160"`: 160 MHz channel width
                - {var}`"80+80"`: 80+80 MHz channel width
              '';
            };

            ##### IEEE 802.11be (WiFi 7) related configuration

            ieee80211be = mkOption {
              default = true;
              type = types.bool;
              description = mdDoc "Enables support for IEEE 802.11be (WiFi 7, EHT)";
            };

            ehtSuBeamformer = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "EHT single user beamformer support";
            };

            ehtSuBeamformee = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "EHT single user beamformee support";
            };

            ehtMuBeamformer = mkOption {
              default = false;
              type = types.bool;
              description = mdDoc "EHT multi user beamformee support";
            };

            ehtOperatingChannelWidth = mkOption {
              default = "20or40";
              type = types.enum ["20or40" "80" "160" "80+80"];
              description = mdDoc ''
                Determines the operating channel width for EHT.

                - {var}`"20or40"`: 20 or 40 MHz operating channel width
                - {var}`"80"`: 80 MHz channel width
                - {var}`"160"`: 160 MHz channel width
                - {var}`"80+80"`: 80+80 MHz channel width
              '';
            };
          };
        });
      };

      #wpa = mkOption {
      #  type = types.bool;
      #  default = true;
      #  description = mdDoc ''
      #    Enable WPA (IEEE 802.11i/D3.0) to authenticate with the access point.
      #  '';
      #};

      #wpaPassphrase = mkOption {
      #  default = "my_sekret";
      #  example = "any_64_char_string";
      #  type = types.str;
      #  description = mdDoc ''
      #    WPA-PSK (pre-shared-key) passphrase. Clients will need this
      #    passphrase to associate with this access point.
      #    Warning: This passphrase will get put into a world-readable file in
      #    the Nix store!
      #  '';
      #};
    };
  };

  ###### implementation

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = count cfg.interfaces > 0;
        message = "At least one interface must be configured with hostapd!";
      }
    ];

    environment.systemPackages = [pkgs.hostapd];

    services.udev.packages = optionals (cfg.countryCode != null) [pkgs.crda];

    systemd.services.hostapd = {
      description = "hostapd wireless AP";

      path = [pkgs.hostapd];
      after = ["sys-subsystem-net-devices-${escapedInterface}.device"];
      bindsTo = ["sys-subsystem-net-devices-${escapedInterface}.device"];
      requiredBy = ["network-link-${cfg.interface}.service"];
      wantedBy = ["multi-user.target"];

      preStart = mkBefore ''
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
