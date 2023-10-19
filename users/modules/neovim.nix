{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatMapStrings
    flip
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    types
    ;

  cfg = config.programs.neovim-custom;

  initLuaContent = ''
    ${cfg.initEarly}

    -- Begin plugin configuration
    ${concatMapStrings (x: "${x.config}\n") (cfg.config.plugins or [])}
    -- End plugin configuration

    ${cfg.init}
  '';

  nvimConfig =
    pkgs.neovimUtils.makeNeovimConfig cfg.config
    // {
      wrapRc = false;
      wrapperArgs = ["--add-flags" "-u ${pkgs.writeText "init.lua" initLuaContent}"];
    };

  finalPackage =
    flip pkgs.wrapNeovimUnstable nvimConfig
    (cfg.package.overrideAttrs (_final: prev: {
      nativeBuildInputs = (prev.nativeBuildInputs or []) ++ [pkgs.makeWrapper];
      postInstall =
        (prev.postInstall or "")
        + ''
          wrapProgram $out/bin/nvim --add-flags "--clean"
        '';
    }));
in {
  options.programs.neovim-custom = {
    enable = mkEnableOption "Neovim";
    package = mkPackageOption pkgs "neovim-unwrapped" {};
    config = mkOption {
      description = "The neovim configuration to use (passed to makeNeovimConfig and then to wrapNeovimUnstable)";
      default = {};
      type = types.anything;
    };
    initEarly = mkOption {
      description = "The early init.lua content that will be added before plugin configs.";
      default = "";
      type = types.lines;
    };
    init = mkOption {
      description = "The init.lua content, added after plugin configs.";
      default = "";
      type = types.lines;
    };
  };

  config = mkIf cfg.enable {
    home = {
      # XXX: TODO packages = [finalPackage];
      shellAliases.E = "${finalPackage}/bin/nvim";
      sessionVariables.EDITOR = "nvim";
      shellAliases.vimdiff = "nvim -d";
    };
  };
}
