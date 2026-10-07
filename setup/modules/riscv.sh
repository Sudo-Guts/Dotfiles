#!/usr/bin/env bash

# ============================================================
# RISC-V Development Environment
# ============================================================
#
# GUTS Dotfiles
#
# Proporciona dos modos de instalación:
#
#   1. Sistema
#      bash setup/modules/riscv.sh
#
#      Instala mediante APT:
#        - GCC bare-metal RISC-V
#        - Binutils
#        - GDB Multiarch
#        - QEMU
#
#   2. Fuente
#      bash setup/modules/riscv.sh --source
#
#      Compila:
#        - RISC-V GNU Toolchain
#        - Spike
#        - Proxy Kernel (pk)
#
# El modo fuente instala todo dentro de:
#
#   ~/.local/opt/riscv
#
# salvo que RISCV_BUILD_PREFIX defina otra ruta.
#
# Este script NO modifica ~/.zshrc ni elimina /opt/riscv.
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Configuration
# ============================================================

build_root="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/riscv"
prefix="${RISCV_BUILD_PREFIX:-$HOME/.local/opt/riscv}"

jobs="${DOTFILES_JOBS:-2}"


# ============================================================
# Arguments
# ============================================================

case "${1:-}" in

    "")
        mode="system"
        ;;

    --source)
        mode="source"
        ;;

    *)
        die "Uso: riscv.sh [--source]"
        ;;

esac

(( $# <= 1 )) ||
    die "Uso: riscv.sh [--source]"


# ============================================================
# System Installation
# ============================================================

if [[ "$mode" == "system" ]]; then

    log "Instalando entorno RISC-V desde los repositorios del sistema..."

    apt_install \
        gcc-riscv64-unknown-elf \
        binutils-riscv64-unknown-elf \
        gdb-multiarch \
        qemu-system-misc

    log "Toolchain RISC-V del sistema lista."
    log "Para RV32I usa: -march=rv32i -mabi=ilp32"

    exit 0
fi


# ============================================================
# Source Build Dependencies
# ============================================================

log "Instalando dependencias para compilación desde fuente..."

apt_install \
    autoconf \
    automake \
    autotools-dev \
    curl \
    python3 \
    python3-pip \
    python3-tomli \
    libmpc-dev \
    libmpfr-dev \
    libgmp-dev \
    gawk \
    build-essential \
    bison \
    flex \
    texinfo \
    gperf \
    libtool \
    patchutils \
    bc \
    zlib1g-dev \
    libexpat-dev \
    meson \
    ninja-build \
    git \
    cmake \
    libglib2.0-dev \
    expect \
    device-tree-compiler \
    libslirp-dev \
    libzstd-dev \
    libncurses-dev \
    libboost-regex-dev \
    libboost-system-dev


# ============================================================
# Build Directories
# ============================================================

mkdir -p \
    "$build_root" \
    "$prefix"

export PATH="$prefix/bin:$PATH"


# ============================================================
# RISC-V GNU Toolchain
# ============================================================

toolchain_source="$build_root/toolchain"
toolchain_build="$build_root/toolchain-build"

if [[ ! -f "$prefix/.toolchain-complete" ]]; then

    log "Preparando RISC-V GNU Toolchain..."

    sync_repo \
        "https://github.com/riscv-collab/riscv-gnu-toolchain.git" \
        "$toolchain_source"

    mkdir -p "$toolchain_build"


    # --------------------------------------------------------
    # Configure
    # --------------------------------------------------------

    log "Configurando RISC-V GNU Toolchain..."

    (
        cd -- "$toolchain_build" || die "No se puede entrar en: $toolchain_build"

        "$toolchain_source/configure" \
            --prefix="$prefix" \
            --enable-multilib \
            --with-multilib-generator='rv32i-ilp32--;rv64gc-lp64d--'
    )


    # --------------------------------------------------------
    # Build
    # --------------------------------------------------------

    log "Compilando RISC-V GNU Toolchain..."

    (
        cd -- "$toolchain_build" || die "No se puede entrar en: $toolchain_build"

        make -j"$jobs"
    )


    # --------------------------------------------------------
    # Mark Complete
    # --------------------------------------------------------

    touch "$prefix/.toolchain-complete"

    log "RISC-V GNU Toolchain instalada."

else

    log "RISC-V GNU Toolchain ya instalada."

fi


# ============================================================
# Spike
# ============================================================

spike_source="$build_root/spike"
spike_build="$build_root/spike-build"

if [[ ! -f "$prefix/.spike-complete" ]]; then

    log "Preparando Spike..."

    sync_repo \
        "https://github.com/riscv-software-src/riscv-isa-sim.git" \
        "$spike_source"

    mkdir -p "$spike_build"


    # --------------------------------------------------------
    # Configure
    # --------------------------------------------------------

    (
        cd -- "$spike_build" || die "No se puede entrar en: $spike_build"

        "$spike_source/configure" \
            --prefix="$prefix"
    )


    # --------------------------------------------------------
    # Build
    # --------------------------------------------------------

    log "Compilando Spike..."

    (
        cd -- "$spike_build" || die "No se puede entrar en: $spike_build"

        make -j"$jobs"
        make install
    )


    # --------------------------------------------------------
    # Mark Complete
    # --------------------------------------------------------

    touch "$prefix/.spike-complete"

    log "Spike instalado."

else

    log "Spike ya instalado."

fi


# ============================================================
# RISC-V Proxy Kernel
# ============================================================

pk_source="$build_root/pk"
pk_build="$build_root/pk-build"

if [[ ! -f "$prefix/.pk-complete" ]]; then

    log "Preparando RISC-V Proxy Kernel..."

    sync_repo \
        "https://github.com/riscv-software-src/riscv-pk.git" \
        "$pk_source"

    mkdir -p "$pk_build"


    # --------------------------------------------------------
    # Configure
    # --------------------------------------------------------

    (
        cd -- "$pk_build" || die "No se puede entrar en: $pk_build"

        "$pk_source/configure" \
            --prefix="$prefix" \
            --host=riscv64-unknown-elf \
            --with-arch=rv64gc \
            --with-abi=lp64d
    )


    # --------------------------------------------------------
    # Build
    # --------------------------------------------------------

    log "Compilando Proxy Kernel..."

    (
        cd -- "$pk_build" || die "No se puede entrar en: $pk_build"

        make -j"$jobs"
        make install
    )


    # --------------------------------------------------------
    # Mark Complete
    # --------------------------------------------------------

    touch "$prefix/.pk-complete"

    log "Proxy Kernel instalado."

else

    log "Proxy Kernel ya instalado."

fi


# ============================================================
# Verification
# ============================================================

log "Verificando entorno RISC-V..."

if command -v riscv64-unknown-elf-gcc >/dev/null 2>&1; then
    log "GCC: $(riscv64-unknown-elf-gcc --version | head -n1)"
fi

if command -v spike >/dev/null 2>&1; then
    log "Spike disponible."
fi


# ============================================================
# Done
# ============================================================

log "Entorno RISC-V instalado en: $prefix"
log "Multilib disponible para RV32I/ILP32 y RV64GC/LP64D."
log "pk es una herramienta para Spike; no es el firmware de tu CPU RV32I."
