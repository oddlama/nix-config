# Provides an option to easily rename interfaces by their mac addresses.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    attrValues
    concatStringsSep
    duplicates
    mapAttrsToList
    mkIf
    mkOption
    types
    ;

  cfg = config.networking.renameInterfacesByMac;

  interfaceNamesUdevRules = pkgs.writeTextFile {
    name = "interface-names-udev-rules";
    text = concatStringsSep "\n" (mapAttrsToList
      (name: mac: ''SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="${mac}", NAME:="${name}"'')
      cfg);
    destination = "/etc/udev/rules.d/01-interface-names.rules";
  };
in {
  options.networking.renameInterfacesByMac = mkOption {
    default = {};
    example = {lan = "11:22:33:44:55:66";};
    description = "Allows naming of network interfaces based on their physical address";
    type = types.attrsOf types.str;
  };

  config = lib.mkIf (cfg != {}) {
    assertions = let
      duplicateMacs = duplicates (attrValues cfg);
    in [
      {
        assertion = duplicateMacs == [];
        message = "Duplicate mac addresses found in network interface name assignment: ${concatStringsSep ", " duplicateMacs}";
      }
    ];

    services.udev.packages = [interfaceNamesUdevRules];
    boot.initrd.services.udev.packages = [interfaceNamesUdevRules];
  };
}
