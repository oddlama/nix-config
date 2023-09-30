{
  lib,
  pkgs,
  ...
}: {
  disabledModules = ["programs/starship.nix"];
  imports = [./starship-module.nix];

  programs.starship = {
    enable = true;
    package = let
      src = pkgs.fetchFromGitHub {
        owner = "oddlama";
        repo = "starship";
        rev = "feat-more-dynamic-username-and-hostname";
        hash = "sha256-br1fpQPgclJcsm4INBZ+vk4/PtpnUCkWMHll0rjdGmQ=";
      };
    in
      pkgs.starship.overrideAttrs (_finalAttrs: previousAttrs: {
        inherit src;
        cargoDeps = previousAttrs.cargoDeps.overrideAttrs (_: {
          inherit src;
          outputHash = "sha256-L4N55ghbPsBrESRK0vHGDSDytFCnib7ghoMKnWFIZvw=";
        });
      });
    settings = {
      add_newline = false;
      format = lib.concatStrings [
        "$username"
        "$hostname"
        " $directory "
        "($git_branch )"
        "($git_commit )"
        "$git_state"
        "$git_status"
        "$character"
      ];
      right_format = lib.concatStrings [
        "($status )"
        "($cmd_duration )"
        "($jobs )"
        "($python )"
        "($rust )"
        "$time"
      ];
      command_timeout = 60; # 60ms must be enough. I like a responsive prompt more than additional git information.
      username = {
        format = "[$user]($style) ";
        show_if_root = false;
        show_if_ssh = false;
        style = "yellow";
      };
      hostname = {
        format = "[$hostname]($style)[$ssh_symbol](green)";
        ssh_only = false;
        ssh_symbol = " 󰣀";
        style = "bold purple";
        user_overrides.root.style = "bold red";
      };
      directory = {
        format = "[$path]($style)[$read_only]($read_only_style)";
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
        format = "[$symbol$branch]($style)";
        symbol = " ";
        style = "green";
      };
      git_commit = {
        commit_hash_length = 8;
        format = "[$hash$tag]($style)";
        style = "green";
      };
      git_status = {
        conflicted = "$count";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇡$ahead_count⇣$behind_count";
        untracked = "?$count";
        stashed = "\\$$count";
        modified = "!$count";
        staged = "+$count";
        renamed = "→$count";
        deleted = "-$count";
        format = lib.concatStrings [
          "[($conflicted )](red)"
          "[($stashed )](magenta)"
          "[($staged )](green)"
          "[($deleted )](red)"
          "[($renamed )](blue)"
          "[($modified )](yellow)"
          "[($untracked )](blue)"
          "[($ahead_behind )](green)"
        ];
      };
      status = {
        disabled = false;
        pipestatus = true;
        pipestatus_format = "$pipestatus => [$int( $signal_name)]($style)";
        pipestatus_separator = "[|]($style)";
        pipestatus_segment_format = "[$status]($style)";
        format = "[$status( $signal_name)]($style)";
        style = "red";
      };
      python = {
        format = "[$symbol$pyenv_prefix($version )(\($virtualenv\) )]($style)";
      };
      cmd_duration = {
        format = "[ $duration]($style)";
        style = "yellow";
      };
      time = {
        format = "[ $time]($style)";
        style = "cyan";
        disabled = false;
      };
    };
  };
}
