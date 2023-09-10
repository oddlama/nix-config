{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    defaultEditor = true;
  };

  home.persistence."/state".directories = [
    ".local/share/nvim"
    ".local/state/nvim"
    ".cache/nvim"
  ];
}
