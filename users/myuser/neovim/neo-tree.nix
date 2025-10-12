{
  programs.nixvim.plugins.neo-tree = {
    enable = true;
    settings = {
      sort_case_insensitive = true;
      use_popups_for_input = false;
      popup_border_style = "rounded";
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
          "a".__raw =
            # lua
            ''{ "add", config = { show_path = "relative" } }'';
          "A".__raw =
            # lua
            ''{ "add_directory", config = { show_path = "relative" } }'';
          "c".__raw =
            # lua
            ''{ "copy", config = { show_path = "relative" } }'';
          "m".__raw =
            # lua
            ''{ "move", config = { show_path = "relative" } }'';
        };
      };
      default_component_configs = {
        modified.symbol = "~ ";
        indent.with_expanders = true;
        name.trailing_slash = true;
        git_status.symbols = {
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
        group_empty_dirs = true;
        follow_current_file.enabled = true;
        use_libuv_file_watcher = true;
        filtered_items = {
          hide_dotfiles = false;
          hide_by_name = [ ".git" ];
        };
      };
    };
  };
}
