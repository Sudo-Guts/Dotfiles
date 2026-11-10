# ============================================================
# Oh My Zsh
# ============================================================

ZSH_THEME=""

# Deshabilitar actualización automática.
zstyle ':omz:update' mode disabled

# Nuestro prompt administra Git por su cuenta.
zstyle ':omz:alpha:lib:git' async-prompt no

ENABLE_CORRECTION="true"


# ============================================================
# Plugins
# ============================================================

plugins=()

for plugin in \
    git \
    zsh-interactive-cd \
    zsh-autosuggestions \
    zsh-history-substring-search
do
    plugin_dir="${ZSH_CUSTOM:-$ZSH/custom}/plugins/$plugin"
    builtin_plugin_dir="$ZSH/plugins/$plugin"

    if [[ -f "$plugin_dir/$plugin.plugin.zsh" ]] ||
       [[ -f "$builtin_plugin_dir/$plugin.plugin.zsh" ]]; then
        plugins+=("$plugin")
    fi
done

unset plugin_dir builtin_plugin_dir


# ============================================================
# Load Oh My Zsh
# ============================================================

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then

    # Evita cargar Oh My Zsh dos veces al ejecutar:
    #
    #   source ~/.zshrc
    #
    if [[ -z "${_GUTS_OMZ_LOADED:-}" ]]; then
        source "$ZSH/oh-my-zsh.sh"
        typeset -g _GUTS_OMZ_LOADED=1
    fi

else

    # Fallback mínimo si Oh My Zsh no está disponible.
    autoload -Uz compinit
    compinit -d "${HISTFILE:h}/zcompdump"

fi


# ============================================================
# Remove Conflicting Oh My Zsh Aliases
# ============================================================

# Algunas funciones propias utilizan nombres que Oh My Zsh
# también puede registrar como aliases.
#
# Se eliminan antes de cargar las funciones propias para evitar expansión
# accidental durante la definición de funciones.

for name in \
    gac \
    gacp \
    gnew \
    gdel \
    groot \
    gsync \
    ginfo \
    gcleanmerged \
    ghrepo \
    ghbranch \
    ghpr \
    ghprc \
    ghinfo \
    ise \
    digilent
do
    (( $+aliases[$name] )) && unalias "$name"
done



unset plugin name
