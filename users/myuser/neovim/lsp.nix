{
  lib,
  pkgs,
  ...
}:
{
  programs.nixvim.plugins = {
    jdtls = {
      enable = true;
      settings.cmd = [
        "${lib.getExe pkgs.jdt-language-server}"
        "-data"
        "~/.cache/jdtls/workspace"
      ];
    };
    lsp = {
      enable = true;
      preConfig =
        # lua
        ''
          local lsp_symbol = function(name, icon)
          vim.fn.sign_define(
            "DiagnosticSign" .. name,
            { text = icon, numhl = "Diagnostic" .. name, texthl = "Diagnostic" .. name }
          )
          end

          lsp_symbol("Error", "󰅙")
          lsp_symbol("Info", "")
          lsp_symbol("Hint", "󰌵")
          lsp_symbol("Warn", "")
        '';
      servers = {
        bashls.enable = true;
        cssls.enable = true;
        html.enable = true;
        clangd.enable = true;
        # rust-analyzer should not be set here because of rustaceanvim
        nil_ls = {
          enable = true;
          settings = {
            formatting.command = [
              (lib.getExe pkgs.nixfmt-rfc-style)
              "--quiet"
            ];
          };
        };
        nixd.enable = true;
      };

      #keymaps = {
      #  diagnostic = {
      #    "<leader>k" = "goto_prev";
      #    "<leader>j" = "goto_next";
      #  };
      #  lspBuf = {
      #    "gd" = "definition";
      #    "gD" = "references";
      #    "<leader>lt" = "type_definition";
      #    "gi" = "implementation";
      #    "K" = "hover";
      #    "<leader>k" = "hover";
      #    "<leader>r" = "rename";
      #  };
      #};
    };

    none-ls = {
      enable = true;
      sources = {
        diagnostics = {
          deadnix.enable = true;
          gitlint.enable = true;
          protolint.enable = true;
        };
        formatting = {
          markdownlint.enable = true;
          sqlfluff.enable = true;
          shfmt.enable = true;
        };
      };
    };

    dap.enable = true;
    dap-virtual-text.enable = true;
    dap-ui.enable = true;
  };
}
