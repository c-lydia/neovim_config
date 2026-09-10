# Neon-blue prompt matching the GNOME and Neovim active-window highlight.
# Line one shows identity, location, Git state, and the active Python venv.
# Line two stays deliberately short so commands remain easy to scan.

ZSH_THEME_GIT_PROMPT_PREFIX="%F{#6c7086}git:(%F{#04d9ff}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%F{#6c7086})%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{#ffd700} ✗%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{#39ff14} ✓%f"

ZSH_THEME_VIRTUALENV_PREFIX="%F{#6c7086}venv:(%F{#04d9ff}"
ZSH_THEME_VIRTUALENV_SUFFIX="%F{#6c7086})%f "

PROMPT='%(?..%F{#ff3366}%? ↵%f )%F{#04d9ff}%n@%m%f %F{#cdd6f4}%~%f $(git_prompt_info)$(virtualenv_prompt_info)
%F{#04d9ff}❯%f '

RPROMPT='%F{#04d9ff}%D{%H:%M}%f'
