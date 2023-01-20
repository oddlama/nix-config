pcall(require, "impatient")
require "options"
require "keymaps"

-- TODO: this should be in treesitter.lua, but it doesn't work there.
-- Something is overriding it.
-- Use treesitter to determine folds, and always start unfolded.
-- FIXME: disabled because extremely slow. apparently called for each line.
--vim.opt.foldlevelstart = 99
--vim.opt.foldmethod = 'expr'
--vim.opt.foldexpr = 'nvim_treesitter#foldexpr()'

local function conf_module(module)
	return "require('plugins." .. module .. "')"
end
local function conf_setup(module)
	return "require('" .. module .. "').setup(require('plugins.others')['" .. module .. "'] or {})"
end
local function conf_fn(module)
	return "require('plugins.others')['" .. module .. "']()"
end
local bootstrap = require "utils.bootstrap"
local packer_bootstrap = bootstrap.ensure_packer()
local packer = require "packer"

return packer.startup(function(use)
	use "wbthomason/packer.nvim" -- Packer can manage itself
	use "lewis6991/impatient.nvim" -- Lua module cache

	----------------------------------------------------------------------------------------------------
	-- Library plugins
	----------------------------------------------------------------------------------------------------

	-- Utility functions
	use "nvim-lua/plenary.nvim"
	use "nvim-lua/popup.nvim"
	use "MunifTanjim/nui.nvim"
	-- Notifications (should be early)
	use { "rcarriga/nvim-notify", config = conf_fn "notify" }
	-- Icon definitions for use in other plugins
	use { "kyazdani42/nvim-web-devicons", config = conf_fn "nvim-web-devicons" }

	----------------------------------------------------------------------------------------------------
	-- Appearance
	----------------------------------------------------------------------------------------------------

	-- Colorscheme
	use { "navarasu/onedark.nvim", config = conf_fn "onedark" }
	-- Statusline
	use { "nvim-lualine/lualine.nvim", config = conf_fn "lualine", after = "onedark.nvim" }
	-- Colored parentheses
	use "p00f/nvim-ts-rainbow"
	-- Line indentation markers
	use { "lukas-reineke/indent-blankline.nvim", config = conf_setup "indent_blankline" }
	-- Show invalid whitespace
	use { "ntpeters/vim-better-whitespace", config = conf_fn "better-whitespace" }
	-- Git status in signcolumn
	use { "lewis6991/gitsigns.nvim", config = conf_module "gitsigns" }
	-- Replace built-in LSP prompts and windows
	use { "stevearc/dressing.nvim", config = conf_setup "dressing" }
	-- Status updates for LSP progress in right bottom corner.
	use { "j-hui/fidget.nvim", after = "nvim-lspconfig", config = conf_setup "fidget" }
	-- Show latex math equations
	use { "jbyuki/nabla.nvim", config = conf_fn "nabla" }
	-- Show colors
	use { "norcalli/nvim-colorizer.lua", config = conf_setup "colorizer" }

	----------------------------------------------------------------------------------------------------
	-- Language support
	----------------------------------------------------------------------------------------------------

	-- Syntax parsing
	use { "nvim-treesitter/nvim-treesitter", run = ":TSUpdate", config = conf_module "treesitter" }
	use { "nvim-treesitter/playground", after = "nvim-treesitter" }
	-- Rust specific tools
	use { "simrat39/rust-tools.nvim", before = "nvim-lspconfig" }
	-- Language server configurations
	use { "neovim/nvim-lspconfig", config = conf_module "lspconfig", after = "mason-lspconfig.nvim" }
	-- Neovim as an additional language server
	use { "jose-elias-alvarez/null-ls.nvim", config = conf_fn "null-ls" }

	----------------------------------------------------------------------------------------------------
	-- Editing
	----------------------------------------------------------------------------------------------------

	-- Multicursor
	use { "mg979/vim-visual-multi" }
	-- Commenting
	use { "numToStr/Comment.nvim", config = conf_setup "Comment" }
	-- Modify Surrounding things like parenthesis and quotes
	use { "machakann/vim-sandwich", config = conf_fn "sandwich" }
	-- Extend vim's "%" key
	use "andymass/vim-matchup"
	-- Align
	use "junegunn/vim-easy-align"
	-- Move blocks
	use { "booperlv/nvim-gomove", config = conf_setup "gomove" }
	-- Case changer
	use "johmsalas/text-case.nvim"
	-- camelcase (and similar) word motions and textobjects
	use { "chaoren/vim-wordmotion", config = conf_fn "wordmotion" }
	-- Codex completion
	use { "tom-doerr/vim_codex" }

	----------------------------------------------------------------------------------------------------
	-- Functionality
	----------------------------------------------------------------------------------------------------

	-- Startup screen
	use { "goolord/alpha-nvim", config = conf_module "alpha" }
	-- Language server / DAP installer
	use { "williamboman/mason.nvim", config = conf_setup "mason" }
	use { "williamboman/mason-lspconfig.nvim", config = conf_setup "mason-lspconfig", after = "mason.nvim" }
	-- Window Picker
	use { "s1n7ax/nvim-window-picker", tag = "v1.*", config = conf_setup "window-picker" }
	-- Filebrowser
	use { "nvim-neo-tree/neo-tree.nvim", branch = "main", config = conf_module "neo-tree" }
	-- Telescope fzf native
	use { "nvim-telescope/telescope-fzf-native.nvim", run = "make" }
	-- Anything Picker
	use {
		"nvim-telescope/telescope.nvim",
		config = conf_module "telescope",
		after = { "telescope-fzf-native.nvim", "nvim-notify" },
	}
	-- Git integration
	use "tpope/vim-fugitive"
	use "sindrets/diffview.nvim"
	-- FIXME: still broken and unusable
	--use { "TimUntersberger/neogit", config = conf_setup "neogit" }
	-- Undo tree
	use { "mbbill/undotree", config = conf_fn "undotree" }
	-- Gpg integration
	use "jamessan/vim-gnupg"

	----------------------------------------------------------------------------------------------------
	-- Completion
	----------------------------------------------------------------------------------------------------

	-- Completion engine
	use { "hrsh7th/nvim-cmp", config = conf_module "cmp" }
	-- Snippet engine
	use { "L3MON4D3/LuaSnip", after = "nvim-cmp" }
	-- Luasnip completion source
	use { "saadparwaiz1/cmp_luasnip", after = "LuaSnip" }
	-- Internal LSP completion source
	use { "hrsh7th/cmp-nvim-lsp", after = "cmp_luasnip" }
	-- Buffer words completion source
	use { "hrsh7th/cmp-buffer", after = "cmp_luasnip" }
	-- Cmdline completion source
	use { "hrsh7th/cmp-cmdline", after = "cmp_luasnip" }
	-- path completion source
	use { "hrsh7th/cmp-path", after = "cmp_luasnip" }
	-- emoji completion source
	use { "hrsh7th/cmp-emoji", after = "cmp_luasnip" }
	-- Shows function signatures on hover
	use "ray-x/lsp_signature.nvim"

	----------------------------------------------------------------------------------------------------
	-- Miscellaneous
	----------------------------------------------------------------------------------------------------

	use { "folke/trouble.nvim", config = conf_setup "trouble" }
	use { "folke/todo-comments.nvim", config = conf_setup "todo-comments" }
	use { "liuchengxu/vista.vim", cmd = "Vista" }

	-- Automatically sync after installing for the first time
	if packer_bootstrap then
		packer.sync()
	end
end)
