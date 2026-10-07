# ============================================================
# History
# ============================================================

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"

[[ -d "${HISTFILE:h}" ]] || mkdir -p -- "${HISTFILE:h}"

HISTSIZE=20000
SAVEHIST=20000

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt INTERACTIVE_COMMENTS
