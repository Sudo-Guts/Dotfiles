#!/usr/bin/env bash

# =============================================================================
# install/kitty.sh - Instalación del terminal Kitty
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

KITTY_DIR="$HOME/.local/kitty.app"

echo -e "${GREEN}🐱 Instalando Kitty terminal...${NC}"

# -----------------------------------------------------------------------------
# Install latest Kitty
# -----------------------------------------------------------------------------

if [[ ! -x "$KITTY_DIR/bin/kitty" ]]; then

    echo "   Instalando última versión de Kitty..."

    curl -L https://sw.kovidgoyal.net/kitty/installer.sh |
        sh /dev/stdin launch=n

else

    echo -e "${YELLOW}   Kitty ya está instalado, saltando.${NC}"

fi

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------

echo
"$KITTY_DIR/bin/kitty" --version

echo
echo -e "${GREEN}✅ Kitty instalado correctamente.${NC}"
