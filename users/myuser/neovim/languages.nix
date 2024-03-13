{pkgs, ...}: {
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

      # Cargo.toml dependency completion
      crates-nvim = {
        enable = true;
        extraOptions = {
          src.cmp.enabled = true;
        };
      };

      rustaceanvim = {
        enable = true;
        server.settings.files.excludeDirs = [".direnv"];
        dap.autoloadConfigurations = true;
        dap.adapter = let
          code-lldb = pkgs.vscode-extensions.vadimcn.vscode-lldb;
        in {
          executable.command = "${code-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
          executable.args = [
            "--liblldb"
            "${code-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/lldb/lib/liblldb.dylib"
            "--port"
            "31337"
          ];
          type = "server";
          port = "31337";
          host = "127.0.0.1";
        };
      };
    };
  };
}
