-- TODO: lspconfig keymappings
-- TODO: a<Tab> inserts literal tab instead of completing when in a word with characters ahead
-- TODO: some way to search fuzzy in completion window
-- TODO: completion should be repeatable with .
local cmp = require "cmp"
if cmp == nil then
	return
end

local icons = require("utils.icons").lspkind
local luasnip = require "luasnip"
local compare = cmp.config.compare

-- Show completion menu also if only one item is available (for context)
vim.opt.completeopt = { "menu", "menuone", "preview" }

local has_words_before = function()
	local line, col = table.unpack(vim.api.nvim_win_get_cursor(0))
	return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s" == nil
end

cmp.setup {
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	formatting = {
		format = function(_, vim_item)
			vim_item.kind = string.format("%s %s", icons[vim_item.kind], vim_item.kind)
			return vim_item
		end,
	},
	mapping = cmp.mapping.preset.insert {
		["<C-y>"] = cmp.config.disable,
		["<C-d>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.close(),
		["<CR>"] = cmp.mapping.confirm {
			behavior = cmp.ConfirmBehavior.Replace,
			select = false,
		},
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif luasnip.expand_or_jumpable() then
				luasnip.expand_or_jump()
			elseif has_words_before() then
				cmp.complete()
			else
				fallback()
			end
		end, { "i", "s", "c" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			elseif luasnip.jumpable(-1) then
				luasnip.jump(-1)
			else
				fallback()
			end
		end, { "i", "s", "c" }),
	},
	sorting = {
		priority_weight = 2,
		comparators = {
			compare.locality,
			compare.recently_used,
			compare.offset,
			compare.exact,
			-- compare.scopes,
			compare.score,
			compare.kind,
			compare.sort_text,
			compare.length,
			compare.order,
		},
	},
	sources = cmp.config.sources({
		{ name = "path", priority_weight = 105 },
		{ name = "luasnip", priority_weight = 103 },
		{ name = "nvim_lsp", priority_weight = 100 },
		{ name = "nvim_lsp_signature_help", priority_weight = 99 },
		{ name = "nvim_lua", priority_weight = 60 },
		{ name = "buffer", priority_weight = 50 },
		{ name = "emoji", priority_weight = 50 },
	}, {
		{ name = "buffer", priority_weight = 50 },
	}),
}

cmp.setup.cmdline(":", {
	sources = {
		{ name = "cmdline" },
	},
})
