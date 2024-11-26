{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.graphical.gaming.enable {
    programs.steam = {
      enable = true;
      package = pkgs.steam.override {
        extraPkgs =
          pkgs: with pkgs; [
            # add packages here in case any game needs them...
          ];
      };
    };

    programs.gamemode.enable = true;
  };
}
