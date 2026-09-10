# Loaded only by the workbench shell, after the user's own Zsh configuration.
typeset -g workbench_home="${WORKBENCH_INSTALL_HOME:-$HOME}"
if [[ -r "$workbench_home/.zshrc" ]]; then
  source "$workbench_home/.zshrc"
fi

typeset -g workbench_data="${XDG_DATA_HOME:-$HOME/.local/share}/nvim-workbench"
if (( ! $+functions[git_prompt_info] )); then
  export ZSH="$workbench_data/oh-my-zsh"
  ZSH_CACHE_DIR="$workbench_data/cache"
  mkdir -p "$ZSH_CACHE_DIR"
  ZSH_THEME=''
  plugins=(git docker docker-compose python pip virtualenv fzf systemd sudo colored-man-pages extract command-not-found z)
  zstyle ':omz:update' mode disabled
  source "$ZSH/oh-my-zsh.sh"
fi

setopt prompt_subst
source "$workbench_data/zsh/neon-workbench.zsh-theme"
source "$workbench_data/zsh/workbench.zsh"
typeset -U path
path=("$workbench_home/.local/bin" $path)
