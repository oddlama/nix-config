# TODO whichkey
# TODO alpha menu
# TODO keybinds
# TODO window select
# TODO neotree left darker
# TODO neotree focsed shows lualine wrongly (full instead of nothing)
# TODO lualine inactive ------ is ugly
{
  lib,
  pkgs,
  ...
}: {
  home.shellAliases.nixvim = lib.getExe (pkgs.nixvim.makeNixvim {
    package = pkgs.neovim-clean;

    # TODO for wayland:
    # clipboard.providers.wl-copy.enable = true;

    colorschemes.catppuccin = {
      enable = true;
      flavour = "mocha";
      integrations = {
        dap.enabled = true;
        dap.enable_ui = true;
        fidget = true;
        indent_blankline = {
          enabled = true;
          colored_indent_levels = true;
        };
        native_lsp.enabled = true;
      };
    };

    globals.mapleader = ",";

    # Hide line numbers in terminal windows
    autoCmd = [
      {
        event = ["BufEnter" "BufWinEnter"];
        pattern = ["term://*"];
        callback = {
          __raw = ''
            function()
              vim.bo.number = false
            end
          '';
        };
      }
    ];

    options = {
      # -------------------------------------------------------------------------------------------------
      # General
      # -------------------------------------------------------------------------------------------------

      undolevels = 1000000; # Set maximum undo levels
      undofile = true; # Enable persistent undo which persists undo history across vim sessions
      updatetime = 300; # Save swap file after 300ms
      mouse = "a"; # Enable full mouse support

      # -------------------------------------------------------------------------------------------------
      # Editor visuals
      # -------------------------------------------------------------------------------------------------

      termguicolors = true; # Enable true color in terminals

      splitkeep = "screen"; # Try not to move text when opening/closing splits
      wrap = false; # Do not wrap text longer than the window's width
      scrolloff = 2; # Keep 2 lines above and below the cursor.
      sidescrolloff = 2; # Keep 2 lines left and right of the cursor.

      number = true; # Show line numbers
      cursorline = true; # Enable cursorline, colorscheme only shows this in number column
      wildmode = ["list" "full"]; # Only complete the longest common prefix and list all results
      fillchars = {stlnc = "─";}; # Show separators in inactive window statuslines

      # FIXME: disabled because this really fucks everything up in the terminal.
      title = false; # Sets the window title
      # titlestring = "%t%( %M%)%( (%{expand(\"%:~:.:h\")})%) - nvim"; # The format for the window title

      # -------------------------------------------------------------------------------------------------
      # Editing behavior
      # -------------------------------------------------------------------------------------------------

      whichwrap = ""; # Never let the curser switch to the next line when reaching line end
      ignorecase = true; # Ignore case in search by default
      smartcase = true; # Be case sensitive when an upper-case character is included

      expandtab = false;
      tabstop = 4; # Set indentation of tabs to be equal to 4 spaces.
      shiftwidth = 4;
      softtabstop = 4;
      shiftround = true; # Round indentation commands to next multiple of shiftwidth

      # r = insert comment leader when hitting <Enter> in insert mode
      # q = allow explicit formatting with gq
      # j = remove comment leaders when joining lines if it makes sense
      formatoptions = "rqj";

      # Allow the curser to be positioned on cells that have no actual character;
      # Like moving beyond EOL or on any visual 'space' of a tab character
      virtualedit = "all";
      selection = "old"; # Do not include line ends in past the-line selections
      smartindent = true; # Use smart auto indenting for all file types

      timeoutlen = 20; # Only wait 20 milliseconds for characters to arrive (see :help timeout)
      ttimeoutlen = 20;
      timeout = false; # Disable timeout, but enable ttimeout (only timeout on keycodes)
      ttimeout = true;

      grepprg = "rg --vimgrep --smart-case --follow"; # Replace grep with ripgrep
    };

    keymaps = let
      withDefaults = lib.recursiveUpdate {
        options = {
          silent = true;
          noremap = true;
        };
      };
    in
      map withDefaults [
        {
          action = "<C-]>";
          key = "<CR>";
          mode = ["n"];
          options.desc = "Jump to tag under cursor";
        }
      ];

    luaLoader.enable = true;
    plugins = {
      # -------------------------------------------------------------------------------------------------
      # Library plugins
      # -------------------------------------------------------------------------------------------------

      notify = {
        enable = true;
        stages = "static";
        render.__raw = ''"compact"'';
        icons = {
          debug = "";
          error = "󰅙";
          info = "";
          trace = "󰰥";
          warn = "";
        };
      };

      # -------------------------------------------------------------------------------------------------
      # Appearance
      # -------------------------------------------------------------------------------------------------

      # Statusline
      lualine = {
        enable = true;
        extensions = ["fzf" "nvim-dap-ui" "symbols-outline" "trouble" "neo-tree" "quickfix" "fugitive"];
        componentSeparators = null;
        # componentSeparators.left = "|";
        # componentSeparators.right = "|";
        # sectionSeparators.left = "";
        # sectionSeparators.right = "";
        sections = {
          lualine_a = ["mode"];
          lualine_b = ["branch" "filename"];
          lualine_c = ["diff" "diagnostics"];
          lualine_x = ["encoding" "fileformat" "filetype"];
          lualine_y = ["progress"];
          lualine_z = ["location"];
        };
        inactiveSections = {
          lualine_a = ["filename"];
          lualine_b = [];
          lualine_c = ["diagnostics"];
          lualine_x = [];
          lualine_y = [];
          lualine_z = ["location"];
        };
      };

      # Line indentation markers
      indent-blankline.enable = true;

      # Show invalid whitespace
      # TODO use { "ntpeters/vim-better-whitespace", config = conf_fn "better-whitespace" }

      # Rainbow parentheses
      rainbow-delimiters.enable = true;

      # Replace built-in LSP prompts and windows
      # TODO use { "stevearc/dressing.nvim", config = conf_setup "dressing" }
      # Status updates for LSP progress in right bottom corner.
      fidget.enable = true;
      # Show latex math equations
      # TODO use { "jbyuki/nabla.nvim", config = conf_fn "nabla" }
      # Show colors
      nvim-colorizer.enable = true;

      # Breadcrumbs
      # TODO navic.enable = true; or dropbar?

      # -------------------------------------------------------------------------------------------------
      # Language support
      # -------------------------------------------------------------------------------------------------

      treesitter = {
        enable = true;
        folding = true;
        indent = true;

        incrementalSelection = {
          enable = true;
          keymaps = {
            initSelection = "<C-Space>";
            nodeIncremental = "<C-Space>";
            scopeIncremental = "<C-S-Space>";
            nodeDecremental = "<C-B>";
          };
        };

        nixvimInjections = true;
      };

      # Show the current function / context in topmost line
      treesitter-context.enable = true;

      # Cargo.toml dependency completion
      crates-nvim = {
        enable = true;
        extraOptions = {
          src.cmp.enabled = true;
        };
      };

      # Rust specific LSP tools
      rust-tools = {
        enable = true;
        server.check.command = "clippy";
      };

      # -------------------------------------------------------------------------------------------------
      # Editing
      # -------------------------------------------------------------------------------------------------

      # Multicursor
      # TODO use { "mg979/vim-visual-multi" }
      # Commenting
      comment-nvim.enable = true;
      # Modify Surrounding things like parenthesis and quotes
      # TODO use { "machakann/vim-sandwich", config = conf_fn "sandwich" }
      # Extend vim's "%" key
      vim-matchup.enable = true;
      # Align
      # TODO use "junegunn/vim-easy-align"
      # Move blocks
      # TODO use { "booperlv/nvim-gomove", config = conf_setup "gomove" }
      # Case changer
      # TODO use "johmsalas/text-case.nvim"
      # camelcase (and similar) word motions and textobjects
      # TODO use { "chaoren/vim-wordmotion", config = conf_fn "wordmotion" }
      # Respect editor-config files
      # TODO use { "gpanders/editorconfig.nvim" }

      # ----------------------------------------------------------------------------------------------------
      # Functionality
      # ----------------------------------------------------------------------------------------------------

      # Fzf picker for arbitrary stuff
      telescope = {
        enable = true;
        enabledExtensions = ["fzf" "notify" "ui-select"];
        extensions.fzf-native.enable = true;
      };

      # Startup screen
      # TODO use { "goolord/alpha-nvim", config = conf_module "alpha" }
      # Window Picker
      # TODO use { "s1n7ax/nvim-window-picker", tag = "v1.*", config = conf_setup "window-picker" }
      # Filebrowser
      neo-tree = {
        enable = true;
        sortCaseInsensitive = true;
        usePopupsForInput = false;
        popupBorderStyle = "rounded";
        # TODO window_opts.winblend = 0;
        window = {
          width = 34;
          position = "left";
          mappings = {
            "<CR>" = "open_with_window_picker";
            "s" = "split_with_window_picker";
            "v" = "vsplit_with_window_picker";
            "t" = "open_tabnew";
            "z" = "close_all_nodes";
            "Z" = "expand_all_nodes";
            "a".__raw = ''{ "add", config = { show_path = "relative" } }'';
            "A".__raw = ''{ "add_directory", config = { show_path = "relative" } }'';
            "c".__raw = ''{ "copy", config = { show_path = "relative" } }'';
            "m".__raw = ''{ "move", config = { show_path = "relative" } }'';
          };
        };
        defaultComponentConfigs = {
          modified.symbol = "~ ";
          indent.withExpanders = true;
          name.trailingSlash = true;
          gitStatus.symbols = {
            added = "+";
            deleted = "✖";
            modified = "";
            renamed = "➜";
            untracked = "?";
            ignored = "󰛑";
            unstaged = ""; # 󰄱
            staged = "󰄵";
            conflict = "";
          };
        };
        filesystem = {
          window.mappings = {
            "gA" = "git_add_all";
            "ga" = "git_add_file";
            "gu" = "git_unstage_file";
          };
          groupEmptyDirs = true;
          followCurrentFile.enabled = true;
          useLibuvFileWatcher = true;
          filteredItems = {
            hideDotfiles = false;
            hideByName = [".git"];
          };
        };
      };

      # Undo tree
      undotree = {
        enable = true;
        focusOnToggle = true;
        windowLayout = 4;
      };

      # Gpg integration
      # TODO use "jamessan/vim-gnupg"

      # -------------------------------------------------------------------------------------------------
      # Git
      # -------------------------------------------------------------------------------------------------

      # Git status in signcolumn
      gitsigns.enable = true;

      # Git commands
      fugitive.enable = true;

      # Manage git from within neovim
      neogit = {
        enable = true;
        disableBuiltinNotifications = true;
      };

      diffview.enable = true;

      # -------------------------------------------------------------------------------------------------
      # Completion
      # -------------------------------------------------------------------------------------------------

      lsp = {
        enable = true;
        preConfig = ''
          local lsp_symbol = function(name, icon)
            vim.fn.sign_define(
              "DiagnosticSign" .. name,
              { text = icon, numhl = "Diagnostic" .. name, texthl = "Diagnostic" .. name }
            )
          end

          lsp_symbol("Error", "󰅙")
          lsp_symbol("Info", "")
          lsp_symbol("Hint", "󰌵")
          lsp_symbol("Warn", "")
        '';
        servers = {
          bashls.enable = true;
          cssls.enable = true;
          html.enable = true;
          lua-ls.enable = true;
          # TODO handeled by rust-tools? rust-analyzer = {
          # TODO handeled by rust-tools?   enable = true;
          # TODO handeled by rust-tools?   settings = {
          # TODO handeled by rust-tools?     checkOnSave = true;
          # TODO handeled by rust-tools?     check.command = "clippy";
          # TODO handeled by rust-tools?   };
          # TODO handeled by rust-tools? };
          nil_ls = {
            enable = true;
            settings = {
              formatting.command = [(lib.getExe pkgs.alejandra) "--quiet"];
            };
          };
          nixd.enable = true;
        };

        #keymaps = {
        #  diagnostic = {
        #    "<leader>k" = "goto_prev";
        #    "<leader>j" = "goto_next";
        #  };
        #  lspBuf = {
        #    "gd" = "definition";
        #    "gD" = "references";
        #    "<leader>lt" = "type_definition";
        #    "gi" = "implementation";
        #    "K" = "hover";
        #    "<leader>k" = "hover";
        #    "<leader>r" = "rename";
        #  };
        #};
      };

      none-ls = {
        enable = true;
        sources = {
          code_actions = {
            # gitsigns.enable = true;
            shellcheck.enable = true;
          };
          diagnostics = {
            deadnix.enable = true;
            gitlint.enable = true;
            luacheck.enable = true;
            protolint.enable = true;
            shellcheck.enable = true;
          };
          formatting = {
            alejandra.enable = true;
            jq.enable = true;
            markdownlint.enable = true;
            rustfmt.enable = true;
            sqlfluff.enable = true;
            shfmt.enable = true;
            stylua.enable = true;
          };
        };
      };

      luasnip = {
        enable = true;
        extraConfig = {
          history = true;
          # Update dynamic snippets while typing
          updateevents = "TextChanged,TextChangedI";
          enable_autosnippets = true;
        };
      };

      cmp_luasnip.enable = true;
      cmp-cmdline.enable = true;
      cmp-cmdline-history.enable = true;
      cmp-path.enable = true;
      cmp-emoji.enable = true;
      cmp-treesitter.enable = true;
      cmp-nvim-lsp.enable = true;
      cmp-nvim-lsp-document-symbol.enable = true;
      cmp-nvim-lsp-signature-help.enable = true;
      nvim-cmp = {
        enable = true;
        sources = [
          {name = "nvim_lsp_signature_help";}
          {name = "nvim_lsp";}
          {name = "nvim_lsp_document_symbol";}
          {name = "path";}
          {name = "treesitter";}
          {name = "luasnip";}
          {name = "emoji";}
        ];
        mappingPresets = ["insert"];
        mapping = {
          "<CR>" = ''
            cmp.mapping.confirm({
              behavior = cmp.ConfirmBehavior.Replace,
              select = false,
            })
          '';
          "<C-d>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
          "<C-e>" = "cmp.mapping.abort()";
          "<Tab>" = {
            modes = ["i" "s"];
            action = ''
              function(fallback)
                local has_words_before = function()
                  local line, col = table.unpack(vim.api.nvim_win_get_cursor(0))
                  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s" == nil
                end

                if cmp.visible() then
                  cmp.select_next_item()
                elseif require("luasnip").expandable() then
                  require("luasnip").expand()
                elseif require("luasnip").expand_or_locally_jumpable() then
                  require("luasnip").expand_or_jump()
                elseif has_words_before() then
                  cmp.complete()
                else
                  fallback()
                end
              end
            '';
          };
          "<S-Tab>" = {
            modes = ["i" "s"];
            action = ''
              function(fallback)
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end
            '';
          };
        };
        formatting.fields = ["abbr" "kind" "menu"];
        formatting.format = ''
          function(_, vim_item)
            local icons = {
              Namespace = "󰌗",
              Text = "󰉿",
              Method = "󰆧",
              Function = "󰆧",
              Constructor = "",
              Field = "󰜢",
              Variable = "󰀫",
              Class = "󰠱",
              Interface = "",
              Module = "",
              Property = "󰜢",
              Unit = "󰑭",
              Value = "󰎠",
              Enum = "",
              Keyword = "󰌋",
              Snippet = "",
              Color = "󰏘",
              File = "󰈚",
              Reference = "󰈇",
              Folder = "󰉋",
              EnumMember = "",
              Constant = "󰏿",
              Struct = "󰙅",
              Event = "",
              Operator = "󰆕",
              TypeParameter = "󰊄",
              Table = "",
              Object = "󰅩",
              Tag = "",
              Array = "[]",
              Boolean = "",
              Number = "",
              Null = "󰟢",
              String = "󰉿",
              Calendar = "",
              Watch = "󰥔",
              Package = "",
              Copilot = "",
              Codeium = "",
              TabNine = "",
            }
            vim_item.kind = string.format("%s %s", icons[vim_item.kind], vim_item.kind)
            return vim_item
          end
        '';
        snippet.expand = "luasnip";
      };

      # TODO use "ray-x/lsp_signature.nvim"

      # TODO dap.enable = true;

      # -------------------------------------------------------------------------------------------------
      # Miscellaneous
      # -------------------------------------------------------------------------------------------------

      # TODO use { "folke/trouble.nvim", config = conf_setup "trouble" }
      # Quickfix menu
      trouble.enable = true;
      # Highlight certain keywords
      todo-comments.enable = true;
      # TODO use { "liuchengxu/vista.vim", cmd = "Vista" }
    };

    extraPlugins = with pkgs.vimPlugins; [
      nvim-web-devicons
      nvim-window-picker
      telescope-ui-select-nvim
    ];

    extraConfigLuaPost = ''
      require("nvim-web-devicons").setup {
        override = {
          default_icon = { icon = "󰈚", name = "Default", },
          c = { icon = "", name = "c", },
          css = { icon = "", name = "css", },
          dart = { icon = "", name = "dart", },
          deb = { icon = "", name = "deb", },
          Dockerfile = { icon = "", name = "Dockerfile", },
          html = { icon = "", name = "html", },
          jpeg = { icon = "󰉏", name = "jpeg", },
          jpg = { icon = "󰉏", name = "jpg", },
          js = { icon = "󰌞", name = "js", },
          kt = { icon = "󱈙", name = "kt", },
          lock = { icon = "󰌾", name = "lock", },
          lua = { icon = "", name = "lua", },
          mp3 = { icon = "󰎆", name = "mp3", },
          mp4 = { icon = "", name = "mp4", },
          out = { icon = "", name = "out", },
          png = { icon = "󰉏", name = "png", },
          py = { icon = "", name = "py", },
          ["robots.txt"] = { icon = "󰚩", name = "robots", },
          toml = { icon = "", name = "toml", },
          ts = { icon = "󰛦", name = "ts", },
          ttf = { icon = "", name = "TrueTypeFont", },
          rb = { icon = "", name = "rb", },
          rpm = { icon = "", name = "rpm", },
          vue = { icon = "󰡄", name = "vue", },
          woff = { icon = "", name = "WebOpenFontFormat", },
          woff2 = { icon = "", name = "WebOpenFontFormat2", },
          xz = { icon = "", name = "xz", },
          zip = { icon = "", name = "zip", },
        },
        default = true,
      }

      local cmp = require "cmp"
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "cmdline" },
          { name = "cmp-cmdline-history" },
        },
      })

      require("window-picker").setup {
        hint = "floating-big-letter",
        selection_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        filter_rules = {
          bo = {
            filetype = { "neo-tree", "neo-tree-popup", "notify", "quickfix" },
            buftype = { "terminal", "quickfix", "prompt" },
          },
        },
        other_win_hl_color = "#4493c8",
      }
    '';
  });

  home.packages = let
    nvimConfig = pkgs.neovimUtils.makeNeovimConfig {
      wrapRc = false;
      withPython3 = true;
      withRuby = true;
      withNodeJs = true;
      extraPython3Packages = p: with p; [openai];
    };
  in [(pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped nvimConfig)];

  home.sessionVariables.EDITOR = "nvim";
  home.shellAliases.vimdiff = "nvim -d";

  xdg.configFile = {
    "nvim/ftplugin".source = ./ftplugin;
    "nvim/init.lua".source = ./init.lua;
    "nvim/lua".source = ./lua;
  };
}
