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
    attrNames
    mkDefault
    mkForce
    net
    optional
    ;

  mac = (net.mac.assignMacs "02:01:27:00:00:00" 24 [] (attrNames config.guests)).${guestName};
in {
  specialArgs = {
    inherit (inputs.self) nodes;
    inherit (inputs.self.pkgs.${guestCfg.microvm.system}) lib;
    inherit inputs;
    inherit minimal;
  };
  pkgs = inputs.self.pkgs.${guestCfg.microvm.system};
  inherit (guestCfg) autostart;
  config = {
    imports = guestCfg.modules ++ [(import ./common-guest-config.nix guestName guestCfg)];

    # TODO needed because of https://github.com/NixOS/nixpkgs/issues/102137
    environment.noXlibs = mkForce false;
    lib.microvm.mac = mac;

    microvm = {
      hypervisor = mkDefault "qemu";

      # Give them some juice by default
      mem = mkDefault (2 * 1024);

      # MACVTAP bridge to the host's network
      interfaces = [
        {
          type = "macvtap";
          id = "vm-${guestName}";
          inherit mac;
          macvtap = {
            link = guestCfg.microvm.macvtapInterface;
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
          {
            source = "/state/guests/${guestName}";
            mountPoint = "/state";
            tag = "state";
            proto = "virtiofs";
          }
        ]
        # Mount persistent data from the host
        ++ optional guestCfg.zfs.enable {
          source = guestCfg.zfs.mountpoint;
          mountPoint = "/persist";
          tag = "persist";
          proto = "virtiofs";
        };
    };

    # FIXME this should be changed in microvm.nix to mkDefault in order to not require mkForce here
    fileSystems."/state".neededForBoot = mkForce true;
    fileSystems."/persist".neededForBoot = mkForce true;

    # Add a writable store overlay, but since this is always ephemeral
    # disable any store optimization from nix.
    microvm.writableStoreOverlay = "/nix/.rw-store";
    nix = {
      settings.auto-optimise-store = mkForce false;
      optimise.automatic = mkForce false;
      gc.automatic = mkForce false;
    };

    networking.renameInterfacesByMac.${guestCfg.networking.mainLinkName} = mac;

    systemd.network.networks = {
      "10-${guestCfg.networking.mainLinkName}" = {
        matchConfig.MACAddress = mac;
      };
    };
  };
}
