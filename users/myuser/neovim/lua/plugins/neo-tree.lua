vim.cmd [[let g:neo_tree_remove_legacy_commands = 1]]
-- local notify = function(message, level)
-- 	vim.notify(message, level, { title = "NeoTree" })
-- end

require("neo-tree").setup {
	sort_case_insensitive = true,
	use_popups_for_input = false,
	popup_border_style = "rounded",
	-- source_selector = {
	-- 	winbar = true,
	-- 	separator = { left = "", right= "" },
	-- },
	win_options = {
		winblend = 0,
	},
	default_component_configs = {
		modified = {
			symbol = "~ ",
		},
		indent = {
			with_expanders = true,
		},
		name = {
			trailing_slash = true,
		},
		git_status = {
			symbols = {
				added = "+",
				deleted = "✖",
				modified = "",
				renamed = "➜",
				untracked = "?",
				ignored = "",
				unstaged = "",
				staged = "",
				conflict = "",
			},
		},
	},
	window = {
		width = 34,
		position = "left",
		mappings = {
			["<CR>"] = "open_with_window_picker",
			["s"] = "split_with_window_picker",
			["v"] = "vsplit_with_window_picker",
			["t"] = "open_tabnew",
			["z"] = "close_all_nodes",
			["Z"] = "expand_all_nodes",
			["a"] = { "add", config = { show_path = "relative" } },
			["A"] = { "add_directory", config = { show_path = "relative" } },
			["c"] = { "copy", config = { show_path = "relative" } },
			["m"] = { "move", config = { show_path = "relative" } },
		},
	},
	filesystem = {
		window = {
			mappings = {
				["gA"] = "git_add_all",
				["ga"] = "git_add_file",
				["gu"] = "git_unstage_file",
			},
		},
		group_empty_dirs = true,
		follow_current_file = {
			enabled = true,
		},
		use_libuv_file_watcher = true,
		filtered_items = {
			hide_dotfiles = false,
			hide_by_name = { ".git" },
		},
	},
	-- event_handlers = {
	-- 	{
	-- 		event = "file_added",
	-- 		handler = function(arg)
	-- 			notify("Added: " .. arg, "info")
	-- 		end,
	-- 	},
	-- 	{
	-- 		event = "file_deleted",
	-- 		handler = function(arg)
	-- 			notify("Deleted: " .. arg, "info")
	-- 		end,
	-- 	},
	-- 	{
	-- 		event = "file_renamed",
	-- 		handler = function(args)
	-- 			notify("Renamed: " .. args.source .. " -> " .. args.destination, "info")
	-- 		end,
	-- 	},
	-- 	{
	-- 		event = "file_moved",
	-- 		handler = function(args)
	-- 			notify("Moved: " .. args.source .. " -> " .. args.destination, "info")
	-- 		end,
	-- 	},
	-- },
}
