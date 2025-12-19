{
  programs.nixvim.plugins = {
    # Git status in signcolumn
    gitsigns.enable = true;

    # Git commands
    fugitive.enable = true;

    diffview.enable = true;

    # Manage git from within neovim
    neogit.enable = true;
  };
}
