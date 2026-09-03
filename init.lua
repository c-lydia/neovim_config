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

if vim.fn.has("nvim-0.11.3") == 0 then
  local version = vim.version()
  error((
    "This configuration requires Neovim 0.11.3 or newer (found %d.%d.%d)"
  ):format(version.major, version.minor, version.patch))
end

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
  local clone_output = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Could not install lazy.nvim:\n" .. clone_output)
  end
end
vim.opt.rtp:prepend(lazypath)

require("options")
require("keymaps")
require("reverse")
require("workflows")

-- Load all files in lua/plugins/ automatically
require("lazy").setup("plugins", {
  change_detection = { notify = false },
  -- Avoid exhausting DNS/network resources when bootstrapping the full stack.
  concurrency = 4,
  lockfile = vim.fn.stdpath("config")
    .. (vim.fn.has("nvim-0.12") == 1 and "/lazy-lock-0.12.json" or "/lazy-lock.json"),
  rocks = { enabled = false },
  ui = { border = "rounded" },
})
