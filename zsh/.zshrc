# ============================================================
# Oh My Zsh
# ============================================================

export ZSH="$HOME/.oh-my-zsh"

ENABLE_CORRECTION="true"

plugins=(
    git
    zsh-interactive-cd
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

source "$ZSH/oh-my-zsh.sh"


# ============================================================
# Dotfiles
# ============================================================

DOTFILES="$HOME/.dotfiles"

source "$DOTFILES/zsh/git.zsh"
source "$DOTFILES/zsh/function.zsh"
source "$DOTFILES/zsh/aliases.zsh"


# ============================================================
# Environment
# ============================================================

# ------------------------------------------------------------
# RISC-V xPack Toolchain
# ------------------------------------------------------------

export PATH="$HOME/.local/xPacks/@xpack-dev-tools/riscv-none-elf-gcc/latest/bin:$PATH"

# ------------------------------------------------------------
# RISC-V
# ------------------------------------------------------------

export RISCV="/opt/riscv"
export PATH="$RISCV/bin:$PATH"

# ============================================================
# Kitty
# ============================================================

export PATH="$HOME/.local/kitty.app/bin:$PATH"

# ============================================================
# Prompt
# ============================================================

setopt prompt_subst

PR_HBAR="-"

PROMPT='$(LH)\
%F{magenta}[%f $(ghost_icon) %F{magenta}]%f\
%F{magenta}[%f %F{cyan}%/%f %F{magenta}]%f\
$(BAR)\
%F{magenta}[%f %F{cyan}%n%f %F{magenta}]%f$(RH)\

$(LL)$(arrow)'


# ============================================================
# Right Prompt
# ============================================================

RPROMPT='%F{magenta}[%f $(GITIF)$(git_prompt_info) $(git_ahead_behind)$(git_stash_count)$(git_prompt_status) %F{magenta}]%f$(RL)'
