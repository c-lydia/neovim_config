local map = vim.keymap.set
local o   = { noremap = true, silent = true }

-- ── Windows ───────────────────────────────────────────────────
map("n", "<C-h>",     "<C-w>h",              o)
map("n", "<C-j>",     "<C-w>j",              o)
map("n", "<C-k>",     "<C-w>k",              o)
map("n", "<C-l>",     "<C-w>l",              o)
map("n", "<C-Up>",    ":resize +2<CR>",      o)
map("n", "<C-Down>",  ":resize -2<CR>",      o)
map("n", "<C-Left>",  ":vert resize -2<CR>", o)
map("n", "<C-Right>", ":vert resize +2<CR>", o)

-- ── Buffers ───────────────────────────────────────────────────
map("n", "<S-l>",      ":bnext<CR>",    o)
map("n", "<S-h>",      ":bprevious<CR>", o)
map("n", "<leader>bd", ":bdelete<CR>",  o)

-- ── Editing ───────────────────────────────────────────────────
map("v", "<",         "<gv",            o)   -- stay in visual after indent
map("v", ">",         ">gv",            o)
map("v", "J",         ":m .+1<CR>==",   o)   -- move line down
map("v", "K",         ":m .-2<CR>==",   o)   -- move line up
map("n", "J",         "mzJ`z",          o)   -- join without cursor jump
map("n", "<C-d>",     "<C-d>zz",        o)   -- keep cursor centred
map("n", "<C-u>",     "<C-u>zz",        o)
map("n", "n",         "nzzzv",          o)
map("n", "N",         "Nzzzv",          o)
map("x", "<leader>p", '"_dP',           o)   -- paste without clobbering register
map("n", "<leader>d", '"_d',            o)   -- delete without yanking
map("v", "<leader>d", '"_d',            o)
map("n", "<Esc>",     ":nohlsearch<CR>", o)

-- ── Save ──────────────────────────────────────────────────────
map("n", "<C-s>", ":w<CR>",      o)
map("i", "<C-s>", "<Esc>:w<CR>", o)

-- ── Format (conform.nvim) ─────────────────────────────────────
map("n", "<leader>cf", function() require("conform").format({ async = true }) end, o)

-- ── File tree ─────────────────────────────────────────────────
map("n", "<leader>e", ":Neotree toggle<CR>", o)

-- ── Telescope ─────────────────────────────────────────────────
map("n", "<leader>ff", ":Telescope find_files<CR>",                   o)
map("n", "<leader>fg", ":Telescope live_grep<CR>",                    o)
map("n", "<leader>fb", ":Telescope buffers<CR>",                      o)
map("n", "<leader>fr", ":Telescope oldfiles<CR>",                     o)
map("n", "<leader>fs", ":Telescope grep_string<CR>",                  o)
map("n", "<leader>fd", ":Telescope diagnostics<CR>",                  o)
map("n", "<leader>fk", ":Telescope keymaps<CR>",                      o)
map("n", "<leader>fc", ":Telescope git_commits<CR>",                  o)

-- ── Git ───────────────────────────────────────────────────────
map("n", "<leader>gg", ":LazyGit<CR>",                    o)
map("n", "<leader>gb", ":Gitsigns blame_line<CR>",         o)
map("n", "<leader>gd", ":Gitsigns diffthis<CR>",           o)
map("n", "]g",         ":Gitsigns next_hunk<CR>",          o)
map("n", "[g",         ":Gitsigns prev_hunk<CR>",          o)

-- ── Diagnostics / Trouble ─────────────────────────────────────
map("n", "<leader>xx", ":Trouble diagnostics toggle<CR>",            o)
map("n", "<leader>xd", ":Trouble diagnostics toggle filter.buf=0<CR>", o)
map("n", "<leader>xl", ":Trouble loclist toggle<CR>",                o)
map("n", "<leader>xq", ":Trouble qflist toggle<CR>",                 o)

-- ── Terminal ──────────────────────────────────────────────────
map("n", "<leader>t",  ":ToggleTerm<CR>", o)
map("t", "<Esc>",      "<C-\\><C-n>",     o)   -- exit terminal mode

-- ── Database (dadbod) ─────────────────────────────────────────
map("n", "<leader>db", ":DBUIToggle<CR>", o)

-- ── Search & Replace ──────────────────────────────────────────
map("n", "<leader>sr", function() require("spectre").open() end, o)

-- ── LSP (set in lsp.lua on LspAttach) ────────────────────────
-- gd · gD · gr · gi · K · <leader>rn · <leader>ca · [d · ]d
