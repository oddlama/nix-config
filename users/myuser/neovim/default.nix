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

    luaLoader.enable = true;
    globals.mapleader = ",";

    # Hide line numbers in terminal windows
    autoCmd = [
      {
        event = ["BufEnter" "BufWinEnter"];
        pattern = ["term://*"];
        callback.__raw =
          /*
          lua
          */
          ''
            function()
              vim.bo.number = false
            end
          '';
      }
      {
        event = ["WinEnter"];
        pattern = ["*"];
        callback.__raw =
          /*
          lua
          */
          ''
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
      (keymap ["n"] "<leader><CR>" ":belowright new | setlocal wfh | resize 10 | terminal<CR>" "Open Terminal")

      # -------------------------------------------------------------------------------------------------
      # Language server
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "gD" "<cmd>lua vim.lsp.buf.declaration()<CR>" "Goto declaration")
      (keymap ["n"] "gd" "<cmd>lua require('telescope.builtin').lsp_definitions()<CR>" "Goto definition")
      (keymap ["n"] "K" "<cmd>lua vim.lsp.buf.hover()<CR>" "Hover")
      (keymap ["n"] "gi" "<cmd>lua require('telescope.builtin').lsp_implementations()<CR>" "Goto implementation")
      (keymap ["n"] "<C-k>" "<cmd>lua vim.lsp.buf.signature_help()<CR>" "Signature Help")
      (keymap ["n"] "<leader>wa" "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>" "Add workspace folder")
      (keymap ["n"] "<leader>wr" "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>" "Remove workspace folder")
      (keymap ["n"] "<leader>wl" "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>" "List workspace folders")
      (keymap ["n"] "gt" "<cmd>lua require('telescope.builtin').lsp_type_definitions()<CR>" "Goto type-definition")
      (keymap ["n"] "<leader>r" "<cmd>lua vim.lsp.buf.rename()<CR>" "Rename")
      (keymap ["n"] "<leader>a" "<cmd>lua vim.lsp.buf.code_action()<CR>" "Code Action")
      (keymap ["n"] "gr" "<cmd>lua require('telescope.builtin').lsp_references()<CR>" "References")
      (keymap ["n"] "gl" "<cmd>lua vim.diagnostic.open_float()<CR>" "Diagnostic float")
      (keymap ["n"] "[d" "<cmd>lua vim.diagnostic.goto_prev()<CR>" "Next diagnostic")
      (keymap ["n"] "]d" "<cmd>lua vim.diagnostic.goto_next()<CR>" "Previous diagnostic")
      (keymap ["n"] "<leader>q" "<cmd>lua vim.diagnostic.setloclist()<CR>" "Show diagnostic quickfix list")
      (keymap ["n"] "<leader>f" "<cmd>lua vim.lsp.buf.format { async = true }<CR>" "Format code")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Easy Align
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "<leader>A" "<Plug>(EasyAlign)" "Easy-Align")
      (keymap ["v"] "<leader>A" "<Plug>(EasyAlign)" "Easy-Align")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Undotree
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "<leader>u" ":UndotreeToggle<CR>" "Undotree")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Better Whitespace
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "<leader>$" ":StripWhitespace<CR>" "Strip whitespace")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Neotree
      # -------------------------------------------------------------------------------------------------

      # Mappings to open the tree / find the current file
      (keymap ["n"] "<leader>t" ":Neotree toggle<CR>" "Filetree toggle")
      (keymap ["n"] "<leader>T" ":Neotree reveal<CR>" "Filetree reveal current file")
      (keymap ["n"] "<leader>G" ":Neotree float git_status<CR>" "Show git status")
      (keymap ["n"] "<leader>b" ":Neotree float buffers<CR>" "Show open buffers")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Sandwich
      # -------------------------------------------------------------------------------------------------

      (keymap ["n" "v"] "m" "<Plug>(operator-sandwich-add)" "Sandwich Add")
      (keymap ["n" "v"] "M" "<Plug>(operator-sandwich-delete)" "Sandwich Delete")
      (keymap ["n" "v"] "<C-m>" "<Plug>(operator-sandwich-replace)" "Sandwich Replace")

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

      (keymap ["x" "o"] "ie" "<Plug>WordMotion_iw" "inside subword")

      # -------------------------------------------------------------------------------------------------
      # Plugin: telescope
      # -------------------------------------------------------------------------------------------------

      (keymap ["n" "v"] "<space><space>" "<cmd>lua require('telescope.builtin').find_files()<CR>" "Telescope find files")
      (keymap ["n" "v"] "<space>g" "<cmd>lua require('telescope.builtin').live_grep()<CR>" "Telescope live grep")
      (keymap ["n" "v"] "<space>b" "<cmd>lua require('telescope.builtin').buffers()<CR>" "Telescope buffers")

      # -------------------------------------------------------------------------------------------------
      # Plugin: textcase
      # -------------------------------------------------------------------------------------------------

      (keymap ["n"] "<leader>C" "<cmd>TextCaseOpenTelescopeQuickChange<CR>" "Change word case")

      (keymap ["n"] "<leader>cu" "<cmd>lua require('textcase').current_word('to_upper_case')<CR><right>" "To UPPER CASE")
      (keymap ["n"] "<leader>cl" "<cmd>lua require('textcase').current_word('to_lower_case')<CR><right>" "To lower case")
      (keymap ["n"] "<leader>cs" "<cmd>lua require('textcase').current_word('to_snake_case')<CR><right>" "To snake_case")
      (keymap ["n"] "<leader>cd" "<cmd>lua require('textcase').current_word('to_dash_case')<CR><right>" "To dash-case")
      (keymap ["n"] "<leader>cn" "<cmd>lua require('textcase').current_word('to_constant_case')<CR><right>" "To CONSTANT_CASE")
      (keymap ["n"] "<leader>cd" "<cmd>lua require('textcase').current_word('to_dot_case')<CR><right>" "To dot.case")
      (keymap ["n"] "<leader>ca" "<cmd>lua require('textcase').current_word('to_phrase_case')<CR><right>" "To Phrase case")
      (keymap ["n"] "<leader>cc" "<cmd>lua require('textcase').current_word('to_camel_case')<CR><right>" "To camelCase")
      (keymap ["n"] "<leader>cp" "<cmd>lua require('textcase').current_word('to_pascal_case')<CR><right>" "To PascalCase")
      (keymap ["n"] "<leader>ct" "<cmd>lua require('textcase').current_word('to_title_case')<CR><right>" "To Title Case")
      (keymap ["n"] "<leader>cf" "<cmd>lua require('textcase').current_word('to_path_case')<CR><right>" "To path/case")

      (keymap ["n"] "<leader>cU" "<cmd>lua require('textcase').lsp_rename('to_upper_case')<CR><right>" "LSP Rename: To UPPER CASE")
      (keymap ["n"] "<leader>cL" "<cmd>lua require('textcase').lsp_rename('to_lower_case')<CR><right>" "LSP Rename: To lower case")
      (keymap ["n"] "<leader>cS" "<cmd>lua require('textcase').lsp_rename('to_snake_case')<CR><right>" "LSP Rename: To snake_case")
      (keymap ["n"] "<leader>cD" "<cmd>lua require('textcase').lsp_rename('to_dash_case')<CR><right>" "LSP Rename: To dash-case")
      (keymap ["n"] "<leader>cN" "<cmd>lua require('textcase').lsp_rename('to_constant_case')<CR><right>" "LSP Rename: To CONSTANT_CASE")
      (keymap ["n"] "<leader>cD" "<cmd>lua require('textcase').lsp_rename('to_dot_case')<CR><right>" "LSP Rename: To dot.case")
      (keymap ["n"] "<leader>cA" "<cmd>lua require('textcase').lsp_rename('to_phrase_case')<CR><right>" "LSP Rename: To Phrase case")
      (keymap ["n"] "<leader>cC" "<cmd>lua require('textcase').lsp_rename('to_camel_case')<CR><right>" "LSP Rename: To camelCase")
      (keymap ["n"] "<leader>cP" "<cmd>lua require('textcase').lsp_rename('to_pascal_case')<CR><right>" "LSP Rename: To PascalCase")
      (keymap ["n"] "<leader>cT" "<cmd>lua require('textcase').lsp_rename('to_title_case')<CR><right>" "LSP Rename: To Title Case")
      (keymap ["n"] "<leader>cF" "<cmd>lua require('textcase').lsp_rename('to_path_case')<CR><right>" "LSP Rename: To path/case")

      # -------------------------------------------------------------------------------------------------
      # Plugin: Neogit
      # -------------------------------------------------------------------------------------------------

      (keymap ["n" "v"] "<leader>g" "<cmd>lua require('neogit').open()<CR>" "Open Neogit")
    ];
  };

  home.sessionVariables.EDITOR = "nvim";
  home.shellAliases.vimdiff = "nvim -d";
}
