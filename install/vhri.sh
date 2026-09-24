#!/usr/bin/env bash
# =============================================================================
# vhri.sh - Instalación de herramientas para Verilog/VHDL
# =============================================================================
# Este script instala:
#   - GHDL          (simulador VHDL)
#   - GTKWave       (visor de formas de onda)
#   - Icarus Verilog (simulador Verilog)
#   - Verible       (LSP para Verilog/SystemVerilog)
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}===> $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Verificar ejecución con sudo
if [[ $EUID -ne 0 ]]; then
    print_error "Este script debe ejecutarse con sudo: sudo ./install/vhri.sh"
fi

# -----------------------------------------------------------------------------
# 1. Instalar paquetes desde apt
# -----------------------------------------------------------------------------
print_step "Instalando GHDL, GTKWave e Icarus Verilog desde apt..."
apt update -y
apt install -y ghdl gtkwave iverilog

# -----------------------------------------------------------------------------
# 2. Instalar Verible (LSP para Verilog)
# -----------------------------------------------------------------------------
print_step "Instalando Verible (última versión estable)..."

# Directorio temporal
WORKDIR="/tmp/verible_build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Obtener la URL de la última versión de Verible desde GitHub API
# Usamos jq si está instalado, si no, usamos grep/sed (más portable)
if command -v jq &>/dev/null; then
    LATEST_URL=$(curl -s https://api.github.com/repos/chipsalliance/verible/releases/latest | jq -r '.assets[] | select(.name | test("linux-static-x86_64.tar.gz")) | .browser_download_url')
else
    LATEST_URL=$(curl -s https://api.github.com/repos/chipsalliance/verible/releases/latest | grep -o 'https://[^"]*linux-static-x86_64.tar.gz' | head -1)
fi

if [[ -z "$LATEST_URL" ]]; then
    print_error "No se pudo obtener la URL de la última versión de Verible."
fi

print_step "Descargando Verible desde $LATEST_URL"
wget -q --show-progress -O verible.tar.gz "$LATEST_URL"

print_step "Extrayendo Verible..."
tar -xzf verible.tar.gz --strip-components=1 -C "$WORKDIR"

print_step "Copiando binarios a /usr/local/bin..."
# Verible tiene varios binarios, copiamos todos los que empiecen por verible-
cp verible-*/bin/verible-* /usr/local/bin/ 2>/dev/null || cp bin/verible-* /usr/local/bin/ 2>/dev/null

# Verificar que se copió verible-verilog-ls
if ! command -v verible-verilog-ls &>/dev/null; then
    print_error "No se pudo instalar verible-verilog-ls."
fi

# -----------------------------------------------------------------------------
# 3. Limpiar
# -----------------------------------------------------------------------------
print_step "Limpiando archivos temporales..."
cd /
rm -rf "$WORKDIR"

# -----------------------------------------------------------------------------
# 4. Verificación final
# -----------------------------------------------------------------------------
print_step "Verificando instalación..."
echo -e "${GREEN}✅ GHDL: $(ghdl --version | head -1)${NC}"
echo -e "${GREEN}✅ GTKWave: $(gtkwave --version 2>&1 | head -1)${NC}"
echo -e "${GREEN}✅ Icarus Verilog: $(iverilog -V 2>&1 | head -1)${NC}"
echo -e "${GREEN}✅ Verible: $(verible-verilog-ls --version 2>&1 | head -1)${NC}"

echo -e "${GREEN}✅ Instalación completada.${NC}"
echo -e "${YELLOW}📌 Puedes usar las herramientas desde cualquier terminal.${NC}"
echo -e "${YELLOW}   - GHDL: ghdl -a archivo.vhd${NC}"
echo -e "${YELLOW}   - iverilog: iverilog -o salida archivo.v${NC}"
echo -e "${YELLOW}   - GTKWave: gtkwave archivo.vcd${NC}"
