local function button(shortcut, txt, keybind, keybind_opts)
	local opts = {
		position = "center",
		shortcut = shortcut,
		cursor = 5,
		width = 50,
		align_shortcut = "right",
		hl_shortcut = "Keyword",
	}

	if keybind then
		keybind_opts = vim.F.if_nil(keybind_opts, { noremap = true, silent = true })
		opts.keymap = { "n", shortcut, keybind, keybind_opts }
	end

	local function on_press()
		local key = vim.api.nvim_replace_termcodes(shortcut .. "<Ignore>", true, false, true)
		vim.api.nvim_feedkeys(key, "normal", false)
	end

	return {
		type = "button",
		val = txt,
		on_press = on_press,
		opts = opts,
	}
end

local function buttons(xs, spacing)
	return {
		type = "group",
		val = xs,
		opts = { spacing = vim.F.if_nil(spacing, 1) },
	}
end

local function text(value, hl)
	return {
		type = "text",
		val = value,
		opts = {
			position = "center",
			hl = hl,
		},
	}
end

local function pad(lines)
	return { type = "padding", val = lines }
end

local header = {
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣴⣶⣶⠀⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⢸⣄⠀⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⠛⠀⠀⠹⣧⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⢠⠀⡄⠀⣿⠀⢀⣤⣤⠀⠀",
	"⠀⠀⠀⠀⠀⠀⠀⠀⢰⡏⠚⠀⠃⠀⣿⣴⠞⠉⢹⠀⠀",
	"⠀⣀⡀⠀⠀⠀⠀⢀⣸⠇⠀⠀⠀⠀⠈⠀⠀⣀⡿⠀⠀",
	"⢸⣟⠛⢳⣤⣤⡶⠛⠃⠀⣠⠀⠀⠀⠚⣶⡾⠟⠀⠀⠀",
	"⠀⠉⢷⣤⣀⣀⣀⣀⣠⡾⠻⣧⡀⠀⠀⢘⣷⣄⣀⣤⣄",
	"⠀⠀⠀⠈⠉⠉⠉⠉⠉⠀⠀⠘⠻⣦⣤⣈⣁⣀⣠⣾⠋",
	"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠉⠉⠀⠀",
}

require("alpha").setup {
	layout = {
		pad(2),
		text(header, "Type"),
		--pad(2), text(separator, 'Number'),
		pad(2),
		buttons {
			button("e", "  New file", ":enew<CR>"),
			--button("f", "  Find file",      ":Telescope find_files<CR>"),
			--button("w", "  Find word",      ":Telescope grep_string<CR>"),
		},
		pad(2),
		buttons {
			button("u", "  Update plugins", ":PackerSync<CR>"),
			button("h", "  Check health", ":checkhealth<CR>"),
			button("q", "  Quit", ":qa<CR>"),
		},
		--text(separator, 'Number'),
	},
	opts = { margin = 5 },
}
