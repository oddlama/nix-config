{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  inherit
    (lib)
    any
    attrValues
    concatLists
    concatMapStrings
    concatStringsSep
    count
    escapeShellArg
    filter
    literalExpression
    mapAttrsToList
    mdDoc
    mkIf
    mkOption
    optional
    optionals
    optionalString
    stringLength
    toLower
    types
    ;

  cfg = config.services.hostapd;

  # Maps the specified acl mode to values understood by hostapd
  macaddrAclModes = {
    "allow" = "0";
    "deny" = "1";
    "radius" = "2";
  };

  # Maps the specified ignore broadcast ssid mode to values understood by hostapd
  ignoreBroadcastSsidModes = {
    "disabled" = "0";
    "empty" = "1";
    "clear" = "2";
  };

  # Maps the specified vht and he channel widths to values understood by hostapd
  operatingChannelWidth = {
    "20or40" = "0";
    "80" = "1";
    "160" = "2";
    "80+80" = "3";
  };

  # Maps the specified vht and he channel widths to values understood by hostapd
  managementFrameProtection = {
    "disabled" = "0";
    "optional" = "1";
    "required" = "2";
  };

  bool01 = b:
    if b
    then "1"
    else "0";

  configFileForInterface = interface: ifcfg:
    pkgs.writeText "hostapd-${interface}.conf" ''
      logger_syslog=-1
      logger_syslog_level=${toString ifcfg.logLevel}
      logger_stdout=-1
      logger_stdout_level=${toString ifcfg.logLevel}

      interface=${interface}
      driver=${ifcfg.driver}
      ctrl_interface=/run/hostapd
      ctrl_interface_group=${ifcfg.group}

      ##### IEEE 802.11 general configuration #######################################

      ssid=${ifcfg.ssid}
      utf8_ssid=${bool01 ifcfg.utf8Ssid}
      ${optionalString (ifcfg.countryCode != null) ''
        country_code=${ifcfg.countryCode}
        # IEEE 802.11d: Limit to frequencies allowed in country
        ieee80211d=1
        # IEEE 802.11h: Enable radar detection and DFS (Dynamic Frequency Selection)
        ieee80211h=1
      ''}
      hw_mode=${ifcfg.hwMode}
      channel=${toString ifcfg.channel}
      noscan=${bool01 ifcfg.noScan}
      # Set the MAC-address access control mode
      macaddr_acl=${macaddrAclModes.${ifcfg.macAcl}}
      ${optionalString (ifcfg.macAllow != [] || ifcfg.macAllowFile != null || ifcfg.authentication.saeAddToMacAllow) ''
        accept_mac_file=/run/hostapd/${interface}.mac.allow
      ''}
      ${optionalString (ifcfg.macDeny != [] || ifcfg.macDenyFile != null) ''
        deny_mac_file=/run/hostapd/${interface}.mac.deny
      ''}
      # Only allow WPA, disable insecure WEP
      auth_algs=1
      ignore_broadcast_ssid=${ignoreBroadcastSsidModes.${ifcfg.ignoreBroadcastSsid}}
      # Always enable QoS, which is required for 802.11n and above
      wmm_enabled=1
      ap_isolate=${bool01 ifcfg.apIsolate}

      ##### IEEE 802.11n (WiFi 4) related configuration #######################################

      ieee80211n=${bool01 ifcfg.wifi4.enable}
      ${optionalString ifcfg.wifi4.enable ''
        ht_capab=${concatMapStrings (x: "[${x}]") ifcfg.wifi4.capabilities}
        require_ht=${bool01 ifcfg.wifi4.require}
      ''}

      ${optionalString ifcfg.wifi5.enable ''
        ##### IEEE 802.11ac (WiFi 5) related configuration #####################################

        ieee80211ac=1
        vht_capab=${concatMapStrings (x: "[${x}]") ifcfg.wifi5.capabilities}
        require_vht=${bool01 ifcfg.wifi5.require}
        vht_oper_chwidth=${operatingChannelWidth.${ifcfg.wifi5.operatingChannelWidth}}
      ''}
      ${optionalString ifcfg.wifi6.enable ''
        ##### IEEE 802.11ax (WiFi 6) related configuration #####################################

        ieee80211ax=1
        require_he=${bool01 ifcfg.wifi6.require}
        he_oper_chwidth=${operatingChannelWidth.${ifcfg.wifi6.operatingChannelWidth}}
        he_su_beamformer=${bool01 ifcfg.wifi6.singleUserBeamformer}
        he_su_beamformee=${bool01 ifcfg.wifi6.singleUserBeamformee}
        he_mu_beamformer=${bool01 ifcfg.wifi6.multiUserBeamformer}
      ''}
      ${optionalString ifcfg.wifi7.enable ''
        ##### IEEE 802.11be (WiFi 7) related configuration #####################################

        ieee80211be=1
        eht_oper_chwidth=${operatingChannelWidth.${ifcfg.wifi7.operatingChannelWidth}}
        eht_su_beamformer=${bool01 ifcfg.wifi7.singleUserBeamformer}
        eht_su_beamformee=${bool01 ifcfg.wifi7.singleUserBeamformee}
        eht_mu_beamformer=${bool01 ifcfg.wifi7.multiUserBeamformer}
      ''}

      ##### WPA/IEEE 802.11i configuration ##########################################

      # Encrypt management frames to protect against deauthentication and similar attacks
      ieee80211w=${managementFrameProtection.${ifcfg.managementFrameProtection}}
      ${optionalString (ifcfg.authentication.mode == "none") ''
        wpa=0
      ''}
      ${optionalString (ifcfg.authentication.mode == "wpa3-sae") ''
        wpa=2
        wpa_key_mgmt=SAE
        # Derive PWE using both hunting-and-pecking loop and hash-to-element
        sae_pwe=2
        # Prevent downgrade attacks by indicating to clients that they should
        # disable any transition modes from now on.
        transition_disable=0x01
      ''}
      ${optionalString (ifcfg.authentication.mode == "wpa3-sae-transition") ''
        wpa=2
        wpa_key_mgmt=WPA-PSK-SHA256 SAE
      ''}
      ${optionalString (ifcfg.authentication.mode == "wpa2-sha256") ''
        wpa=2
        wpa_key_mgmt=WPA-PSK-SHA256
      ''}
      ${optionalString (ifcfg.authentication.mode != "none") ''
        wpa_pairwise=${concatStringsSep " " ifcfg.authentication.pairwiseCiphers}
        rsn_pairwise=${concatStringsSep " " ifcfg.authentication.pairwiseCiphers}
      ''}

      ${optionalString (ifcfg.authentication.wpaPassword != null) ''
        wpa_passphrase=${ifcfg.authentication.wpaPassword}
      ''}
      ${optionalString (ifcfg.authentication.wpaPskFile != null) ''
        wpa_passphrase=${ifcfg.authentication.wpaPskFile}
      ''}
      ${optionalString (ifcfg.authentication.saePasswords != []) (concatMapStrings (pw: "sae_password=${pw}\n") ifcfg.authentication.saePasswords)}
    '';

  makeInterfaceRuntimeFiles = interface: ifcfg: let
    # All MAC addresses from SAE entries that aren't the wildcard address
    saeMacs = filter (mac: mac != null && (toLower mac) != "ff:ff:ff:ff:ff:ff") (map (x: x.mac) ifcfg.authentication.saePasswords);
  in
    pkgs.writeShellScript "make-hostapd-${interface}-files" (''
        set -euo pipefail

        mac_allow_file=/run/hostapd/${escapeShellArg interface}.mac.allow
        mac_deny_file=/run/hostapd/${escapeShellArg interface}.mac.deny
        hostapd_config_file=/run/hostapd/${escapeShellArg interface}.hostapd.conf

        rm -f "$mac_allow_file"
        touch "$mac_allow_file"
        rm -f "$mac_deny_file"
        touch "$mac_deny_file"
        rm -f "$hostapd_config_file"
        cp ${configFileForInterface interface ifcfg} "$hostapd_config_file"

      ''
      + concatStringsSep "\n" (
        optional (ifcfg.macAllow != []) ''
          cat >> "$mac_allow_file" <<EOF
          ${concatStringsSep "\n" ifcfg.macAllow}
          EOF
        ''
        ++ optional (ifcfg.macAllowFile != null) ''
          grep -Eo '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})' ${escapeShellArg ifcfg.macAllowFile} >> "$mac_allow_file"
        ''
        # Populate mac allow list from saePasswords
        ++ optional (ifcfg.authentication.saeAddToMacAllow && saeMacs != []) ''
          cat >> "$mac_allow_file" <<EOF
          ${concatStringsSep "\n" saeMacs}
          EOF
        ''
        # Populate mac allow list from saePasswordsFile
        # (filter for lines with mac=;  exclude commented lines; filter for real mac-addresses; strip mac=)
        ++ optional (ifcfg.authentication.saeAddToMacAllow && ifcfg.authentication.saePasswordsFile != null) ''
          grep mac= ${escapeShellArg ifcfg.authentication.saePasswordsFile} \
            | grep -v '\s*#' \
            | grep -Eo 'mac=([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})' \
            | sed 's|^mac=||' >> "$mac_allow_file"
        ''
        # Create combined mac.deny list from macDeny and macDenyFile
        ++ optional (ifcfg.macDeny != []) ''
          cat >> "$mac_deny_file" <<EOF
          ${concatStringsSep "\n" ifcfg.macDeny}
          EOF
        ''
        ++ optional (ifcfg.macDenyFile != null) ''
          grep -Eo '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})' ${escapeShellArg ifcfg.macDenyFile} >> "$mac_deny_file"
        ''
        # Add WPA passphrase from file if necessary
        ++ optional (ifcfg.authentication.wpaPasswordFile != null) ''
          cat >> "$hostapd_config_file" <<EOF
          wpa_passphrase=$(cat ${escapeShellArg ifcfg.authentication.wpaPasswordFile})
          EOF
        ''
        # Add SAE passwords from file if necessary
        ++ optional (ifcfg.authentication.saePasswordsFile != null) ''
          grep -v '\s*#' ${escapeShellArg ifcfg.authentication.saePasswordsFile} \
            | sed 's/^/sae_password=/' >> "$hostapd_config_file"
        ''
        # Finally append extraConfig if necessary.
        ++ optional (ifcfg.extraConfig != "") ''
          cat >> "$hostapd_config_file" <<EOF

          ##### User-provided extra configuration ##########################################

          EOF
          cat ${escapeShellArg (pkgs.writeText ifcfg.extraConfig)} >> "$hostapd_config_file"
        ''
      ));

  runtimeConfigFiles = mapAttrsToList (i: _: "/run/hostapd/${i}.hostapd.conf") cfg.interfaces;
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
            # Simple 2.4GHz AP
            "wlp2s0" = {
              ssid = "AP 1";
              # countryCode = "US";
              authentication.saePasswords = [{ password = "a flakey password"; }]; # Use saePasswordsFile if possible.
            };

            # WiFi 5 (5GHz)
            "wlp4s0" = {
              ssid = "Open AP with WiFi5";
              # countryCode = "US";
              hwMode = "a";
              authentication.mode = "none";
            };

            # Legacy WPA2 example
            "wlp5s0" = {
              ssid = "AP 2";
              # countryCode = "US";
              channel = 0; # Enables automatic channel selection ACS. Use only if your hardware support's it.
              authentication = {
                mode = "wpa2-sha256";
                wpaPassword = "a flakey password"; # Use wpaPasswordFile if possible.
              };
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
              example = "❄️ cool ❄️";
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

                Most likely you to select 'a' (5GHz & 6GHz a/n/ac/ax) or 'g' (2.4GHz b/g/n) here.
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
                only lines starting with a valid MAC address will be considered (e.g. `11:22:33:44:55:66`) and
                any content after the MAC address is ignored.
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
                only lines starting with a valid MAC address will be considered (e.g. `11:22:33:44:55:66`) and
                any content after the MAC address is ignored.
              '';
            };

            ignoreBroadcastSsid = mkOption {
              default = "disabled";
              type = types.enum ["disabled" "empty" "clear"];
              description = mdDoc ''
                Send empty SSID in beacons and ignore probe request frames that do not
                specify full SSID, i.e., require stations to know SSID. Note that this does
                not increase security, since your clients will then broadcast the SSID instead,
                which can increase congestion.

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
                Isolate traffic between stations (clients) and prevent them from
                communicating with each other.
              '';
            };

            extraConfig = mkOption {
              default = "";
              example = ''
                multi_ap=1
              '';
              type = types.lines;
              description = mdDoc "Extra configuration options to put at the end of this interface's hostapd.conf.";
            };

            #### IEEE 802.11i (WPA) configuration

            authentication = {
              mode = mkOption {
                default = "wpa3-sae";
                type = types.enum ["none" "wpa2-sha256" "wpa3-sae-transition" "wpa3-sae"];
                description = mdDoc ''
                  Selects the authentication mode for this AP.

                  - {var}`"none"`: Don't configure any authentication. This will disable wpa alltogether
                    and create an open AP. Use {option}`extraConfig` together with this option if you
                    want to configure the authentication manually. Any password options will still be
                    effective, if set.
                  - {var}`"wpa2-sha256"`: WPA2-Personal using SHA256 (IEEE 802.11i/RSN). Passwords are set
                    using {option}`wpaPassword` or preferably by {option}`wpaPasswordFile` or {option}`wpaPskFile`.
                  - {var}`"wpa3-sae-transition"`: Use WPA3-Personal (SAE) if possible, otherwise fallback
                    to WPA2-SHA256. Only use if necessary and switch to the newer WPA3-SAE when possible.
                    You will have to specify both {option}`wpaPassword` and {option}`saePasswords` (or one of their alternatives).
                  - {var}`"wpa3-sae"`: Use WPA3-Personal (SAE). This is currently the recommended way to
                    setup a secured WiFi AP (as of March 2023) and therefore the default. Passwords are set
                    using either {option}`saePasswords` or preferably {option}`saePasswordsFile`.
                '';
              };

              pairwiseCiphers = mkOption {
                default = ["CCMP" "CCMP-256" "GCMP" "GCMP-256"];
                example = ["CCMP-256" "GCMP-256"];
                type = types.listOf types.str;
                description = mdDoc ''
                  Set of accepted cipher suites (encryption algorithms) for pairwise keys (unicast packets).
                  Please refer to the hostapd documentation for allowed values. Generally, only
                  CCMP or GCMP modes should be considered safe options. Most devices support CCMP while
                  GCMP is often only available when using devices supporting WiFi 5 (IEEE 802.11ac) or higher.
                '';
              };

              wpaPassword = mkOption {
                default = null;
                example = "a flakey password";
                type = types.uniq (types.nullOr types.str);
                description = mdDoc ''
                  Sets the password for WPA-PSK that will be converted to the pre-shared key.
                  The password length must be in the range [8, 63] characters. While some devices
                  may allow arbitrary characters (such as UTF-8) to be used, but the standard specifies
                  that each character in the passphrase must be an ASCII character in the range [0x20, 0x7e]
                  (IEEE Std. 802.11i-2004, Annex H.4.1). Use emojis at your own risk.

                  Not used when {option}`mode` is {var}`"wpa3-sae"`.

                  Warning: This password will get put into a world-readable file in the Nix store!
                  Using {option}`wpaPasswordFile` or {option}`wpaPskFile` instead is recommended.
                '';
              };

              wpaPasswordFile = mkOption {
                default = null;
                type = types.uniq (types.nullOr types.path);
                description = mdDoc ''
                  Sets the password for WPA-PSK. Follows the same rules as {option}`wpaPassword`,
                  but reads the password from the given file to prevent the password from being
                  put into the Nix store.

                  Not used when {option}`mode` is {var}`"wpa3-sae"`.
                '';
              };

              wpaPskFile = mkOption {
                default = null;
                type = types.uniq (types.nullOr types.path);
                description = mdDoc ''
                  Sets the password(s) for WPA-PSK. Similar to {option}`wpaPasswordFile`,
                  but additionally allows specifying multiple passwords, and some other options.

                  Each line, except for empty lines and lines starting with #, must contain a
                  MAC address and either a 64-hex-digit PSK or a password separated with a space.
                  The password must follow the same rules as outlined in {option}`wpaPassword`.
                  The special MAC address `00:00:00:00:00:00` can be used to configure PSKs
                  that any client can use.

                  An optional key identifier can be added by prefixing the line with `keyid=<keyid_string>`
                  An optional VLAN ID can be specified by prefixing the line with `vlanid=<VLAN ID>`.
                  An optional WPS tag can be added by prefixing the line with `wps=<0/1>` (default: 0).
                  Any matching entry with that tag will be used when generating a PSK for a WPS Enrollee
                  instead of generating a new random per-Enrollee PSK.

                  Not used when {option}`mode` is {var}`"wpa3-sae"`.
                '';
              };

              saePasswords = mkOption {
                default = [];
                example = literalExpression ''
                  [
                    # Any client may use these passwords
                    { password = "Wi-Figure it out"; }
                    { password = "second password for everyone"; mac = "ff:ff:ff:ff:ff:ff"; }

                    # Only the client with MAC-address 11:22:33:44:55:66 can use this password
                    { password = "sekret pazzword"; mac = "11:22:33:44:55:66"; }
                  ]
                '';
                description = mdDoc ''
                  Sets allowed passwords for WPA3-SAE.

                  The last matching (based on peer MAC address and identifier) entry is used to
                  select which password to use. An empty string has the special meaning of
                  removing all previously added entries.

                  Warning: These entries will get put into a world-readable file in
                  the Nix store! Using {option}`saePasswordFile` instead is recommended.

                  Not used when {option}`mode` is {var}`"wpa2-sha256"`.
                '';
                type = types.listOf (types.submodule {
                  options = {
                    password = mkOption {
                      example = "a flakey password";
                      type = types.str;
                      description = mdDoc ''
                        The password for this entry. SAE technically imposes no restrictions on
                        password length or character set. But due to limitations of {command}`hostapd`'s
                        config file format, a true newline character cannot be parsed.

                        Warning: This password will get put into a world-readable file in
                        the Nix store! Using {option}`wpaPasswordFile` or {option}`wpaPskFile` is recommended.
                      '';
                    };

                    mac = mkOption {
                      default = null;
                      example = "11:22:33:44:55:66";
                      type = types.uniq (types.nullOr types.str);
                      description = mdDoc ''
                        If this attribute is not included, or if is set to the wildcard address (`ff:ff:ff:ff:ff:ff`),
                        the entry is available for any station (client) to use. If a specific peer MAC address is included,
                        only a station with that MAC address is allowed to use the entry.
                      '';
                    };

                    vlanid = mkOption {
                      default = null;
                      example = 1;
                      type = types.uniq (types.nullOr types.int);
                      description = mdDoc "If this attribute is given, all clients using this entry will get tagged with the given VLAN ID.";
                    };

                    pk = mkOption {
                      default = null;
                      example = "";
                      type = types.uniq (types.nullOr types.str);
                      description = mdDoc ''
                        If this attribute is given, SAE-PK will be enabled for this connection.
                        This prevents evil-twin attacks, but a public key is required additionally to connect.
                        (Essentially adds pubkey authentication such that the client can verify identity of the AP)
                      '';
                    };

                    id = mkOption {
                      default = null;
                      example = "";
                      type = types.uniq (types.nullOr types.str);
                      description = mdDoc ''
                        If this attribute is given with non-zero length, it will set the password identifier
                        for this entry. It can then only be used with that identifier.
                      '';
                    };
                  };
                });
              };

              saePasswordsFile = mkOption {
                default = null;
                type = types.uniq (types.nullOr types.path);
                description = mdDoc ''
                  Sets the password for WPA3-SAE. Follows the same rules as {option}`saePasswords`,
                  but reads the entries from the given file to prevent them from being
                  put into the Nix store.

                  One entry per line, empty lines and lines beginning with # will be ignored.
                  Each line must match the following format, although the order of optional
                  parameters doesn't matter:
                  `<password>[|mac=<peer mac>][|vlanid=<VLAN ID>][|pk=<m:ECPrivateKey-base64>][|id=<identifier>]`

                  Not used when {option}`mode` is {var}`"wpa2-sha256"`.
                '';
              };

              saeAddToMacAllow = mkOption {
                type = types.bool;
                default = false;
                description = mdDoc ''
                  If set, all sae password entries that have a non-wildcard MAC associated to
                  them will additionally be used to populate the MAC allow list. This is
                  additional to any entries set via {option}`macAllow` or {option}`macAllowFile`.
                '';
              };
            };

            managementFrameProtection = mkOption {
              default = "required";
              type = types.enum ["disabled" "optional" "required"];
              description = mdDoc ''
                Management frame protection (MFP) authenticates management frames
                to prevent deauthentication (or related) attacks.

                - {var}`"disabled"`: No management frame protection
                - {var}`"optional"`: Use MFP if a connection allows it
                - {var}`"required"`: Force MFP for all clients
              '';
            };

            #### IEEE 802.11n (WiFi 4) related configuration

            wifi4 = {
              enable = mkOption {
                default = true;
                type = types.bool;
                description = mdDoc ''
                  Enables support for IEEE 802.11n (WiFi 4, HT).
                  This is enabled by default, since the vase majority of devices
                  are expected to support this.
                '';
              };

              capabilities = mkOption {
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

              require = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "Require stations (clients) to support WiFi 4 (HT) and disassociate them if they don't.";
              };
            };

            #### IEEE 802.11ac (WiFi 5) related configuration

            wifi5 = {
              enable = mkOption {
                default = true;
                type = types.bool;
                description = mdDoc "Enables support for IEEE 802.11ac (WiFi 5, VHT)";
              };

              capabilities = mkOption {
                type = types.listOf types.str;
                default = [];
                example = ["SHORT-GI-80" "TX-STBC-2BY1" "RX-STBC-1" "RX-ANTENNA-PATTERN" "TX-ANTENNA-PATTERN"];
                description = mdDoc ''
                  VHT (Very High Throughput) capabilities given as a list of flags.
                  Please refer to the hostapd documentation for allowed values and
                  only set values supported by your physical adapter.
                '';
              };

              require = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "Require stations (clients) to support WiFi 5 (VHT) and disassociate them if they don't.";
              };

              operatingChannelWidth = mkOption {
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
            };

            #### IEEE 802.11ax (WiFi 6) related configuration

            wifi6 = {
              enable = mkOption {
                # TODO Change this once WiFi 6 is enabled in hostapd upstream
                default = false;
                type = types.bool;
                description = mdDoc "Enables support for IEEE 802.11ax (WiFi 6, HE)";
              };

              require = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "Require stations (clients) to support WiFi 6 (HE) and disassociate them if they don't.";
              };

              singleUserBeamformer = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "HE single user beamformer support";
              };

              singleUserBeamformee = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "HE single user beamformee support";
              };

              multiUserBeamformer = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "HE multi user beamformee support";
              };

              operatingChannelWidth = mkOption {
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
            };

            #### IEEE 802.11be (WiFi 7) related configuration

            wifi7 = {
              enable = mkOption {
                # FIXME: Change this to true once WiFi 7 is stable and hostapd is built with CONFIG_IEEE80211BE by default
                default = false;
                type = types.bool;
                description = mdDoc ''
                  Enables support for IEEE 802.11be (WiFi 7, EHT). This is currently experimental
                  and requires you to manually enable CONFIG_IEEE80211BE when building hostapd.
                '';
              };

              singleUserBeamformer = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "EHT single user beamformer support";
              };

              singleUserBeamformee = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "EHT single user beamformee support";
              };

              multiUserBeamformer = mkOption {
                default = false;
                type = types.bool;
                description = mdDoc "EHT multi user beamformee support";
              };

              operatingChannelWidth = mkOption {
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
          };
        });
      };
    };
  };

  config = mkIf cfg.enable {
    assertions =
      [
        {
          assertion = cfg.interfaces != {};
          message = "At least one interface must be configured with hostapd!";
        }
      ]
      # Interface warnings
      ++ (concatLists (mapAttrsToList (interface: ifcfg: let
          countWpaPasswordDefinitions = count (x: x != null) [ifcfg.authentication.wpaPassword ifcfg.authentication.wpaPasswordFile ifcfg.authentication.wpaPskFile];
        in [
          {
            assertion = ifcfg.authentication.mode == "wpa3-sae" -> ifcfg.managementFrameProtection == "required";
            message = ''hostapd interface ${interface} uses WPA3-SAE which requires managementFrameProtection="required"'';
          }
          {
            assertion = ifcfg.authentication.mode == "wpa3-sae-transition" -> ifcfg.managementFrameProtection != "disabled";
            message = ''hostapd interface ${interface} uses WPA3-SAE in transition mode with WPA2-SHA256, which requires managementFrameProtection="optional" or ="required"'';
          }
          {
            assertion = countWpaPasswordDefinitions <= 1;
            message = ''hostapd interface ${interface} must use at most one WPA password option (wpaPassword, wpaPasswordFile, wpaPskFile)'';
          }
          {
            assertion = ifcfg.authentication.wpaPassword != null -> (stringLength ifcfg.authentication.wpaPassword >= 8 && stringLength ifcfg.authentication.wpaPassword <= 63);
            message = ''hostapd interface ${interface} uses a wpaPassword of invalid length (must be in [8,63]).'';
          }
          {
            assertion = ifcfg.authentication.saePasswords == [] || ifcfg.authentication.saePasswordsFile == null;
            message = ''hostapd interface ${interface} must use only one SAE password option (saePasswords or saePasswordsFile)'';
          }
          {
            assertion = ifcfg.authentication.mode == "wpa3-sae" -> (ifcfg.authentication.saePasswords != [] || ifcfg.authentication.saePasswordsFile != null);
            message = ''hostapd interface ${interface} uses WPA3-SAE which requires defining a sae password option'';
          }
          {
            assertion = ifcfg.authentication.mode == "wpa3-sae-transition" -> (ifcfg.authentication.saePasswords != [] || ifcfg.authentication.saePasswordsFile != null) && countWpaPasswordDefinitions == 1;
            message = ''hostapd interface ${interface} uses WPA3-SAE in transition mode requires defining both a wpa password option and a sae password option'';
          }
          {
            assertion = ifcfg.authentication.mode == "wpa2-sha256" -> countWpaPasswordDefinitions == 1;
            message = ''hostapd interface ${interface} uses WPA2-SHA256 which requires defining a wpa password option'';
          }
        ])
        cfg.interfaces));

    environment.systemPackages = [pkgs.hostapd];

    services.udev.packages = optionals (any (i: i.countryCode != null) (attrValues cfg.interfaces)) [pkgs.crda];

    systemd.services.hostapd = {
      description = "Hostapd IEEE 802.11 AP Daemon";

      path = [pkgs.hostapd];
      after = mapAttrsToList (interface: _: "sys-subsystem-net-devices-${utils.escapeSystemdPath interface}.device") cfg.interfaces;
      bindsTo = mapAttrsToList (interface: _: "sys-subsystem-net-devices-${utils.escapeSystemdPath interface}.device") cfg.interfaces;
      requiredBy = mapAttrsToList (interface: _: "network-link-${interface}.service") cfg.interfaces;
      wantedBy = ["multi-user.target"];

      # Create merged configuration and acl files for each interface prior to starting
      preStart = concatStringsSep "\n" (mapAttrsToList makeInterfaceRuntimeFiles cfg.interfaces);

      serviceConfig = {
        ExecStart = "${pkgs.hostapd}/bin/hostapd ${concatStringsSep " " runtimeConfigFiles}";
        Restart = "always";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
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
