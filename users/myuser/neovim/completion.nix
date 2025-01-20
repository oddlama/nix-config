{
  programs.nixvim = {
    plugins = {
      blink-compat.enable = true;

      blink-cmp = {
        enable = true;
        settings = {
          keymap = {
            preset = "none";
            "<C-space>" = [
              "show"
              "show_documentation"
              "hide_documentation"
            ];
            "<C-e>" = [
              "cancel"
              "fallback"
            ];
            "<CR>" = [
              "accept"
              "fallback"
            ];

            "<A-Tab>" = [
              "snippet_forward"
              "fallback"
            ];
            "<A-S-Tab>" = [
              "snippet_backward"
              "fallback"
            ];
            "<Tab>" = [
              "select_next"
              "fallback"
            ];
            "<S-Tab>" = [
              "select_prev"
              "fallback"
            ];

            "<C-p>" = [
              "select_prev"
              "fallback"
            ];
            "<C-n>" = [
              "select_next"
              "fallback"
            ];

            "<S-Up>" = [
              "scroll_documentation_up"
              "fallback"
            ];
            "<S-Down>" = [
              "scroll_documentation_down"
              "fallback"
            ];
          };

          appearance = {
            use_nvim_cmp_as_default = true;
            nerd_font_variant = "mono";
          };

          sources = {
            default = [
              "lsp"
              "path"
              "snippets"
              "emoji"
              "buffer"
            ];
            providers = {
              emoji = {
                name = "emoji";
                module = "blink.compat.source";
              };
            };
          };

          signature.enabled = true;
          completion = {
            list.selection = {
              preselect = false;
              auto_insert = true;
            };
            documentation.auto_show = true;
          };
        };
      };

      cmp-emoji.enable = true;
      lsp.capabilities = # lua
        ''
          capabilities = require('blink.cmp').get_lsp_capabilities(capabilities)
        '';
    };
  };
}
