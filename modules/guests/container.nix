guestName: guestCfg: {
  config,
  inputs,
  lib,
  minimal,
  nodes,
  pkgs,
  ...
}: {
  autoStart = guestCfg.autostart;
  macvlans = ["${guestCfg.container.macvlan}:${guestCfg.networking.mainLinkName}"];
  ephemeral = true;
  privateNetwork = true;
  # We bind-mount stuff from the host into /guest first, and later bind
  # mount them into the correct path inside the guest, so we have a
  # fileSystems entry that impermanence can depend upon.
  bindMounts = {
    "/guest/state" = {
      hostPath = "/state/guests/${guestName}";
      isReadOnly = false;
    };
    # Mount persistent data from the host
    "/guest/persist" = lib.mkIf guestCfg.zfs.enable {
      hostPath = guestCfg.zfs.mountpoint;
      isReadOnly = false;
    };
  };
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
          fileSystems."/state" = {
            fsType = "none";
            neededForBoot = true;
            device = "/guest/state";
            options = ["bind"];
          };
          fileSystems."/persist" = lib.mkIf guestCfg.zfs.enable {
            fsType = "none";
            neededForBoot = true;
            device = "/guest/persist";
            options = ["bind"];
          };
        }
        (import ./common-guest-config.nix guestName guestCfg)
      ]
      ++ guestCfg.modules;
  };
}
