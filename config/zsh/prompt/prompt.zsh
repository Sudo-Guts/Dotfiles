# ============================================================
# Prompt
# ============================================================

function dotfiles_precmd() {
    local tint="red"
    local ghost="󱙜"
    local label="$PWD"
    local width="${COLUMNS:-80}"

    # --------------------------------------------------------
    # Current Directory
    # --------------------------------------------------------

    if [[ "$PWD" == "$HOME" ]]; then
        tint="blue"
        ghost="󱙝"
        label="~"

    elif [[ "$PWD" == "$HOME/"* ]]; then
        label="~/${PWD#$HOME/}"
    fi


    # --------------------------------------------------------
    # Path Length
    # --------------------------------------------------------

    local maxpath=$(( width > 35 ? width - 30 : 10 ))

    if (( ${#label} > maxpath )); then
        label="…${label[-maxpath,-1]}"
    fi


    # --------------------------------------------------------
    # Escape Prompt Characters
    # --------------------------------------------------------

    # Evita interpretar '%' contenido en nombres de directorios.
    label=${label//\%/%%}

    local user_label=${USER//\%/%%}


    # --------------------------------------------------------
    # Prompt Width
    # --------------------------------------------------------

    local left="╭──[ $ghost ][ $label ]"
    local right="[ $user_label ]──╮"

    local pad=$(( width - ${#left} - ${#right} - 3 ))

    (( pad >= 0 )) || pad=0


    # --------------------------------------------------------
    # Prompt Composition
    # --------------------------------------------------------

    DF_PROMPT_TOP="%B%F{$tint}╭──%f%b%F{magenta}[ $ghost ]%f%F{cyan}[ $label ]%f %F{$tint}${(l:$pad::-:)}%f %F{magenta}[ $user_label ]%f%F{$tint}──╮%f"

    DF_PROMPT_BOTTOM="%B%F{$tint}╰──%f%b%F{magenta}➤  %f"


    # --------------------------------------------------------
    # Git Status
    # --------------------------------------------------------

    dotfiles_git_refresh

    return 0
}

# ============================================================
# Hooks
# ============================================================

autoload -Uz add-zsh-hook

# Evita duplicar el hook si ~/.zshrc se recarga.
add-zsh-hook -d precmd dotfiles_precmd 2>/dev/null
add-zsh-hook precmd dotfiles_precmd

typeset -U \
    precmd_functions \
    preexec_functions \
    chpwd_functions


# ============================================================
# Prompt
# ============================================================

PROMPT='${DF_PROMPT_TOP}
${DF_PROMPT_BOTTOM}'

RPROMPT='${DF_GIT_PROMPT}'
