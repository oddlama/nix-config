{
  programs.nixvim = {
    files."ftplugin/nix.lua".extraConfigLua = ''
      vim.opt_local.expandtab = true
      vim.opt_local.tabstop = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.softtabstop = 2
    '';

    plugins = {
      treesitter = {
        enable = true;
        # TODO (autocmd * zR needed) folding = true;
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
    };
  };
}
