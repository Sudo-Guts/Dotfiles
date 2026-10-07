# ============================================================
# Internal Utilities
# ============================================================

function dotfiles_need() {
    command -v "$1" >/dev/null || {
        print -u2 -- "Falta el comando: $1"
        return 1
    }
}

# Lanzador del AppImage local de KiCad.
kicad() {
    "$HOME/.local/bin/kicad.AppImage" &> /dev/null &
}
