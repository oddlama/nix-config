{
  programs.nixvim.plugins.neo-tree = {
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
}
