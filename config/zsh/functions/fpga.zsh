# ============================================================
# Xilinx ISE
# ============================================================

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

# ============================================================
# Digilent / Nexys 3
# ============================================================

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
