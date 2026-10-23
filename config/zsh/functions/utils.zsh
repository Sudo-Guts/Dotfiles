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
#       - STM32CubeIDE y STM32CubeProgrammer: opcionales, instalados por separado.
#       - sudo: necesario para abrir CubeProgrammer con cubeprog().
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


# =============================================================================
#   STM32
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: cubeide [argumentos]
# -----------------------------------------------------------------------------
#
#   Abre STM32CubeIDE como usuario normal.
#   Busca stm32cubeide en PATH, /opt/st/ y ~/st/.
#   STM32_CUBEIDE_GUI permite indicar la ruta completa del ejecutable.
#   Conserva los mensajes del programa en esta terminal.
#
# -----------------------------------------------------------------------------

function cubeide() {
    local app="${STM32_CUBEIDE_GUI:-${commands[stm32cubeide]:-}}"
    local candidate

    if [[ -z "${STM32_CUBEIDE_GUI:-}" && ( ! -f "$app" || ! -x "$app" ) ]]; then
        app=""
        for candidate in \
            /opt/st/stm32cubeide*/stm32cubeide(NnOn) \
            "$HOME"/st/stm32cubeide*/stm32cubeide(NnOn)
        do
            if [[ -f "$candidate" && -x "$candidate" ]]; then
                app="$candidate"
                break
            fi
        done
    fi

    [[ -n "$app" && -f "$app" && -x "$app" ]] || {
        print -u2 -- "No se encontro STM32CubeIDE. Define STM32_CUBEIDE_GUI con la ruta de stm32cubeide."
        return 1
    }

    command "$app" "$@"
}


# -----------------------------------------------------------------------------
#   Uso: cubeprog [argumentos]
# -----------------------------------------------------------------------------
#
#   Abre la interfaz grafica de STM32CubeProgrammer con sudo.
#   STM32_PROGRAMMER_GUI permite indicar otra ruta completa del ejecutable.
#   Mantiene sudo en primer plano para poder introducir la contrasena.
#
# -----------------------------------------------------------------------------

function cubeprog() {
    local app="${STM32_PROGRAMMER_GUI:-$HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32CubeProgrammer}"

    [[ -f "$app" && -x "$app" ]] || {
        print -u2 -- "No existe o no es ejecutable: $app"
        print -u2 -- "Define STM32_PROGRAMMER_GUI con la ruta de STM32CubeProgrammer."
        return 1
    }

    dotfiles_need sudo || return
    command sudo -- "$app" "$@"
}
