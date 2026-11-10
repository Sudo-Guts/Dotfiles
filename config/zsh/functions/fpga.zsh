# =============================================================================
#   Proyecto : Dotfiles
#   Archivo  : fpga.zsh
#   Autor    : Gustavo Ruiz Luis
# =============================================================================
#
#   FPGA - Herramientas para desarrollo y programacion
#
#   Requisitos:
#       - bash: necesario para cargar el entorno de Xilinx ISE.
#       - Xilinx ISE 14.7: entorno de desarrollo para FPGA.
#       - djtgcfg: herramienta de programacion de Digilent.
#
#   Nota:
#       - dotfiles_need() se define en functions/utils.zsh.
#       - Este archivo se carga desde config/zsh/.zshrc.
#       - XILINX_SETTINGS permite personalizar la ruta de ISE.
#
# =============================================================================


# =============================================================================
#   Xilinx ISE
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: ise
# -----------------------------------------------------------------------------
#
#   Inicia Xilinx ISE utilizando su entorno de configuracion.
#
#   Operaciones:
#       1. Localiza el archivo settings64.sh.
#       2. Verifica que el archivo exista y sea legible.
#       3. Carga las variables de entorno mediante Bash.
#       4. Ejecuta Xilinx ISE.
#
#   Nota:
#       - La configuracion se carga en un proceso independiente.
#       - No modifica las variables de entorno de la sesion Zsh.
#       - La ruta predeterminada corresponde a Xilinx ISE 14.7.
#
# -----------------------------------------------------------------------------

function ise() {
    local settings="${XILINX_SETTINGS:-/opt/Xilinx/14.7/ISE_DS/settings64.sh}"

    [[ -r "$settings" ]] || {
        print -u2 -- "No existe: $settings"
        return 1
    }

    bash -c '
        settings="$1"
        set --
        source "$settings" &&
            exec ise
    ' _ "$settings"
}


# =============================================================================
#   Digilent / Nexys 3
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: digilent archivo.bit
# -----------------------------------------------------------------------------
#
#   Programa la FPGA Nexys 3 mediante la herramienta djtgcfg.
#
#   Operaciones:
#       1. Comprueba que se proporcione un archivo .bit.
#       2. Verifica que djtgcfg este disponible.
#       3. Convierte la ruta del archivo a una ruta absoluta.
#       4. Comprueba que el archivo exista.
#       5. Inicializa la comunicacion con Nexys 3.
#       6. Programa el dispositivo con el bitstream indicado.
#
#   Nota:
#       - Requiere que la tarjeta este conectada.
#       - Utiliza el indice de dispositivo 0.
#       - No genera el archivo .bit; solo lo programa.
#
# -----------------------------------------------------------------------------

function digilent() {
    (( $# == 1 )) || {
        print -u2 "Uso: digilent archivo.bit"
        return 1
    }

    dotfiles_need djtgcfg || return

    local bit_file="${1:A}"

    [[ -f "$bit_file" ]] || {
        print -u2 -- "No existe: $bit_file"
        return 1
    }

    command djtgcfg init \
        -d Nexys3 &&
        command djtgcfg prog \
            -d Nexys3 \
            -i 0 \
            -f "$bit_file"
}
