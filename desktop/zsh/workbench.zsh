# Terminal counterparts to the workflows in ~/.config/nvim/lua/workflows.lua.

alias v='nvim'
alias vi='nvim'
alias vim='nvim'
alias nws='nvim-workspace'
alias cmake-presets='cmake --list-presets'
alias cmake-build-presets='cmake --build --list-presets'
alias ctest-presets='ctest --list-presets'

function venv-create() {
  emulate -L zsh
  local name="${1:-.venv}"

  if [[ ! "$name" =~ '^([A-Za-z0-9]|\.)[A-Za-z0-9._-]*$' ]]; then
    print -u2 -- "venv-create: use letters, numbers, '.', '_' or '-'"
    return 2
  fi
  if [[ -e "$name" ]]; then
    print -u2 -- "venv-create: '$name' already exists"
    return 2
  fi

  python3 -m venv --prompt "$name" "$name" || return
  source "./$name/bin/activate"
}

function venv-use() {
  emulate -L zsh
  local name="${1:-.venv}"
  local activate="$name/bin/activate"

  if [[ ! -f "$activate" ]]; then
    print -u2 -- "venv-use: '$name' is not a Python environment"
    return 2
  fi
  source "$activate"
}

function docker-build-name() {
  emulate -L zsh
  if (( $# != 1 )); then
    print -u2 -- "usage: docker-build-name IMAGE:TAG"
    return 2
  fi
  docker build --tag "$1" .
}

function compose-up-name() {
  emulate -L zsh
  local project="${1:-${PWD:t:l}}"
  project="${project//[^a-z0-9_-]/-}"
  docker compose --project-name "$project" up --build
}

function compose-down-name() {
  emulate -L zsh
  local project="${1:-${PWD:t:l}}"
  project="${project//[^a-z0-9_-]/-}"
  docker compose --project-name "$project" down
}
