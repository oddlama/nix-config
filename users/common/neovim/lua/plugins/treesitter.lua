require("nvim-treesitter.configs").setup {
	ensure_installed = "all",
	highlight = {
		enable = true,
		use_languagetree = true,
	},
	rainbow = {
		enable = true,
		extended_mode = true,
		--	colors = { },
		--	termcolors = { }
	},
	matchup = {
		enable = true,
	},
}
