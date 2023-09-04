local lsp_symbol = function(name, icon)
	vim.fn.sign_define(
		"DiagnosticSign" .. name,
		{ text = icon, numhl = "Diagnostic" .. name, texthl = "Diagnostic" .. name }
	)
end

lsp_symbol("Error", "")
lsp_symbol("Info", "")
lsp_symbol("Hint", "")
lsp_symbol("Warn", "")

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
	border = "single",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
	border = "single",
	focusable = false,
	relative = "cursor",
})

-- Borders for LspInfo winodw
local win = require "lspconfig.ui.windows"
local _default_opts = win.default_opts

win.default_opts = function(options)
	local opts = _default_opts(options)
	opts.border = "single"
	return opts
end

local lspconfig = require "lspconfig"

-- lua: https://github.com/sumneko/lua-language-server
lspconfig.sumneko_lua.setup {
	settings = {
		Lua = {
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = { "vim" },
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = vim.api.nvim_get_runtime_file("", true),
			},
			-- Do not send telemetry data containing a randomized but unique identifier
			telemetry = { enable = false },
		},
	},
}

lspconfig.clangd.setup {}
lspconfig.bashls.setup {}
lspconfig.cmake.setup {}
lspconfig.html.setup {}
lspconfig.jdtls.setup {}
lspconfig.pyright.setup {}
lspconfig.texlab.setup {}

local rt = require "rust-tools"
rt.setup {
	server = {
		on_attach = function(_, bufnr)
			-- Hover actions
			vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
		end,
		settings = {
			["rust-analyzer"] = {
				checkOnSave = {
					command = "clippy",
				},
			},
		},
	},
}

require("lsp_signature").setup()
