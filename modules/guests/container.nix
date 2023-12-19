guestName: guestCfg: {
  config,
  inputs,
  lib,
  minimal,
  nodes,
  pkgs,
  ...
}: let
  inherit
    (lib)
    flip
    mapAttrs'
    nameValuePair
    substring
    ;

  initialLinkName = "mv-${(substring 0 12 (builtins.hashString "sha256" guestName))}";
in {
  ephemeral = true;
  privateNetwork = true;
  autoStart = guestCfg.autostart;
  macvlans = ["${guestCfg.container.macvlan}:${initialLinkName}"];
  extraFlags = [
    "--uuid=${builtins.substring 0 32 (builtins.hashString "sha256" guestName)}"
  ];
  bindMounts = flip mapAttrs' guestCfg.zfs (
    _: zfsCfg:
      nameValuePair zfsCfg.guestMountpoint {
        hostPath = zfsCfg.hostMountpoint;
        isReadOnly = false;
      }
  );
  nixosConfiguration = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit lib nodes inputs minimal;
    };
    prefix = ["nodes" "${config.node.name}-${guestName}" "config"];
    system = null;
    modules =
      [
        {
          boot.isContainer = true;
          networking.useHostResolvConf = false;

          # We cannot force the package set via nixpkgs.pkgs and
          # inputs.nixpkgs.nixosModules.readOnlyPkgs, since some nixosModules
          # like nixseparatedebuginfod depend on adding packages via nixpkgs.overlays.
          # So we just mimic the options and overlays defined by the passed pkgs set.
          nixpkgs.hostPlatform = config.nixpkgs.hostPlatform.system;
          nixpkgs.overlays = pkgs.overlays;
          nixpkgs.config = pkgs.config;

          # Bind the /guest/* paths from above so impermancence doesn't complain.
          # We bind-mount stuff from the host to itself, which is perfectly defined
          # and not recursive. This allows us to have a fileSystems entry for each
          # bindMount which other stuff can depend upon (impermanence adds dependencies
          # to the state fs).
          fileSystems = flip mapAttrs' guestCfg.zfs (_: zfsCfg:
            nameValuePair zfsCfg.guestMountpoint {
              neededForBoot = true;
              fsType = "none";
              device = zfsCfg.guestMountpoint;
              options = ["bind"];
            });

          # Rename the network interface to our liking
          systemd.network.links = {
            "01-${guestCfg.networking.mainLinkName}" = {
              matchConfig.Name = initialLinkName;
              linkConfig.Name = guestCfg.networking.mainLinkName;
            };
          };
        }
        (import ./common-guest-config.nix guestName guestCfg)
      ]
      ++ guestCfg.modules;
  };
}
