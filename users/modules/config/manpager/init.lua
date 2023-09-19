vim.opt.buftype = "nowrite"
vim.opt.backup = false
vim.opt.modeline = false
vim.opt.shelltemp = false
vim.opt.swapfile = false
vim.opt.undofile = false
vim.opt.writebackup = false
vim.opt.shadafile = vim.fn.stdpath "state" .. "/shada/man.shada"
vim.opt.virtualedit = "all"
vim.opt.splitkeep = "screen"
-- Make sure to use ANSI colors
vim.opt.termguicolors = false

vim.keymap.set("n", "<CR>", "<C-]>", { silent = true, desc = "Jump to tag under cursor" })
vim.keymap.set("n", "<BS>", ":pop<CR>", { silent = true, desc = "Jump to previous tag in stack" })
vim.keymap.set("n", "<C-Left>", ":pop<CR>", { silent = true, desc = "Jump to previous tag in stack" })
vim.keymap.set("n", "<C-Right>", ":tag<CR>", { silent = true, desc = "Jump to next tag in stack" })
