-- ============================================================
--  init.lua  –  Neovim config for:
--  Python · C/C++ · Rust · Go · Java · JS · Docker · Markdown · RST
--  ROS2 · GStreamer · YOLO · AI/ML · Arduino · ESP32 · STM32
--  PostgreSQL · Reverse Engineering · Security · Cryptography
--  HTML · CSS · XML · JSON · YAML · CMake · ASM · YARA · Sage
-- ============================================================

-- Leader key MUST be set before lazy.nvim loads
vim.g.mapleader      = " "
vim.g.maplocalleader = "\\"

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("options")
require("keymaps")
require("reverse")
require("workflows")

-- Load all files in lua/plugins/ automatically
require("lazy").setup("plugins", {
  change_detection = { notify = false },
  rocks = { enabled = false },
  ui = { border = "rounded" },
})
