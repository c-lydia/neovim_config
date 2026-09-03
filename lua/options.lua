local opt = vim.opt

-- ── Numbers ──────────────────────────────────────────────────
opt.number         = true
opt.relativenumber = true

-- ── Tabs & indent ─────────────────────────────────────────────
opt.tabstop     = 2        -- visual width of a tab character
opt.shiftwidth  = 2        -- indent step
opt.expandtab   = true     -- spaces instead of tabs
opt.smartindent = true
opt.autoindent  = true

-- ── Lines & columns ───────────────────────────────────────────
opt.wrap        = false
opt.cursorline  = true
opt.scrolloff   = 8
opt.sidescrolloff = 8
opt.colorcolumn = "120"    -- vertical ruler at 120 chars
opt.signcolumn  = "yes"    -- always show gutter (prevents layout shift)

-- ── Search ────────────────────────────────────────────────────
opt.ignorecase  = true
opt.smartcase   = true     -- case-sensitive when query has uppercase
opt.hlsearch    = false
opt.incsearch   = true

-- ── Appearance ────────────────────────────────────────────────
opt.termguicolors = true
opt.showmode      = false  -- lualine shows the mode instead
opt.pumheight     = 10     -- max completion menu height

-- ── Splits ────────────────────────────────────────────────────
opt.splitright = true
opt.splitbelow = true

-- ── Performance ───────────────────────────────────────────────
opt.updatetime  = 50
opt.timeoutlen  = 300

-- ── Clipboard ─────────────────────────────────────────────────
opt.clipboard = "unnamedplus"

-- ── Persistence ───────────────────────────────────────────────
opt.undofile = true
opt.undodir  = vim.fn.stdpath("data") .. "/undo"
opt.swapfile = false
opt.backup   = false

-- ── Completion ────────────────────────────────────────────────
opt.completeopt = "menu,menuone,noselect"

-- ── Per-filetype overrides ────────────────────────────────────
local ft_indent = vim.api.nvim_create_augroup("FtIndent", { clear = true })

-- 4-space indent: Python, C, C++, Java, Arduino, embedded
vim.api.nvim_create_autocmd("FileType", {
  group   = ft_indent,
  pattern = { "python", "c", "cpp", "java", "arduino", "cmake" },
  callback = function()
    vim.opt_local.tabstop    = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- Treat .ino / .pde (Arduino) as C++
vim.filetype.add({
  extension = {
    ino = "cpp",
    pde = "cpp",
  },
})

-- ROS2 interface files – basic highlighting via rst/yaml fallback
vim.filetype.add({
  extension = {
    msg    = "rosidl",
    srv    = "rosidl",
    action = "rosidl",
  },
})

-- Reverse engineering, security rules, and cryptography notebooks.
vim.filetype.add({
  extension = {
    yar  = "yar",
    yara = "yara",
    sage = "sage",
  },
})

-- Docker Compose variants
vim.filetype.add({
  filename = {
    ["docker-compose.yml"]          = "yaml.docker-compose",
    ["docker-compose.yaml"]         = "yaml.docker-compose",
    ["docker-compose.override.yml"] = "yaml.docker-compose",
  },
})

-- Make the active editor split obvious. This mirrors the desktop focus ring
-- configured for GNOME, so focus is visible at both levels.
local focus_group = vim.api.nvim_create_augroup("ActiveWindowHighlight", { clear = true })

local function define_focus_highlights()
  vim.api.nvim_set_hl(0, "ActiveWindowSeparator", { fg = "#04d9ff", bold = true })
  vim.api.nvim_set_hl(0, "InactiveWindowSeparator", { fg = "#45475a" })
  vim.api.nvim_set_hl(0, "NormalNC", { bg = "#181825" })
end

local function refresh_window_highlights()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
      local active = win == current
      vim.wo[win].cursorline = active
      vim.wo[win].winhighlight = active
          and "WinSeparator:ActiveWindowSeparator"
        or "Normal:NormalNC,WinSeparator:InactiveWindowSeparator,CursorLine:NormalNC"
    end
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = focus_group,
  callback = function()
    define_focus_highlights()
    vim.schedule(refresh_window_highlights)
  end,
})

vim.api.nvim_create_autocmd({ "VimEnter", "WinEnter", "WinLeave", "BufWinEnter" }, {
  group = focus_group,
  callback = function() vim.schedule(refresh_window_highlights) end,
})

define_focus_highlights()
