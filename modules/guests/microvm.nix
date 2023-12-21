guestName: guestCfg: {
  config,
  inputs,
  lib,
  pkgs,
  minimal,
  ...
}: let
  inherit
    (lib)
    flip
    mapAttrsToList
    mkDefault
    mkForce
    ;
in {
  specialArgs = {
    inherit (inputs.self) nodes;
    inherit (inputs.self.pkgs.${guestCfg.microvm.system}) lib;
    inherit inputs minimal;
  };
  pkgs = inputs.self.pkgs.${guestCfg.microvm.system};
  inherit (guestCfg) autostart;
  config = {
    imports = guestCfg.modules ++ [(import ./common-guest-config.nix guestName guestCfg)];

    # TODO needed because of https://github.com/NixOS/nixpkgs/issues/102137
    environment.noXlibs = mkForce false;
    lib.microvm.mac = guestCfg.microvm.mac;

    microvm = {
      hypervisor = mkDefault "qemu";

      # Give them some juice by default
      mem = mkDefault (2 * 1024);

      # MACVTAP bridge to the host's network
      interfaces = [
        {
          type = "macvtap";
          id = "vm-${guestName}";
          inherit (guestCfg.microvm) mac;
          macvtap = {
            link = guestCfg.microvm.macvtap;
            mode = "bridge";
          };
        }
      ];

      shares =
        [
          # Share the nix-store of the host
          {
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            tag = "ro-store";
            proto = "virtiofs";
          }
        ]
        ++ flip mapAttrsToList guestCfg.zfs (
          _: zfsCfg: {
            source = zfsCfg.hostMountpoint;
            mountPoint = zfsCfg.guestMountpoint;
            tag = lib.replaceStrings ["/"] ["_"] zfsCfg.hostMountpoint;
            proto = "virtiofs";
          }
        );
    };

    # Add a writable store overlay, but since this is always ephemeral
    # disable any store optimization from nix.
    microvm.writableStoreOverlay = "/nix/.rw-store";

    networking.renameInterfacesByMac.${guestCfg.networking.mainLinkName} = guestCfg.microvm.mac;
    systemd.network.networks."10-${guestCfg.networking.mainLinkName}".matchConfig.MACAddress = guestCfg.microvm.mac;
  };
}
