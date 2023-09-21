{
  programs.neovim-custom.enable = true;

  home.persistence."/state".directories = [
    ".local/share/nvim"
    ".local/state/nvim"
    ".cache/nvim"
  ];
}
