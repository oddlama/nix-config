{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
# All hope abandon ye who enter here. hostapd's configuration
# format is ... special, and you won't be able to infer any
# of their assumptions from just reading the "documentation"
# (i.e. the example config). Also, do NOT try to make this RFC 42
# compatible. The format is non-standard, some options may repeat,
# are order-dependent, or completely switch into another global context.
# Assume footguns at all points - to make informed decisions you
# will probably need to look at hostapd's code. You have been warned,
# proceed with care.
let
  inherit
    (lib)
    attrNames
    attrValues
    concatLists
    concatMap
    concatMapStrings
    concatStringsSep
    count
    escapeShellArg
    filter
    getAttr
    imap0
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
    unique
    ;

  cfg = config.services.hostapd;

  bool01 = b:
    if b
    then "1"
    else "0";

  genSaePasswordEntry = entry:
    "sae_password=${entry.password}"
    + optionalString (entry.mac != null) "|mac=${entry.mac}"
    + optionalString (entry.vlanid != null) "|vlanid=${toString entry.vlanid}"
    + optionalString (entry.pk != null) "|pk=${entry.pk}"
    + optionalString (entry.id != null) "|id=${entry.id}"
    + "\n";

  # Generates the configuration for a single BSS (i.e. WiFi network)
  writeBssConfig = radio: radioCfg: bss: bssCfg: bssIdx: let
    pairwiseCiphers =
      concatStringsSep " " (unique (bssCfg.authentication.pairwiseCiphers
          ++ optionals bssCfg.authentication.enableRecommendedPairwiseCiphers ["CCMP" "CCMP-256" "GCMP" "GCMP-256"]));
  in
    pkgs.writeText "hostapd-radio-${radio}-bss-${bss}.conf" ''
      ##### BSS ${toString bssIdx}: ${bss} #######################################

      ${
        if bssIdx == 0
        then "interface"
        else "bss"
      }=${bss}
      ssid=${bssCfg.ssid}
      utf8_ssid=${bool01 bssCfg.utf8Ssid}

      logger_syslog=-1
      logger_syslog_level=${toString bssCfg.logLevel}
      logger_stdout=-1
      logger_stdout_level=${toString bssCfg.logLevel}
      ctrl_interface=/run/hostapd
      ctrl_interface_group=${bssCfg.group}

      # Set the MAC-address access control mode
      macaddr_acl=${bssCfg.macAcl}
      ${optionalString (bssCfg.macAllow != [] || bssCfg.macAllowFile != null || bssCfg.authentication.saeAddToMacAllow) ''
        accept_mac_file=/run/hostapd/${bss}.mac.allow
      ''}
      ${optionalString (bssCfg.macDeny != [] || bssCfg.macDenyFile != null) ''
        deny_mac_file=/run/hostapd/${bss}.mac.deny
      ''}
      # Only allow WPA, disable insecure WEP
      auth_algs=1
      ignore_broadcast_ssid=${bssCfg.ignoreBroadcastSsid}
      # Always enable QoS, which is required for 802.11n and above
      wmm_enabled=1
      ap_isolate=${bool01 bssCfg.apIsolate}

      ##### IEEE 802.11i (authentication) related configuration
      # Encrypt management frames to protect against deauthentication and similar attacks
      ieee80211w=${bssCfg.managementFrameProtection}
      ${optionalString (bssCfg.authentication.mode == "none") ''
        wpa=0
      ''}
      ${optionalString (bssCfg.authentication.mode == "wpa3-sae") ''
        wpa=2
        wpa_key_mgmt=SAE
        # Derive PWE using both hunting-and-pecking loop and hash-to-element
        sae_pwe=2
        # Prevent downgrade attacks by indicating to clients that they should
        # disable any transition modes from now on.
        transition_disable=0x01
      ''}
      ${optionalString (bssCfg.authentication.mode == "wpa3-sae-transition") ''
        wpa=2
        wpa_key_mgmt=WPA-PSK-SHA256 SAE
      ''}
      ${optionalString (bssCfg.authentication.mode == "wpa2-sha256") ''
        wpa=2
        wpa_key_mgmt=WPA-PSK-SHA256
      ''}
      ${optionalString (bssCfg.authentication.mode != "none") ''
        wpa_pairwise=${pairwiseCiphers}
        rsn_pairwise=${pairwiseCiphers}
      ''}

      ${optionalString (bssCfg.authentication.wpaPassword != null) ''
        wpa_passphrase=${bssCfg.authentication.wpaPassword}
      ''}
      ${optionalString (bssCfg.authentication.wpaPskFile != null) ''
        wpa_passphrase=${bssCfg.authentication.wpaPskFile}
      ''}
      ${optionalString (bssCfg.authentication.saePasswords != []) (concatMapStrings genSaePasswordEntry bssCfg.authentication.saePasswords)}
    '';

  writeRadioBaseConfig = radio: radioCfg:
    pkgs.writeText "hostapd-radio-${radio}-base.conf" ''
      driver=${radioCfg.driver}

      ##### IEEE 802.11 general configuration #######################################
      ${optionalString (radioCfg.countryCode != null) ''
        country_code=${radioCfg.countryCode}
        # IEEE 802.11d: Limit to frequencies allowed in country
        ieee80211d=1
        # IEEE 802.11h: Enable radar detection and DFS (Dynamic Frequency Selection)
        ieee80211h=1
      ''}
      hw_mode=${radioCfg.hwMode}
      channel=${toString radioCfg.channel}
      noscan=${bool01 radioCfg.noScan}

      ${optionalString radioCfg.wifi4.enable ''
        ##### IEEE 802.11n (WiFi 4) related configuration #######################################
        ieee80211n=1
        ${optionalString radioCfg.wifi4.require "require_ht=1"}
        ht_capab=${concatMapStrings (x: "[${x}]") radioCfg.wifi4.capabilities}
      ''}

      ${optionalString radioCfg.wifi5.enable ''
        ##### IEEE 802.11ac (WiFi 5) related configuration #####################################
        ieee80211ac=1
        ${optionalString radioCfg.wifi5.require "require_vht=1"}
        vht_oper_chwidth=${radioCfg.wifi5.operatingChannelWidth}
        vht_capab=${concatMapStrings (x: "[${x}]") radioCfg.wifi5.capabilities}
      ''}

      ${ # ieee80211ax support must be enabled in hostapd,
        # so the enable option cannot be included unconditionally
        optionalString radioCfg.wifi6.enable ''
          ##### IEEE 802.11ax (WiFi 6) related configuration #####################################
          ieee80211ax=1
          ${optionalString radioCfg.wifi6.require "require_he=1"}
          he_oper_chwidth=${radioCfg.wifi6.operatingChannelWidth}
          he_su_beamformer=${bool01 radioCfg.wifi6.singleUserBeamformer}
          he_su_beamformee=${bool01 radioCfg.wifi6.singleUserBeamformee}
          he_mu_beamformer=${bool01 radioCfg.wifi6.multiUserBeamformer}
        ''
      }

      ${ # ieee80211be support must be enabled in hostapd,
        # so the enable option cannot be included unconditionally
        optionalString radioCfg.wifi7.enable ''
          ##### IEEE 802.11be (WiFi 7) related configuration #####################################
          ieee80211be=1
          eht_oper_chwidth=${radioCfg.wifi7.operatingChannelWidth}
          eht_su_beamformer=${bool01 radioCfg.wifi7.singleUserBeamformer}
          eht_su_beamformee=${bool01 radioCfg.wifi7.singleUserBeamformee}
          eht_mu_beamformer=${bool01 radioCfg.wifi7.multiUserBeamformer}
        ''
      }
    '';

  makeRadioRuntimeFiles = radio: radioCfg:
    pkgs.writeShellScript "make-hostapd-${radio}-files" (''
        set -euo pipefail

        hostapd_config_file=/run/hostapd/${escapeShellArg radio}.hostapd.conf
        rm -f "$hostapd_config_file"
        cp ${writeRadioBaseConfig radio radioCfg} "$hostapd_config_file"

        ${optionalString (radioCfg.extraConfig != "") ''
          cat >> "$hostapd_config_file" <<EOF

          ##### User-provided extra radio configuration ##########################################
          EOF
          cat ${escapeShellArg (pkgs.writeText "hostapd-radio-${radio}-extra.conf" radioCfg.extraConfig)} >> "$hostapd_config_file"
        ''}
      ''
      + concatStringsSep "\n" (imap0 (i: f: f i) (mapAttrsToList (
          bss: bssCfg: bssIdx: let
            # All MAC addresses from SAE entries that aren't the wildcard address
            saeMacs = filter (mac: mac != null && (toLower mac) != "ff:ff:ff:ff:ff:ff") (map (x: x.mac) bssCfg.authentication.saePasswords);
          in
            ''
              #### BSS configuration: ${bss}

              mac_allow_file=/run/hostapd/${escapeShellArg bss}.mac.allow
              rm -f "$mac_allow_file"
              touch "$mac_allow_file"

              mac_deny_file=/run/hostapd/${escapeShellArg bss}.mac.deny
              rm -f "$mac_deny_file"
              touch "$mac_deny_file"

              cat ${writeBssConfig radio radioCfg bss bssCfg bssIdx} >> "$hostapd_config_file"

            ''
            + concatStringsSep "\n" (
              optional (bssCfg.macAllow != []) ''
                cat >> "$mac_allow_file" <<EOF
                ${concatStringsSep "\n" bssCfg.macAllow}
                EOF
              ''
              ++ optional (bssCfg.macAllowFile != null) ''
                grep -Eo '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})' ${escapeShellArg bssCfg.macAllowFile} >> "$mac_allow_file"
              ''
              # Populate mac allow list from saePasswords
              ++ optional (bssCfg.authentication.saeAddToMacAllow && saeMacs != []) ''
                cat >> "$mac_allow_file" <<EOF
                ${concatStringsSep "\n" saeMacs}
                EOF
              ''
              # Populate mac allow list from saePasswordsFile
              # (filter for lines with mac=;  exclude commented lines; filter for real mac-addresses; strip mac=)
              ++ optional (bssCfg.authentication.saeAddToMacAllow && bssCfg.authentication.saePasswordsFile != null) ''
                grep mac= ${escapeShellArg bssCfg.authentication.saePasswordsFile} \
                  | grep -v '\s*#' \
                  | grep -Eo 'mac=([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})' \
                  | sed 's|^mac=||' >> "$mac_allow_file"
              ''
              # Create combined mac.deny list from macDeny and macDenyFile
              ++ optional (bssCfg.macDeny != []) ''
                cat >> "$mac_deny_file" <<EOF
                ${concatStringsSep "\n" bssCfg.macDeny}
                EOF
              ''
              ++ optional (bssCfg.macDenyFile != null) ''
                grep -Eo '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})' ${escapeShellArg bssCfg.macDenyFile} >> "$mac_deny_file"
              ''
              # Add WPA passphrase from file if necessary
              ++ optional (bssCfg.authentication.wpaPasswordFile != null) ''
                cat >> "$hostapd_config_file" <<EOF
                wpa_passphrase=$(cat ${escapeShellArg bssCfg.authentication.wpaPasswordFile})
                EOF
              ''
              # Add SAE passwords from file if necessary
              ++ optional (bssCfg.authentication.saePasswordsFile != null) ''
                grep -v '\s*#' ${escapeShellArg bssCfg.authentication.saePasswordsFile} \
                  | sed 's/^/sae_password=/' >> "$hostapd_config_file"
              ''
              # Finally append extraConfig if necessary.
              ++ optional (bssCfg.extraConfig != "") ''
                cat >> "$hostapd_config_file" <<EOF

                ##### User-provided extra BSS configuration ##########################################
                EOF
                cat ${escapeShellArg (pkgs.writeText "hostapd-radio-${radio}-bss-${bss}-extra.conf" bssCfg.extraConfig)} >> "$hostapd_config_file"
              ''
            )
        )
        radioCfg.networks)));

  runtimeConfigFiles = mapAttrsToList (radio: _: "/run/hostapd/${radio}.hostapd.conf") cfg.radios;
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

      radios = mkOption {
        default = {};
        example = literalExpression ''
          {
            # Simple 2.4GHz AP
            wlp2s0 = {
              # countryCode = "US";
              networks.wlp2s0 = {
                ssid = "AP 1";
                authentication.saePasswords = [{ password = "a flakey password"; }]; # Use saePasswordsFile if possible.
              };
            };

            # WiFi 5 (5GHz) with two advertised networks
            wlp3s0 = {
              hwMode = "a";
              channel = 0; # Enable automatic channel selection (ACS). Use only if your hardware supports it.
              # countryCode = "US";
              networks.wlp3s0 = {
                ssid = "My AP";
                authentication.saePasswords = [{ password = "a flakey password"; }]; # Use saePasswordsFile if possible.
              };
              networks.wlp3s0-1 = {
                ssid = "Open AP with WiFi5";
                authentication.mode = "none";
              };
            };

            # Legacy WPA2 example
            wlp4s0 = {
              # countryCode = "US";
              networks.wlp4s0 = {
                ssid = "AP 2";
                authentication = {
                  mode = "wpa2-sha256";
                  wpaPassword = "a flakey password"; # Use wpaPasswordFile if possible.
                };
              };
            };
          }
        '';
        description = mdDoc ''
          This option allows you to define APs for one or multiple physical radios.
          At least one radio must be specified.

          For each radio, hostapd requires a separate logical interface (like wlp3s0, wlp3s1, ...).
          A default interface is usually be created automatically by your system, but to use
          multiple radios with a single device, you will likely have to use {command}`iw` to create
          additional logical interfaces.

          Each physical radio can only support a single hardware-mode that is configured via
          ({option}`services.hostapd.radios.<radio>.hwMode`). To create a dual-band
          or tri-band AP, you will have to use a device that has multiple physical radios
          and supports configuring multiple APs (Refer to valid interface combinations in
          {command}`iw list`).
        '';
        type = types.attrsOf (types.submodule {
          options = {
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

            noScan = mkOption {
              type = types.bool;
              default = false;
              description = mdDoc ''
                Disables scan for overlapping BSSs in HT40+/- mode.
                Caution: turning this on will likely violate regulatory requirements!
              '';
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
                to be set to hw_mode=a. When using ACS (see `channel` parameter), the
                special value "any" can be used to indicate that any supported band may be selected.
                This special case is currently only supported with hardware for which the driver
                implements offloaded ACS.

                Most likely you want to select 'a' (5GHz & 6GHz a/n/ac/ax) or 'g' (2.4GHz b/g/n) here.
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

            extraConfig = mkOption {
              default = "";
              example = ''
                acs_exclude_dfs=1
              '';
              type = types.lines;
              description = mdDoc ''
                Extra configuration options to put at the end of global initialization, before defining BSSes.
                To find out which options are global and which are per-bss you have to read hostapd's source code,
                this is non-trivial and not documented otherwise.
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
                apply = x:
                  getAttr x {
                    "20or40" = "0";
                    "80" = "1";
                    "160" = "2";
                    "80+80" = "3";
                  };
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
                apply = x:
                  getAttr x {
                    "20or40" = "0";
                    "80" = "1";
                    "160" = "2";
                    "80+80" = "3";
                  };
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
                apply = x:
                  getAttr x {
                    "20or40" = "0";
                    "80" = "1";
                    "160" = "2";
                    "80+80" = "3";
                  };
                description = mdDoc ''
                  Determines the operating channel width for EHT.

                  - {var}`"20or40"`: 20 or 40 MHz operating channel width
                  - {var}`"80"`: 80 MHz channel width
                  - {var}`"160"`: 160 MHz channel width
                  - {var}`"80+80"`: 80+80 MHz channel width
                '';
              };
            };

            #### BSS definitions

            networks = mkOption {
              default = {};
              example = literalExpression ''
                {
                  wlp2s0 = {
                    ssid = "Primary advertised network";
                    authentication.saePasswords = [{ password = "a flakey password"; }]; # Use saePasswordsFile if possible.
                  };
                  wlp2s0-1 = {
                    ssid = "Secondary advertised network (Open)";
                    authentication.mode = "none";
                  };
                }
              '';
              description = mdDoc ''
                This defines a BSS, colloquially known as a WiFi network.
                You have to specify at least one.
              '';
              type = types.attrsOf (types.submodule {
                options = {
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

                  macAcl = mkOption {
                    default = "allow";
                    type = types.enum ["allow" "deny" "radius"];
                    apply = x:
                      getAttr x {
                        "allow" = "0";
                        "deny" = "1";
                        "radius" = "2";
                      };
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
                    apply = x:
                      getAttr x {
                        "disabled" = "0";
                        "empty" = "1";
                        "clear" = "2";
                      };
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
                      default = ["CCMP"];
                      example = ["CCMP-256" "GCMP-256"];
                      type = types.listOf types.str;
                      description = mdDoc ''
                        Set of accepted cipher suites (encryption algorithms) for pairwise keys (unicast packets).
                        By default this allows just CCMP, which is the only commonly supported secure option.
                        Use {option}`enableRecommendedPairwiseCiphers` to also enable newer recommended ciphers.

                        Please refer to the hostapd documentation for allowed values. Generally, only
                        CCMP or GCMP modes should be considered safe options. Most devices support CCMP while
                        GCMP is often only available with devices supporting WiFi 5 (IEEE 802.11ac) or higher.
                      '';
                    };

                    enableRecommendedPairwiseCiphers = mkOption {
                      default = false;
                      example = true;
                      type = types.bool;
                      description = mdDoc ''
                        Additionally enable the recommended set of pairwise ciphers.
                        This enables newer secure ciphers, additionally to those defined in {option}`pairwiseCiphers`.
                        You will have to test whether your hardware supports these by trial-and-error, because
                        even if `iw list` indicates hardware support, your driver might not expose it.

                        Beware {command}`hostapd` will most likely not return a useful error message in case
                        this is enabled despite the driver or hardware not supporting the newer ciphers.
                        Look out for messages like `Failed to set beacon parameters`.
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
                    apply = x:
                      getAttr x {
                        "disabled" = "0";
                        "optional" = "1";
                        "required" = "2";
                      };
                    description = mdDoc ''
                      Management frame protection (MFP) authenticates management frames
                      to prevent deauthentication (or related) attacks.

                      - {var}`"disabled"`: No management frame protection
                      - {var}`"optional"`: Use MFP if a connection allows it
                      - {var}`"required"`: Force MFP for all clients
                    '';
                  };
                };
              });
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
          assertion = cfg.radios != {};
          message = "At least one radio must be configured with hostapd!";
        }
      ]
      # TODO check that multiple BSS -> bssid is defined or hardware bssids are used.
      # TODO check that network name for each bss is prefixed with radio name
      # TODO check that no bss name appears twice, even globally.
      # TODO check that first bss has same name as radio.
      # Radio warnings
      ++ (concatLists (mapAttrsToList (
          radio: radioCfg:
            [
              {
                assertion = radioCfg.networks != {};
                message = "hostapd radio ${radio}: At least one network must be configured!";
              }
              {
                assertion = radioCfg.hwMode == "a" -> radioCfg.wifi5.enable;
                message = ''hostapd radio ${radio}: Must set at least wifi5.enable=true in order to use hwMode="a"'';
              }
            ]
            # BSS warnings
            ++ (concatLists (mapAttrsToList (bss: bssCfg: let
                auth = bssCfg.authentication;
                countWpaPasswordDefinitions = count (x: x != null) [
                  auth.wpaPassword
                  auth.wpaPasswordFile
                  auth.wpaPskFile
                ];
              in [
                {
                  assertion = auth.mode == "wpa3-sae" -> bssCfg.managementFrameProtection == "2";
                  message = ''hostapd radio ${radio} bss ${bss}: uses WPA3-SAE which requires managementFrameProtection="required"'';
                }
                {
                  assertion = auth.mode == "wpa3-sae-transition" -> bssCfg.managementFrameProtection != "0";
                  message = ''hostapd radio ${radio} bss ${bss}: uses WPA3-SAE in transition mode with WPA2-SHA256, which requires managementFrameProtection="optional" or ="required"'';
                }
                {
                  assertion = countWpaPasswordDefinitions <= 1;
                  message = ''hostapd radio ${radio} bss ${bss}: must use at most one WPA password option (wpaPassword, wpaPasswordFile, wpaPskFile)'';
                }
                {
                  assertion = auth.wpaPassword != null -> (stringLength auth.wpaPassword >= 8 && stringLength auth.wpaPassword <= 63);
                  message = ''hostapd radio ${radio} bss ${bss}: uses a wpaPassword of invalid length (must be in [8,63]).'';
                }
                {
                  assertion = auth.saePasswords == [] || auth.saePasswordsFile == null;
                  message = ''hostapd radio ${radio} bss ${bss}: must use only one SAE password option (saePasswords or saePasswordsFile)'';
                }
                {
                  assertion = auth.mode == "wpa3-sae" -> (auth.saePasswords != [] || auth.saePasswordsFile != null);
                  message = ''hostapd radio ${radio} bss ${bss}: uses WPA3-SAE which requires defining a sae password option'';
                }
                {
                  assertion = auth.mode == "wpa3-sae-transition" -> (auth.saePasswords != [] || auth.saePasswordsFile != null) && countWpaPasswordDefinitions == 1;
                  message = ''hostapd radio ${radio} bss ${bss}: uses WPA3-SAE in transition mode requires defining both a wpa password option and a sae password option'';
                }
                {
                  assertion = auth.mode == "wpa2-sha256" -> countWpaPasswordDefinitions == 1;
                  message = ''hostapd radio ${radio} bss ${bss}: uses WPA2-SHA256 which requires defining a wpa password option'';
                }
              ])
              radioCfg.networks))
        )
        cfg.radios));

    environment.systemPackages = [pkgs.hostapd];

    services.udev.packages = with pkgs; [crda];

    systemd.services.hostapd = {
      description = "IEEE 802.11 Host Access-Point Daemon";

      path = [pkgs.hostapd];
      after = map (radio: "sys-subsystem-net-devices-${utils.escapeSystemdPath radio}.device") (attrNames cfg.radios);
      bindsTo = map (radio: "sys-subsystem-net-devices-${utils.escapeSystemdPath radio}.device") (attrNames cfg.radios);
      wantedBy = ["multi-user.target"];

      # Create merged configuration and acl files for each radio (and their bsses) prior to starting
      preStart = concatStringsSep "\n" (mapAttrsToList makeRadioRuntimeFiles cfg.radios);

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
        PrivateUsers = false; # hostapd requires true root access.
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
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "@chown"
        ];
        UMask = "0077";
      };
    };
  };
}
