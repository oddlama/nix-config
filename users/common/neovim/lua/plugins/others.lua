local configs = {
	["dressing"] = {
		input = {
			prefer_width = 80,
			max_width = { 140, 0.9 },
			min_width = { 80, 0.6 },
			win_options = {
				winblend = 0,
			},
		},
	},
	["null-ls"] = function()
		local null_ls = require "null-ls"
		null_ls.setup {
			sources = {
				null_ls.builtins.code_actions.shellcheck,
				null_ls.builtins.formatting.stylua,
				--null_ls.builtins.diagnostics.eslint,
				null_ls.builtins.completion.spell,
			},
		}
	end,
	["lualine"] = function()
		local c = require "onedark.colors"
		local theme = {
			inactive = {
				a = { fg = c.fg, bg = c.bg2, gui = "bold" },
				b = { fg = c.fg, bg = c.bg2 },
				c = { fg = c.bg2, bg = c.bg0 },
			},
			normal = {
				a = { fg = c.bg0, bg = c.green, gui = "bold" },
				b = { fg = c.fg, bg = c.bg2 },
				c = { fg = c.fg, bg = c.bg0 },
			},
			visual = { a = { fg = c.bg0, bg = c.purple, gui = "bold" } },
			replace = { a = { fg = c.bg0, bg = c.red, gui = "bold" } },
			insert = { a = { fg = c.bg0, bg = c.blue, gui = "bold" } },
			command = { a = { fg = c.bg0, bg = c.yellow, gui = "bold" } },
			terminal = { a = { fg = c.bg0, bg = c.cyan, gui = "bold" } },
		}

		require("lualine").setup {
			options = {
				theme = theme,
				component_separators = "",
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_a = { "mode" },
				lualine_b = { "branch", "filename" },
				lualine_c = { "diff", "diagnostics" },
				lualine_x = { "encoding", "fileformat", "filetype" },
				lualine_y = { "progress" },
				lualine_z = { "location" },
			},
			inactive_sections = {
				lualine_a = { "filename" },
				lualine_b = {},
				lualine_c = { "diagnostics" },
				lualine_x = {},
				lualine_y = {},
				lualine_z = { "location" },
			},
			extensions = { "quickfix", "fugitive", "fzf", "nvim-dap-ui", "neo-tree" },
		}
	end,
	["neogit"] = {
		disable_builtin_notifications = true,
	},
	["window-picker"] = {
		selection_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
		filter_rules = {
			bo = {
				filetype = { "neo-tree", "neo-tree-popup", "notify", "quickfix" },
				buftype = { "terminal", "quickfix", "prompt" },
			},
		},
		other_win_hl_color = "#4493c8",
	},
	["gomove"] = {
		map_defaults = false,
		undojoin = true,
		move_past_end_col = true,
	},
	["better-whitespace"] = function()
		function _G.whitespace_visibility()
			pcall(function()
				if vim.bo.buftype == "nofile" or vim.bo.buftype == "help" then
					vim.cmd "DisableWhitespace"
				else
					vim.cmd "EnableWhitespace"
				end
			end)
		end

		vim.cmd [[autocmd WinEnter * lua whitespace_visibility()]]
	end,
	["onedark"] = function()
		local onedark = require "onedark"
		onedark.setup {
			toggle_style_key = "<nop>",
			colors = {
				fg = "#abb2bf",
				black = "#181a1f",
				bg0 = "#1e222a",
				bg1 = "#252931",
				bg2 = "#282c34",
				bg3 = "#353b45",
				bg_d = "#191c21",
				bg_blue = "#73b8f1",
				bg_yellow = "#ebd09c",

				dark_cyan = "#2b6f77",
				dark_red = "#993939",
				dark_yellow = "#93691d",

				grey = "#42464e",
				grey_fg = "#565c64",
				grey_fg2 = "#6f737b",
				light_grey = "#6f737b",
				baby_pink = "#de8c92",
				pink = "#ff75a0",
				nord_blue = "#81a1c1",
				sun = "#ebcb8b",
				light_purple = "#de98fd",
				dark_purple = "#c882e7",
				teal = "#519aba",
				dark_pink = "#fca2aa",
				light_blue = "#a3b8ef",
				vibrant_green = "#7eca9c",

				red = "#e06c75",
				orange = "#d19a66",
				yellow = "#e5c07b",
				green = "#98c379",
				cyan = "#56b6c2",
				blue = "#61afef",
				purple = "#c678dd",

				diff_add = "#31392b",
				diff_delete = "#382b2c",
				diff_change = "#1c3448",
				diff_text = "#2c5372",
			},
			highlights = {
				CursorLine = { bg = "$bg0" },
				FloatBorder = { fg = "$blue" },
				NeoTreeTabActive = { fg = "$fg", bg = "$bg_d" },
				NeoTreeTabInactive = { fg = "$grey", bg = "$black" },
				NeoTreeTabSeparatorActive = { fg = "$black", bg = "$black" },
				NeoTreeTabSeparatorInactive = { fg = "$black", bg = "$black" },
				NeoTreeWinSeparator = { fg = "$bg_d", bg = "$bg_d" },
				NeoTreeVertSplit = { fg = "$bg_d", bg = "$bg_d" },
				VisualMultiMono = { fg = "$purple", bg = "$diff_change" },
				VisualMultiExtend = { bg = "$diff_change" },
				VisualMultiCursor = { fg = "$purple", bg = "$diff_change" },
				VisualMultiInsert = { fg = "$blue", bg = "$diff_change" },
			},
		}
		vim.g.VM_Mono_hl = "VisualMultiMono"
		vim.g.VM_Extend_hl = "VisualMultiExtend"
		vim.g.VM_Cursor_hl = "VisualMultiCursor"
		vim.g.VM_Insert_hl = "VisualMultiInsert"
		onedark.load()
	end,
	["sandwich"] = function()
		vim.g.operator_sandwich_no_default_key_mappings = 1
		vim.g.textobj_sandwich_no_default_key_mappings = 1
	end,
	["undotree"] = function()
		vim.g.undotree_SetFocusWhenToggle = 1
		vim.g.undotree_WindowLayout = 4
	end,
	["wordmotion"] = function()
		vim.g.wordmotion_nomap = 1
	end,
	["nvim-web-devicons"] = function()
		local devicons = require "nvim-web-devicons"
		devicons.setup {
			override = require("utils.icons").devicons,
			default = true,
		}
	end,
	["notify"] = function()
		local notify = require "notify"
		notify.setup {
			fps = 60,
			icons = {
				DEBUG = "",
				ERROR = "",
				INFO = "",
				TRACE = "✎",
				WARN = "",
			},
			max_width = 120,
		}
		vim.notify = notify
	end,
	["nabla"] = function()
		require("nabla").enable_virt()
	end,
}

return configs
