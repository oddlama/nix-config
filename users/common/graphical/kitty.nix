{
  config,
  pkgs,
  ...
}: {
  programs.kitty = {
    enable = true;
    package = pkgs.kitty.overrideAttrs (finalAttrs: prevAttrs: {
      doCheck = false;
    });
    font = {
      package = pkgs.nerdfonts;
      name = "FiraCode Nerd Font";
      size = 10;
    };
    settings = {
      # Use xterm-256color because copying terminfo-kitty is painful.
      term = "xterm-256color";

      # Do not wait for inherited child processes.
      close_on_child_death = "yes";

      # Disable ligatures.
      disable_ligatures = "always";

      # Modified onehalfdark color scheme
      foreground = "#c9d3e5";
      background = "#090a0c";
      cursor = "#cccccc";

      color0 = " #090a0c";
      color8 = " #393e48";
      color1 = " #b2555d";
      color9 = " #e06c75";
      color2 = " #81a566";
      color10 = "#98c379";
      color3 = " #ccab6e";
      color11 = "#e6c17c";
      color4 = " #5395cc";
      color12 = "#61afef";
      color5 = " #9378de";
      color13 = "#c678dd";
      color6 = " #56b6c2";
      color14 = "#56b6c2";
      color7 = " #979eab";
      color15 = "#abb2bf";

      selection_foreground = "#282c34";
      selection_background = "#979eab";

      # Disable cursor blinking
      cursor_blink_interval = "0";

      # Big fat scrollback buffer
      scrollback_lines = "100000";
      # Set scrollback buffer for pager in MB
      scrollback_pager_history_size = "256";

      # Don't copy on select
      copy_on_select = "no";

      # Set program to open urls with
      open_url_with = "xdg-open";

      # Fuck the bell
      enable_audio_bell = "no";
    };
    keybindings = {
      # Keyboard mappings
      "shift+page_up" = "scroll_page_up";
      "shift+page_down" = "scroll_page_down";
      "ctrl+shift+." = "change_font_size all -2.0";
      "ctrl+shift+," = "change_font_size all +2.0";
    };
    extraConfig = ''
      # Use nvim as scrollback pager
      scrollback_pager nvim -u NONE -c "set nonumber nolist showtabline=0 foldcolumn=0 laststatus=0" -c "autocmd TermOpen * normal G" -c "silent write! /tmp/kitty_scrollback_buffer | te head -c-1 /tmp/kitty_scrollback_buffer; rm /tmp/kitty_scrollback_buffer; cat"
    '';
  };
}
