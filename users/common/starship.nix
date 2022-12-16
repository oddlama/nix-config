{lib, ...}: {
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_status"
        "$character"
      ];
      right_format = lib.concatStrings [
        "$status"
        "$cmd_duration"
        "$jobs"
        "$package"
        "$python"
        "$rust"
        "$nix_shell"
        "$time"
      ];

      username = {
        format = "[$user]($style) ";
        style_root = "red";
        style_user = "cyan";
      };
      hostname = {
        format = "[$ssh_symbol$hostname]($style) ";
        ssh_only = false;
        ssh_symbol = "🌐";
        style = "cyan";
      };
      directory = {
        fish_style_pwd_dir_length = 1;
        style = "bold blue";
      };
      character = {
        success_symbol = "\\$";
        error_symbol = "\\$";
        vimcmd_symbol = "[](bold green)";
        vimcmd_replace_one_symbol = "[](bold purple)";
        vimcmd_replace_symbol = "[](bold purple)";
        vimcmd_visual_symbol = "[](bold yellow)";
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "green";
      };
      git_commit = {
        commit_hash_length = 8;
        format = "[$hash$tag]($style) ";
        style = "green";
      };
      git_status = {
        conflicted = "$count ";
        ahead = "⇡$count ";
        behind = "⇣$count ";
        diverged = "⇡$ahead_count⇣$behind_count ";
        untracked = "?$count ";
        stashed = "\\$$count ";
        modified = "!$count ";
        staged = "+$count ";
        renamed = "→$count ";
        deleted = "-$count ";
        format = "[$conflicted](red)[$stashed](magenta)[$staged](green)[$deleted](red)[$renamed](blue)[$modified](yellow)[$untracked](yellow)[$ahead_behind](green)";
      };
      status = {
        pipestatus = true;
        disabled = false;
        pipestatus_format = "$pipestatus => [$symbol$common_meaning$signal_name$maybe_int]($style)";
        pipestatus_segment_format = "[$symbol$status]($style)";
        format = "[$symbol$status$signal_name]($style)";
      };
      cmd_duration = {
        format = "[ $duration]($style) ";
        style = "yellow";
      };
      time = {
        format = "[ $time]($style) ";
        style = "cyan";
        disabled = false;
      };
    };
  };
}
