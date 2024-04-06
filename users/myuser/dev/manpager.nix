{
  lib,
  pkgs,
  ...
}: {
  home.sessionVariables.MANPAGER = let
    prg = lib.getExe (pkgs.nixvim.makeNixvim {
      package = pkgs.neovim-clean;

      opts = {
        buftype = "nowrite";
        backup = false;
        modeline = false;
        shelltemp = false;
        swapfile = false;
        undofile = false;
        writebackup = false;
        virtualedit = "all";
        splitkeep = "screen";
        termguicolors = false;
      };

      extraConfigLua = ''
        vim.opt.shadafile = vim.fn.stdpath "state" .. "/shada/man.shada";
      '';

      keymaps = [
        {
          action = "<C-]>";
          key = "<CR>";
          mode = ["n"];
          options = {
            silent = true;
            desc = "Jump to tag under cursor";
          };
        }
        {
          action = ":pop<CR>";
          key = "<BS>";
          mode = ["n"];
          options = {
            silent = true;
            desc = "Jump to previous tag in stack";
          };
        }
        {
          action = ":pop<CR>";
          key = "<C-Left>";
          mode = ["n"];
          options = {
            silent = true;
            desc = "Jump to previous tag in stack";
          };
        }
        {
          action = ":tag<CR>";
          key = "<C-Right>";
          mode = ["n"];
          options = {
            silent = true;
            desc = "Jump to next tag in stack";
          };
        }
      ];
    });
  in "${prg} '+Man!'";
}
