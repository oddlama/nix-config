{
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      # navarasu's one dark
      onedark-nvim
    ];

    extraConfigLua =
      lib.mkBefore
      # lua
      ''
        local onedark = require "onedark"
        onedark.setup {
          toggle_style_key = "<nop>",
          colors = {
            fg = "#abb2bf",
            black = "#181a1f",
            bg0 = "#1e222a",
            bg1 = "#252931",
            bg2 = "#282c34",
            bg3 = "#353b45",
            bg_d = "#191c21",
            bg_blue = "#73b8f1",
            bg_yellow = "#ebd09c",

            dark_cyan = "#2b6f77",
            dark_red = "#993939",
            dark_yellow = "#93691d",

            grey = "#42464e",
            grey_fg = "#565c64",
            grey_fg2 = "#6f737b",
            light_grey = "#6f737b",
            baby_pink = "#de8c92",
            pink = "#ff75a0",
            nord_blue = "#81a1c1",
            sun = "#ebcb8b",
            light_purple = "#de98fd",
            dark_purple = "#c882e7",
            teal = "#519aba",
            dark_pink = "#fca2aa",
            light_blue = "#a3b8ef",
            vibrant_green = "#7eca9c",

            red = "#e06c75",
            orange = "#d19a66",
            yellow = "#e5c07b",
            green = "#98c379",
            cyan = "#56b6c2",
            blue = "#61afef",
            purple = "#c678dd",

            diff_add = "#31392b",
            diff_delete = "#382b2c",
            diff_change = "#1c3448",
            diff_text = "#2c5372",
          },
          highlights = {
            CursorLine = { bg = "$bg0" },
            FloatBorder = { fg = "$blue" },
            NeoTreeTabActive = { fg = "$fg", bg = "$bg_d" },
            NeoTreeTabInactive = { fg = "$grey", bg = "$black" },
            NeoTreeTabSeparatorActive = { fg = "$black", bg = "$black" },
            NeoTreeTabSeparatorInactive = { fg = "$black", bg = "$black" },
            NeoTreeWinSeparator = { fg = "$bg_d", bg = "$bg_d" },
            NeoTreeVertSplit = { fg = "$bg_d", bg = "$bg_d" },
            VisualMultiMono = { fg = "$purple", bg = "$diff_change" },
            VisualMultiExtend = { bg = "$diff_change" },
            VisualMultiCursor = { fg = "$purple", bg = "$diff_change" },
            VisualMultiInsert = { fg = "$blue", bg = "$diff_change" },
          },
        }
        vim.g.VM_Mono_hl = "VisualMultiMono"
        vim.g.VM_Extend_hl = "VisualMultiExtend"
        vim.g.VM_Cursor_hl = "VisualMultiCursor"
        vim.g.VM_Insert_hl = "VisualMultiInsert"
        onedark.load()
      '';
  };
}
