-- TODO: files and content in the searchable area should be split into two window portions,
-- TODO: Ctrl+Up in telescope fucks up spacing
-- or maybe only that the file just takes small amount of space

local telescope = require "telescope"

telescope.setup {
	defaults = {
		-- Default configuration for telescope goes here:
		-- config_key = value,
		mappings = {
			i = {
				["<C-h>"] = "which_key",
				["<C-Down>"] = require("telescope.actions").cycle_history_next,
				["<C-Up>"] = require("telescope.actions").cycle_history_prev,
			},
		},
		prompt_prefix = " ",
		selection_caret = " ",
	},
}

local function load_ext(ext)
	local ok, _ = pcall(telescope.load_extension, ext)
	if not ok then
		vim.notify("Could not load telescope extension: " .. ext, "error")
	end
end

load_ext "fzf"
load_ext "notify"
