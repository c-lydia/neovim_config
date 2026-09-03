#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
install_mode='native'
install_method='link'

usage() {
  printf '%s\n' \
    'Usage: ./scripts/install.sh [--native | --flatpak | --both] [--link | --copy]' \
    '' \
    'Install this workbench as the Neovim configuration.' \
    '' \
    'Targets:' \
    '  --native    Install for a native Neovim (default)' \
    '  --flatpak   Install for io.neovim.nvim from Flathub' \
    '  --both      Install for native and Flatpak Neovim' \
    '' \
    'Methods:' \
    '  --link      Link both targets to this checkout (default)' \
    '  --copy      Copy this checkout into each target' \
    '' \
    'An existing target is never overwritten; move it aside before retrying.'
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --native)
      install_mode='native'
      ;;
    --flatpak)
      install_mode='flatpak'
      ;;
    --both)
      install_mode='both'
      ;;
    --link)
      install_method='link'
      ;;
    --copy)
      install_method='copy'
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'install.sh: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

install_home="${WORKBENCH_INSTALL_HOME:-$HOME}"
native_config="${XDG_CONFIG_HOME:-$install_home/.config}/nvim"
flatpak_config="$install_home/.var/app/io.neovim.nvim/config/nvim"

install_target() {
  local label=$1
  local target=$2

  if [[ -e $target || -L $target ]]; then
    if [[ $target -ef $repo_root ]]; then
      printf '%s configuration already uses this checkout: %s\n' "$label" "$target"
      return
    fi
    printf 'install.sh: refusing to overwrite existing %s configuration: %s\n' \
      "$label" "$target" >&2
    printf 'Move it aside, then run this command again.\n' >&2
    return 1
  fi

  mkdir -p "$(dirname -- "$target")"
  if [[ $install_method == 'copy' ]]; then
    cp -a "$repo_root" "$target"
  else
    ln -s "$repo_root" "$target"
  fi
  printf 'Installed %s configuration (%s): %s\n' "$label" "$install_method" "$target"
}

case $install_mode in
  native)
    install_target 'native Neovim' "$native_config"
    ;;
  flatpak)
    install_target 'Flatpak Neovim' "$flatpak_config"
    printf 'Start it with: flatpak run io.neovim.nvim\n'
    ;;
  both)
    install_target 'native Neovim' "$native_config"
    install_target 'Flatpak Neovim' "$flatpak_config"
    printf 'Start Flatpak Neovim with: flatpak run io.neovim.nvim\n'
    ;;
esac
