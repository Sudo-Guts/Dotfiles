# Cargador principal. La ruta real funciona también desde ~/.zshrc.
export DOTFILES="${${(%):-%x}:A:h:h:h}"

setopt PROMPT_SUBST
unsetopt FLOW_CONTROL

for module in \
    env history plugins \
    functions/utils functions/git functions/github functions/fpga \
    aliases keybindings prompt/git prompt/prompt
do
    source "$DOTFILES/config/zsh/$module.zsh"
done
unset module

# ============================================================
# Syntax Highlighting
# ============================================================

# zsh-syntax-highlighting debe cargarse al final para evitar
# conflictos con widgets definidos previamente.

SYNTAX_HIGHLIGHT_FILE="${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

if [[ -r "$SYNTAX_HIGHLIGHT_FILE" ]] &&
   [[ -z "${ZSH_HIGHLIGHT_VERSION:-}" ]]; then

    source "$SYNTAX_HIGHLIGHT_FILE"

fi

unset SYNTAX_HIGHLIGHT_FILE


# ============================================================
# Initial Prompt State
# ============================================================

# Actualiza las variables del prompt inmediatamente, también
# cuando ~/.zshrc se recarga manualmente.
dotfiles_precmd
