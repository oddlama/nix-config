local opt = vim.opt
local g = vim.g

g.mapleader = ","

----------------------------------------------------------------------------------------------------
-- General
----------------------------------------------------------------------------------------------------

opt.undolevels = 1000000 -- Set maximum undo levels
opt.undofile = true -- Enable persistent undo which persists undo history across vim sessions
opt.updatetime = 300 -- Save swap file after 300ms
opt.mouse = "a" -- Enable full mouse support

----------------------------------------------------------------------------------------------------
-- Editor visuals
----------------------------------------------------------------------------------------------------

opt.termguicolors = true -- Enable true color in terminals

-- FIXME: TODO: neovim after 0.8: enable this!
--opt.splitkeep = 'screen'                           -- Try not to move text when opening/closing splits
opt.wrap = false -- Do not wrap text longer than the window's width
opt.scrolloff = 2 -- Keep 2 lines above and below the cursor.
opt.sidescrolloff = 2 -- Keep 2 lines left and right of the cursor.

opt.number = true -- Show line numbers
opt.cursorline = true -- Enable cursorline, colorscheme only shows this in number column
opt.wildmode = { "list", "full" } -- Only complete the longest common prefix and list all results
opt.fillchars = { stlnc = "─" } -- Show separators in inactive window statuslines

-- FIXME: disabled because this really fucks everything up in the terminal.
opt.title = false -- Sets the window title
--opt.titlestring = "%t%( %M%)%( (%{expand(\"%:~:.:h\")})%) - nvim" -- The format for the window title

-- Hide line numbers in terminal windows
vim.api.nvim_exec([[au BufEnter term://* setlocal nonumber]], false)

----------------------------------------------------------------------------------------------------
-- Editing behavior
----------------------------------------------------------------------------------------------------

opt.whichwrap = "" -- Never let the curser switch to the next line when reaching line end
opt.ignorecase = true -- Ignore case in search by default
opt.smartcase = true -- Be case sensitive when an upper-case character is included

opt.expandtab = false
opt.tabstop = 4 -- Set indentation of tabs to be equal to 4 spaces.
opt.shiftwidth = 4
opt.softtabstop = 4
opt.shiftround = true -- Round indentation commands to next multiple of shiftwidth

opt.formatoptions = "rqj" -- r = insert comment leader when hitting <Enter> in insert mode
-- q = allow explicit formatting with gq
-- j = remove comment leaders when joining lines if it makes sense

opt.virtualedit = "all" -- Allow the curser to be positioned on cells that have no actual character;
-- Like moving beyond EOL or on any visual 'space' of a tab character
opt.selection = "old" -- Do not include line ends in past the-line selections
opt.smartindent = true -- Use smart auto indenting for all file types

opt.timeoutlen = 20 -- Only wait 20 milliseconds for characters to arrive (see :help timeout)
opt.ttimeoutlen = 20
opt.timeout = false -- Disable timeout, but enable ttimeout (only timeout on keycodes)
opt.ttimeout = true

opt.grepprg = "rg --vimgrep --smart-case --follow" -- Replace grep with ripgrep
