#!/usr/bin/env bash
# =============================================================================
# install/riscv.sh - Instalación automática y forzada del entorno RISC-V
# =============================================================================
# Este script SIEMPRE reinstala la toolchain RISC-V, Spike y Proxy Kernel.
# No pregunta nada, no verifica si ya está instalado.
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

export RISCV="/opt/riscv"
export PATH="$RISCV/bin:$PATH"

print_step() {
    echo -e "${GREEN}===> $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Verificar ejecución con sudo
if [[ $EUID -ne 0 ]]; then
    print_error "Este script debe ejecutarse con sudo: sudo ./install/riscv.sh"
fi

# -----------------------------------------------------------------------------
# 0. Limpiar instalación anterior (SIEMPRE)
# -----------------------------------------------------------------------------
print_step "Eliminando instalación anterior (si existe)..."
sudo rm -rf /opt/riscv
rm -rf /tmp/riscv_build

# -----------------------------------------------------------------------------
# 1. Preparar directorio temporal
# -----------------------------------------------------------------------------
WORKDIR="/tmp/riscv_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# -----------------------------------------------------------------------------
# 2. Dependencias del sistema
# -----------------------------------------------------------------------------
print_step "Instalando dependencias del sistema..."
apt update -y
apt install -y \
    autoconf automake autotools-dev curl python3 python3-pip \
    python3-tomli libmpc-dev libmpfr-dev libgmp-dev gawk \
    build-essential bison flex texinfo gperf libtool patchutils \
    bc zlib1g-dev libexpat-dev ninja-build git cmake \
    libglib2.0-dev libslirp-dev device-tree-compiler \
    libboost-regex-dev libboost-system-dev

# -----------------------------------------------------------------------------
# 3. Crear directorio de instalación y asignar permisos al usuario
# -----------------------------------------------------------------------------
print_step "Creando directorio $RISCV y asignando permisos..."
mkdir -p "$RISCV"
chown -R "$SUDO_USER":"$SUDO_USER" "$RISCV"

# -----------------------------------------------------------------------------
# 4. Clonar y compilar la toolchain (newlib)
# -----------------------------------------------------------------------------
print_step "Clonando riscv-gnu-toolchain..."
git clone --depth 1 https://github.com/riscv/riscv-gnu-toolchain
cd riscv-gnu-toolchain

print_step "Configurando toolchain para bare-metal (newlib)..."
./configure --prefix="$RISCV" --with-arch=rv64imafdc_zifencei --with-abi=lp64d
print_step "Compilando toolchain (esto puede tomar 30-60 minutos)..."
make -j$(nproc)
make install

cd "$WORKDIR"

# -----------------------------------------------------------------------------
# 5. (Opcional) Toolchain para Linux
# -----------------------------------------------------------------------------
# Si quieres incluirla siempre, descomenta las siguientes líneas:
# print_step "Configurando toolchain para Linux..."
# cd riscv-gnu-toolchain
# ./configure --prefix="$RISCV" --with-arch=rv64imafdc_zifencei --with-abi=lp64d
# make linux -j$(nproc)
# make linux install
# cd "$WORKDIR"

# -----------------------------------------------------------------------------
# 6. Clonar y compilar Spike
# -----------------------------------------------------------------------------
print_step "Clonando Spike..."
git clone --depth 1 https://github.com/riscv-software-src/riscv-isa-sim
cd riscv-isa-sim
mkdir -p build
cd build
print_step "Configurando Spike..."
../configure --prefix="$RISCV"
print_step "Compilando Spike..."
make -j$(nproc)
make install

cd "$WORKDIR"

# -----------------------------------------------------------------------------
# 7. Clonar y compilar Proxy Kernel (pk)
# -----------------------------------------------------------------------------
print_step "Clonando Proxy Kernel (pk)..."
git clone --depth 1 https://github.com/riscv-software-src/riscv-pk
cd riscv-pk
mkdir -p build
cd build
print_step "Configurando pk (con CFLAGS para Zifencei)..."
CFLAGS="-march=rv64imafdc_zifencei" ../configure --prefix="$RISCV" --host=riscv64-unknown-elf
print_step "Compilando pk..."
make -j$(nproc)
make install

# -----------------------------------------------------------------------------
# 8. Añadir variables de entorno al .zshrc del usuario
# -----------------------------------------------------------------------------
print_step "Agregando variables de entorno al .zshrc del usuario..."
USER_HOME=$(eval echo ~"$SUDO_USER")
grep -qxF "export RISCV=\"$RISCV\"" "$USER_HOME/.zshrc" || \
    echo "export RISCV=\"$RISCV\"" >> "$USER_HOME/.zshrc"
grep -qxF 'export PATH="$RISCV/bin:$PATH"' "$USER_HOME/.zshrc" || \
    echo 'export PATH="$RISCV/bin:$PATH"' >> "$USER_HOME/.zshrc"

# -----------------------------------------------------------------------------
# 9. Limpiar
# -----------------------------------------------------------------------------
print_step "Limpiando archivos temporales..."
cd /
rm -rf "$WORKDIR"

# -----------------------------------------------------------------------------
# 10. Verificación final
# -----------------------------------------------------------------------------
print_step "¡Instalación completada! Verificando herramientas..."
su - "$SUDO_USER" -c "source $USER_HOME/.zshrc && riscv64-unknown-elf-gcc --version"
su - "$SUDO_USER" -c "source $USER_HOME/.zshrc && spike --h"
su - "$SUDO_USER" -c "source $USER_HOME/.zshrc && pk --version" || echo "pk se encuentra en $RISCV/riscv64-unknown-elf/bin/pk"

echo -e "${GREEN}✅ Instalación exitosa.${NC}"
echo -e "${YELLOW}📌 Para usar las herramientas, reinicia tu terminal o ejecuta: source ~/.zshrc${NC}"
