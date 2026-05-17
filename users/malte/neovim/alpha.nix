{
  programs.nixvim.plugins.alpha = {
    enable = true;
    settings.layout =
      let
        padding = val: {
          type = "padding";
          inherit val;
        };
      in
      [
        (padding 2)
        {
          opts = {
            hl = "Type";
            position = "center";
          };
          type = "text";
          val = [
            "    ██████  ▄▄▄       ███▄ ▄███▓ ██▓ ██▓    ▓█████▄ ▓█████   "
            "  ▒██    ▒ ▒████▄    ▓██▒▀█▀ ██▒▓██▒▓██▒    ▒██▀ ██▌▓█   ▀   "
            "  ░ ▓██▄   ▒██  ▀█▄  ▓██    ▓██░▒██▒▒██░    ░██   █▌▒███     "
            "    ▒   ██▒░██▄▄▄▄██ ▒██    ▒██ ░██░▒██░    ░▓█▄   ▌▒▓█  ▄   "
            "  ▒██████▒▒ ▓█   ▓██▒▒██▒   ░██▒░██░░██████▒░▒████▓ ░▒████▒  "
            "  ▒ ▒▓▒ ▒ ░ ▒▒   ▓▒█░░ ▒░   ░  ░░▓  ░ ▒░▓  ░ ▒▒▓  ▒ ░░ ▒░ ░  "
            "  ░ ░▒  ░ ░  ▒   ▒▒ ░░  ░      ░ ▒ ░░ ░ ▒  ░ ░ ▒  ▒  ░ ░  ░  "
            "  ░  ░  ░    ░   ▒   ░      ░    ▒ ░  ░ ░    ░ ░  ░    ░     "
            "        ░        ░  ░       ░    ░      ░  ░   ░       ░  ░  "
          ];
        }
        (padding 2)
        {
          type = "group";
          opts.spacing = 1;
          val = [
            {
              type = "button";
              val = "  New file";
              on_press.__raw =
                # lua
                "function() vim.cmd[[enew]] end";
              opts = {
                shortcut = "e";
                position = "center";
                hl_shortcut = "keyword";
                align_shortcut = "right";
                width = 50;
                cursor = 3;
                keymap = [
                  "n"
                  "e"
                  ":enew<CR>"
                  {
                    noremap = true;
                    silent = true;
                    nowait = true;
                  }
                ];
              };
            }
            {
              type = "button";
              val = "󰅙  Quit Neovim";
              on_press.__raw =
                # lua
                "function() vim.cmd[[qa]] end";
              opts = {
                shortcut = "q";
                position = "center";
                hl_shortcut = "keyword";
                align_shortcut = "right";
                width = 50;
                cursor = 3;
                keymap = [
                  "n"
                  "q"
                  ":qa<CR>"
                  {
                    noremap = true;
                    silent = true;
                    nowait = true;
                  }
                ];
              };
            }
          ];
        }
      ];
  };
}
