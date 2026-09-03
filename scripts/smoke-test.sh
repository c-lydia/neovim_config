#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
nvim_command="${NVIM_BIN:-nvim}"
nvim_path="$(command -v -- "$nvim_command")"
test_root="$(mktemp -d /tmp/neovim-rc-smoke.XXXXXX)"

cleanup() {
  if [[ "$test_root" == /tmp/neovim-rc-smoke.* ]]; then
    rm -rf -- "$test_root"
  fi
}
trap cleanup EXIT

mkdir -p "$test_root/home" "$test_root/venv/bin"
WORKBENCH_INSTALL_HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
  "$repo_root/scripts/install.sh" --both --copy >/dev/null
[[ -d "$test_root/config/nvim" && ! -L "$test_root/config/nvim" ]]
[[ -d "$test_root/home/.var/app/io.neovim.nvim/config/nvim" ]]
ln -s "$nvim_path" "$test_root/venv/bin/python"

XDG_CONFIG_HOME="$test_root/config" \
NVIM_SKIP_TOOL_INSTALL=1 \
NVIM_RC_ROOT="$repo_root" \
RC_TEST_BASE_PATH="$PATH" \
RC_TEST_VENV="$test_root/venv" \
VIRTUAL_ENV="$test_root/venv" \
PATH="$test_root/venv/bin:$PATH" \
"$nvim_path" --headless -i NONE -n \
  --cmd 'lua _G.RC_SMOKE_ERRORS = {}; local original_notify = vim.notify; vim.notify = function(msg, level, opts) if level == vim.log.levels.ERROR then table.insert(_G.RC_SMOKE_ERRORS, tostring(msg)) end; return original_notify(msg, level, opts) end' \
  '+lua dofile(vim.env.NVIM_RC_ROOT .. "/tests/smoke.lua")'
