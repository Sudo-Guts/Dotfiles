# =============================================================================
#   Proyecto : Dotfiles
#   Archivo  : utils.zsh
#   Autor    : Gustavo Ruiz Luis
# =============================================================================
#
#   Utilidades - Funciones auxiliares del entorno Zsh
#
#   Requisitos:
#       - zsh: interprete de comandos.
#       - KiCad AppImage: opcional para la funcion kicad().
#
#   Nota:
#       - Este archivo se carga desde config/zsh/.zshrc.
#       - Debe cargarse antes de los modulos que utilizan dotfiles_need().
#
# =============================================================================


# =============================================================================
#   Verificacion de dependencias
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: dotfiles_need comando
# -----------------------------------------------------------------------------
#
#   Comprueba que un comando este disponible en el entorno actual.
#
#   Comportamiento:
#       - Devuelve 0 si encuentra el comando.
#       - Devuelve 1 y muestra un mensaje si no esta disponible.
#
#   Nota:
#       - No instala dependencias automaticamente.
#       - Se utiliza en los demas modulos de funciones.
#
# -----------------------------------------------------------------------------

function dotfiles_need() {
    command -v "$1" >/dev/null || {
        print -u2 -- "Falta el comando: $1"
        return 1
    }
}

# =============================================================================
#   KiCad
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: kicad
# -----------------------------------------------------------------------------
#
#   Inicia KiCad utilizando el AppImage instalado localmente.
#
#   Comportamiento:
#       - Ejecuta el AppImage desde ~/.local/bin/.
#       - Inicia KiCad como proceso en segundo plano.
#       - Oculta la salida estandar y los mensajes de error.
#
#   Nota:
#       - No requiere instalar KiCad mediante APT.
#       - No comprueba que el AppImage exista.
#
# -----------------------------------------------------------------------------

function kicad() {
    local appimage="$HOME/.local/bin/kicad.AppImage"

    [[ -x "$appimage" ]] || {
        print -u2 -- "No existe o no es ejecutable: $appimage"
        return 1
    }

    "$appimage" >/dev/null 2>&1 &
}
