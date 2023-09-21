{
  lib,
  config,
  pkgs,
  ...
}: {
  options.programs.neovim-custom = {
    enable = lib.mkEnableOption "Neovim";
    package = lib.mkPackageOption pkgs "neovim" {};
  };

  config = lib.mkIf config.programs.neovim-custom.enable {
    home = {
      # TODO packages = [config.programs.neovim-custom.package];
      sessionVariables.EDITOR = "nvim";
      shellAliases.vimdiff = "nvim -d";
    };
  };
}
