local default_opts = { noremap = true, silent = true }
local function map(mode, lhs, rhs, opts)
	for c in mode:gmatch "." do
		vim.api.nvim_set_keymap(c, lhs, rhs, opts or default_opts)
	end
end

----------------------------------------------------------------------------------------------------
-- General
----------------------------------------------------------------------------------------------------

-- Shift + <up/down> scroll with cursor locked to position
map("", "<S-Down>", "")
map("", "<S-Up>", "")
map("i", "<S-Down>", "a")
map("i", "<S-Up>", "a")

-- Shift + Alt + <arrow keys> change the current window size
map("n", "<M-S-Up>", ":resize -2<CR>")
map("n", "<M-S-Down>", ":resize +2<CR>")
map("n", "<M-S-Left>", ":vertical resize -2<CR>")
map("n", "<M-S-Right>", ":vertical resize +2<CR>")

-- Allow exiting terminal mode
map("t", "<C-w><Esc>", "<C-\\><C-n>")
-- Allow C-w in terminal mode
map("t", "<C-w>", "<C-\\><C-n><C-w>")

-- Open fixed size terminal window at the bottom
map("n", "<leader><CR>", ":belowright new | setlocal wfh | resize 10 | terminal<CR>")

----------------------------------------------------------------------------------------------------
-- Language server
----------------------------------------------------------------------------------------------------

map("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>")
map("n", "gd", "<cmd>lua require('telescope.builtin').lsp_definitions()<CR>")
map("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>")
map("n", "gi", "<cmd>lua require('telescope.builtin').lsp_implementations()<CR>")
map("n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>")
map("n", "<leader>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>")
map("n", "<leader>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>")
map("n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>")
map("n", "gt", "<cmd>lua require('telescope.builtin').lsp_type_definitions()<CR>")
map("n", "<leader>r", "<cmd>lua vim.lsp.buf.rename()<CR>")
map("n", "<leader>a", "<cmd>lua vim.lsp.buf.code_action()<CR>")
map("n", "gr", "<cmd>lua require('telescope.builtin').lsp_references()<CR>")
map("n", "gl", "<cmd>lua vim.diagnostic.open_float()<CR>")
map("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
map("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>")
map("n", "<leader>q", "<cmd>lua vim.diagnostic.setloclist()<CR>")
map("n", "<leader>f", "<cmd>lua vim.lsp.buf.format { async = true }<CR>")

----------------------------------------------------------------------------------------------------
-- Plugin: Easy Align
----------------------------------------------------------------------------------------------------

map("n", "<leader>A", "<Plug>(EasyAlign)")
map("v", "<leader>A", "<Plug>(EasyAlign)")

----------------------------------------------------------------------------------------------------
-- Plugin: Undotree
--[[ ----------------------------------------------------------------------------------------------------
]]
map("n", "<leader>u", ":UndotreeToggle<CR>")

----------------------------------------------------------------------------------------------------
-- Plugin: Better Whitespace
----------------------------------------------------------------------------------------------------

map("n", "<leader>$", ":StripWhitespace<CR>")

----------------------------------------------------------------------------------------------------
-- Plugin: Neotree
----------------------------------------------------------------------------------------------------

-- Mappings to open the tree / find the current file
map("n", "<leader>t", ":Neotree toggle<CR>")
map("n", "<leader>T", ":Neotree reveal<CR>")
map("n", "<leader>G", ":Neotree float git_status<CR>")
map("n", "<leader>b", ":Neotree float buffers<CR>")

----------------------------------------------------------------------------------------------------
-- Plugin: Sandwich
----------------------------------------------------------------------------------------------------

map("nv", "m", "<Plug>(operator-sandwich-add)")
map("nv", "M", "<Plug>(operator-sandwich-delete)")
map("nv", "C-m", "<Plug>(operator-sandwich-replace)")

----------------------------------------------------------------------------------------------------
-- Plugin: gomove
----------------------------------------------------------------------------------------------------

--map("n", "<M-Left>",  "<Plug>GoNSMLeft")
--map("n", "<M-Down>",  "<Plug>GoNSMDown")
--map("n", "<M-Up>",    "<Plug>GoNSMUp")
--map("n", "<M-Right>", "<Plug>GoNSMRight")

map("x", "<M-Left>", "<Plug>GoVSMLeft")
map("x", "<M-Down>", "<Plug>GoVSMDown")
map("x", "<M-Up>", "<Plug>GoVSMUp")
map("x", "<M-Right>", "<Plug>GoVSMRight")

--map("n", "<S-M-Left>",  "<Plug>GoNSDLeft")
--map("n", "<S-M-Down>",  "<Plug>GoNSDDown")
--map("n", "<S-M-Up>",    "<Plug>GoNSDUp")
--map("n", "<S-M-Right>", "<Plug>GoNSDRight")

map("x", "<S-M-Left>", "<Plug>GoVSDLeft")
map("x", "<S-M-Down>", "<Plug>GoVSDDown")
map("x", "<S-M-Up>", "<Plug>GoVSDUp")
map("x", "<S-M-Right>", "<Plug>GoVSDRight")

----------------------------------------------------------------------------------------------------
-- Plugin: wordmotion
----------------------------------------------------------------------------------------------------

map("xo", "ie", "<Plug>WordMotion_iw")

----------------------------------------------------------------------------------------------------
-- Plugin: textcase
----------------------------------------------------------------------------------------------------

-- TODO: ... keybinds + telescope integration
