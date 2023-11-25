{
  programs.nixvim.plugins.alpha = {
    enable = true;
    layout = let
      padding = val: {
        type = "padding";
        inherit val;
      };
    in [
      (padding 2)
      {
        opts = {
          hl = "Type";
          position = "center";
        };
        type = "text";
        val = [
          "  ███╗   ██╗██╗██╗  ██╗██╗   ██╗██╗███╗   ███╗  "
          "  ████╗  ██║██║╚██╗██╔╝██║   ██║██║████╗ ████║  "
          "  ██╔██╗ ██║██║ ╚███╔╝ ██║   ██║██║██╔████╔██║  "
          "  ██║╚██╗██║██║ ██╔██╗ ╚██╗ ██╔╝██║██║╚██╔╝██║  "
          "  ██║ ╚████║██║██╔╝ ██╗ ╚████╔╝ ██║██║ ╚═╝ ██║  "
          "  ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝  "
        ];
      }
      (padding 2)
      {
        type = "group";
        opts.spacing = 1;
        val = [
          {
            command = ":enew<CR>";
            desc = "  New file";
            shortcut = "e";
          }
          {
            command = ":qa<CR>";
            desc = "󰅙  Quit Neovim";
            shortcut = "q";
          }
        ];
      }
    ];
  };
}
