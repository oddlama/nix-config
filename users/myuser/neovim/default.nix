# TODO vim illuminate
# TODO keybinds
# TODO dap dapui
# TODO neotree focsed shows lualine wrongly (full instead of nothing)
# TODO lualine inactive ------ is ugly
# TODO move lines. gomove again?
# TODO vim-wordmotion vs https://github.com/chrisgrieser/nvim-various-textobjs
# TODO blankline cur indent too bright
{
  imports = [
    ./alpha.nix
    ./appearance.nix
    ./completion.nix
    ./git.nix
    ./globals.nix
    ./languages.nix
    ./lsp.nix
    ./misc.nix
    ./neo-tree.nix
    ./onedark.nix
    ./web-devicons.nix
  ];

  programs.nixvim = {
    enable = true;

    # TODO for wayland:
    # clipboard.providers.wl-copy.enable = true;

    #colorschemes.catppuccin = {
    #  enable = true;
    #  flavour = "mocha";
    #  integrations = {
    #    dap.enabled = true;
    #    dap.enable_ui = true;
    #    fidget = true;
    #    indent_blankline = {
    #      enabled = true;
    #      colored_indent_levels = true;
    #    };
    #    native_lsp.enabled = true;
    #  };
    #};
    #colorschemes.onedark.enable = true;

    luaLoader.enable = true;
    globals.mapleader = ",";

    # Hide line numbers in terminal windows
    autoCmd = [
      {
        event = ["BufEnter" "BufWinEnter"];
        pattern = ["term://*"];
        callback.__raw = ''
          function()
            vim.bo.number = false
          end
        '';
      }
      {
        event = ["WinEnter"];
        pattern = ["*"];
        callback.__raw = ''
          function()
            pcall(function()
              if vim.bo.buftype == "nofile" or vim.bo.buftype == "help" then
                vim.cmd "DisableWhitespace"
              else
                vim.cmd "EnableWhitespace"
              end
            end)
          end
        '';
      }
    ];

    # TODO split into files
    keymaps = let
      keymap = mode: key: action: desc: {
        inherit action key mode;
        options = {
          silent = true;
          inherit desc;
        };
      };
    in [
      # -------------------------------------------------------------------------------------------------
      # General
      # -------------------------------------------------------------------------------------------------

      # Shift + <up/down> scroll with cursor locked to position
      (keymap ["n" "v"] "<S-Down>" "<C-e>" "")
      (keymap ["n" "v"] "<S-Up>" "<C-y>" "")
      (keymap ["i"] "<S-Down>" "<C-x><C-e>" "")
      (keymap ["i"] "<S-Up>" "<C-x><C-y>" "")

      # Shift + Alt + <arrow keys> change the current window size
      (keymap ["n"] "<M-S-Up>" ":resize -2<CR>" "")
      (keymap ["n"] "<M-S-Down>" ":resize +2<CR>" "")
      (keymap ["n"] "<M-S-Left>" ":vertical resize -2<CR>" "")
      (keymap ["n"] "<M-S-Right>" ":vertical resize +2<CR>" "")

      # Allow exiting terminal mode
      (keymap ["t"] "<C-w><Esc>" "<C-\\><C-n>" "")
      # Allow C-w in terminal mode
      (keymap ["t"] "<C-w>" "<C-\\><C-n><C-w>" "")

      # Open fixed size terminal window at the bottom
      (keymap ["n"] "<leader><CR>" ":belowright new | setlocal wfh | resize 10 | terminal<CR>" "")

      # -------------------------------------------------------------------------------------------------
      # Language server
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "gD" "<cmd>lua vim.lsp.buf.declaration()<CR>" "")
      (keymap ["n"] "gd" "<cmd>lua require('telescope.builtin').lsp_definitions()<CR>" "")
      (keymap ["n"] "K" "<cmd>lua vim.lsp.buf.hover()<CR>" "")
      (keymap ["n"] "gi" "<cmd>lua require('telescope.builtin').lsp_implementations()<CR>" "")
      (keymap ["n"] "<C-k>" "<cmd>lua vim.lsp.buf.signature_help()<CR>" "")
      (keymap ["n"] "<leader>wa" "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>" "")
      (keymap ["n"] "<leader>wr" "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>" "")
      (keymap ["n"] "<leader>wl" "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>" "")
      (keymap ["n"] "gt" "<cmd>lua require('telescope.builtin').lsp_type_definitions()<CR>" "")
      (keymap ["n"] "<leader>r" "<cmd>lua vim.lsp.buf.rename()<CR>" "")
      (keymap ["n"] "<leader>a" "<cmd>lua vim.lsp.buf.code_action()<CR>" "")
      (keymap ["n"] "gr" "<cmd>lua require('telescope.builtin').lsp_references()<CR>" "")
      (keymap ["n"] "gl" "<cmd>lua vim.diagnostic.open_float()<CR>" "")
      (keymap ["n"] "[d" "<cmd>lua vim.diagnostic.goto_prev()<CR>" "")
      (keymap ["n"] "]d" "<cmd>lua vim.diagnostic.goto_next()<CR>" "")
      (keymap ["n"] "<leader>q" "<cmd>lua vim.diagnostic.setloclist()<CR>" "")
      (keymap ["n"] "<leader>f" "<cmd>lua vim.lsp.buf.format { async = true }<CR>" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Easy Align
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "<leader>A" "<Plug>(EasyAlign)" "")
      (keymap ["v"] "<leader>A" "<Plug>(EasyAlign)" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Undotree
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "<leader>u" ":UndotreeToggle<CR>" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Better Whitespace
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "<leader>$" ":StripWhitespace<CR>" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Neotree
      # -------------------------------------------------------------------------------------------------

      # Mappings to open the tree / find the current file
      (keymap ["n"] "<leader>t" ":Neotree toggle<CR>" "")
      (keymap ["n"] "<leader>T" ":Neotree reveal<CR>" "")
      (keymap ["n"] "<leader>G" ":Neotree float git_status<CR>" "")
      (keymap ["n"] "<leader>b" ":Neotree float buffers<CR>" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Sandwich
      # -------------------------------------------------------------------------------------------------

      (keymap ["n" "v"] "m" "<Plug>(operator-sandwich-add)" "")
      (keymap ["n" "v"] "M" "<Plug>(operator-sandwich-delete)" "")
      (keymap ["n" "v"] "C-m" "<Plug>(operator-sandwich-replace)" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: gomove
      # -------------------------------------------------------------------------------------------------

      #(keymap ["n"] "<M-Left>"  "<Plug>GoNSMLeft" "")
      #(keymap ["n"] "<M-Down>"  "<Plug>GoNSMDown" "")
      #(keymap ["n"] "<M-Up>"    "<Plug>GoNSMUp" "")
      #(keymap ["n"] "<M-Right>" "<Plug>GoNSMRight" "")

      (keymap ["x"] "<M-Left>" "<Plug>GoVSMLeft" "")
      (keymap ["x"] "<M-Down>" "<Plug>GoVSMDown" "")
      (keymap ["x"] "<M-Up>" "<Plug>GoVSMUp" "")
      (keymap ["x"] "<M-Right>" "<Plug>GoVSMRight" "")

      #(keymap ["n"] "<S-M-Left>"  "<Plug>GoNSDLeft" "")
      #(keymap ["n"] "<S-M-Down>"  "<Plug>GoNSDDown" "")
      #(keymap ["n"] "<S-M-Up>"    "<Plug>GoNSDUp" "")
      #(keymap ["n"] "<S-M-Right>" "<Plug>GoNSDRight" "")

      (keymap ["x"] "<S-M-Left>" "<Plug>GoVSDLeft" "")
      (keymap ["x"] "<S-M-Down>" "<Plug>GoVSDDown" "")
      (keymap ["x"] "<S-M-Up>" "<Plug>GoVSDUp" "")
      (keymap ["x"] "<S-M-Right>" "<Plug>GoVSDRight" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: wordmotion
      # -------------------------------------------------------------------------------------------------

      (keymap ["x" "o"] "ie" "<Plug>WordMotion_iw" "")

      # -------------------------------------------------------------------------------------------------
      # Plugin: textcase
      # -------------------------------------------------------------------------------------------------

      # TODO: ... keybinds + telescope integration
    ];
  };

  home.sessionVariables.EDITOR = "nvim";
  home.shellAliases.vimdiff = "nvim -d";
}
