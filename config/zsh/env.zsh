# ============================================================
# Environment
# ============================================================

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export RISCV="${RISCV:-/opt/riscv}"

export EDITOR="nvim"
export VISUAL="nvim"


# ============================================================
# PATH
# ============================================================

# Evita entradas duplicadas automáticamente.
typeset -U path PATH

MASON_BIN="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"

path=(
    "$HOME/.local/bin"
    "$HOME/.local/kitty.app/bin"

    "$RISCV/bin"
    "$HOME/.local/opt/riscv/bin"
    "$HOME/.local/xPacks/@xpack-dev-tools/riscv-none-elf-gcc/latest/bin"

    # Conservar las rutas existentes, excepto Mason.
    "${(@)path:#"$MASON_BIN"}"

    # Mason queda al final para dar prioridad a las herramientas
    # instaladas por el sistema.
    "$MASON_BIN"
)

export PATH

unset MASON_BIN
