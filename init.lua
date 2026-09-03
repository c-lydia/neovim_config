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

local lockfile = vim.fn.stdpath("config")
  .. (vim.fn.has("nvim-0.12") == 1 and "/lazy-lock-0.12.json" or "/lazy-lock.json")

local function locked_lazy_commit()
  local ok, contents = pcall(vim.fn.readfile, lockfile)
  if not ok then return nil end
  local decoded_ok, lock = pcall(vim.json.decode, table.concat(contents, "\n"))
  if not decoded_ok or type(lock) ~= "table" then return nil end
  return lock["lazy.nvim"] and lock["lazy.nvim"].commit or nil
end

-- Bootstrap lazy.nvim at the published revision. Without the checkout, a fresh
-- install can rewrite the lockfile to whatever the stable branch points at.
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

  local commit = locked_lazy_commit()
  if commit then
    local checkout_output = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", commit })
    if vim.v.shell_error ~= 0 then
      error("Could not select the locked lazy.nvim revision:\n" .. checkout_output)
    end
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
  lockfile = lockfile,
  rocks = { enabled = false },
  ui = { border = "rounded" },
})
