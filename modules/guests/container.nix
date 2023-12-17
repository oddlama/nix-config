guestName: guestCfg: {
  config,
  lib,
  ...
} @ attrs: let
  inherit (lib) mkMerge;
in {
  autoStart = guestCfg.autostart;
  specialArgs =
    attrs
    // {
      parentNode = config;
    };
  macvlans = [guestCfg.container.macvlan];
  ephemeral = true;
  privateNetwork = true;
  config = mkMerge (guestCfg.modules
    ++ [
      (import ./common-guest-config.nix guestName guestCfg)
      {
        systemd.network.networks = {
          "10-${guestCfg.networking.mainLinkName}" = {
            matchConfig.OriginalName = "mv-${guestCfg.container.macvlan}";
            linkConfig.Name = guestCfg.networking.mainLinkName;
          };
        };
      }
    ]);
}
