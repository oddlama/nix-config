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
        settings = {
          indent.enable = true;

          incremental_selection = {
            enable = true;
            keymaps = {
              init_selection = "<C-Space>";
              node_incremental = "<C-Space>";
              scope_incremental = "<C-S-Space>";
              node_decremental = "<C-B>";
            };
          };
        };
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
        settings = {
          server.default_settings.files.excludeDirs = [".direnv"];
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
  };
}
