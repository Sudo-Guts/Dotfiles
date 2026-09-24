#!/usr/bin/env bash

# =============================================================================
# bootstrap.sh - Configuración completa de mi entorno Linux
# =============================================================================
# Este script:
#   1. Detecta el directorio raíz de los dotfiles
#   2. Ejecuta en orden los scripts de instalación (common, nvim, zsh, kitty, fonts)
#   3. Crea enlaces simbólicos de las configuraciones (desde las carpetas nvim/, zsh/, etc.)
#   4. Cambia el shell por defecto a Zsh si es necesario
#   5. Es idempotente y no interactivo
# =============================================================================
#	~/.dotfiles/
#	├── install/                      # Todos los scripts de instalación
#	│   ├── bootstrap.sh              # Script principal (orquesta todo)
#	│   ├── common.sh                 # Cosas comunes: curl, git, timedatectl...
#	│   ├── nvim.sh                   # Instalación de Neovim y config
#	│   ├── zsh.sh                    # Instalación de Zsh, Oh My Zsh, plugins
#	│   ├── kitty.sh                  # Instalación de Kitty
#	│   └── fonts.sh                  # Instalación de Nerd Fonts
#	├── nvim/                         # Configuración de Neovim (init.lua, etc.)
#	├── zsh/                          # Configuración de Zsh (.zshrc, etc.)
#	├── kitty/                        # Configuración de Kitty
#	└── fonts/                        # Fuentes
# =============================================================================

# Detener el script si ocurre cualquier error
set -e

# Colores para una salida más bonita
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# 1. Variables y detección de rutas
# -----------------------------------------------------------------------------

# DOTFILES: directorio raíz del repositorio (el que contiene la carpeta install/)

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${DOTFILES}/install"

echo -e "${GREEN}🚀 Iniciando configuración de dotfiles desde ${DOTFILES}${NC}"

# -----------------------------------------------------------------------------
# 2. Función para ejecutar un script de instalación si existe
# -----------------------------------------------------------------------------

run_installer() {
    local script_name="$1"
    local script_path="${INSTALL_DIR}/${script_name}.sh"
    
    if [[ -f "$script_path" ]]; then
        echo -e "${GREEN}📦 Ejecutando ${script_name}.sh ...${NC}"
        chmod +x "$script_path"
        bash "$script_path"
    else
        echo -e "${YELLOW}⚠️  No se encuentra ${script_path} - saltando${NC}"
    fi
}

# -----------------------------------------------------------------------------
# Función para ejecutar un instalador opcional con pregunta al usuario
# -----------------------------------------------------------------------------
run_optional_installer() {
    local script_name="$1"
    local prompt_message="${2:-¿Deseas instalar $script_name?}"
    local script_path="${INSTALL_DIR}/${script_name}.sh"

    if [[ -f "$script_path" ]]; then
        if ask_yes_no "$prompt_message"; then
            echo -e "${GREEN}📦 Ejecutando ${script_name}.sh ...${NC}"
            chmod +x "$script_path"
            sudo bash "$script_path"
        else
            echo -e "${YELLOW}⏭️  Saltando ${script_name}${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No se encuentra ${script_path} - saltando${NC}"
    fi
}

# Función auxiliar para preguntar
ask_yes_no() {
    local prompt="$1 (y/n): "
    local answer
    read -r -p "$prompt" answer
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# -----------------------------------------------------------------------------
# 3. Instalación de programas (orden lógico)
# -----------------------------------------------------------------------------

# common.sh: curl, git, wget, unzip, timedatectl, etc.
#run_installer "common"

# nvim.sh: Neovim y plugins
run_installer "nvim"

# zsh.sh: Zsh, Oh My Zsh, plugins
run_installer "zsh"

# kitty.sh: Terminal Kitty
run_installer "kitty"

# docker.sh: Docker
run_installer "docker"

# vhri.sh - Herramientas Verilog/VHDL
run_installer "vhri"

# fonts.sh: Nerd Fonts
run_installer "fonts"

# Módulos opcionales (con pregunta)
run_optional_installer "riscv" "¿Deseas instalar el entorno de desarrollo RISC-V? (tarda ~1 hora)"

# -----------------------------------------------------------------------------
# 4. Enlaces simbólicos de configuración
# -----------------------------------------------------------------------------

# Cada carpeta (nvim/, zsh/, kitty/) contiene archivos de configuración.
# Creamos enlaces desde ~/.config/ o ~/ según corresponda.
echo -e "${GREEN}🔗 Creando enlaces simbólicos de configuración...${NC}"

#Función segura para enlazar archivos/carpetas
safe_link() {
    local src="$1"
    local dst="$2"
    
    if [[ ! -e "$src" ]]; then
        echo -e "${YELLOW}   ⚠️  Origen no existe: $src${NC}"
        return 1
    fi
    
    # Si el destino ya existe (sea archivo, directorio o enlace), respaldar
    if [[ -e "$dst" ]] || [[ -L "$dst" ]]; then
        echo "   📁 Respaldo: $dst → ${dst}.backup"
        mv "$dst" "${dst}.backup" 2>/dev/null || true
    fi
    
    # Crear el directorio padre si no existe
    mkdir -p "$(dirname "$dst")"
    
    # Crear el enlace simbólico
    ln -sf "$src" "$dst"
    echo "   ✅ ${src} → ${dst}"
}

# Enlaces para Neovim (configuración en ~/.config/nvim)
if [[ -d "${DOTFILES}/nvim" ]]; then
    safe_link "${DOTFILES}/nvim" "${HOME}/.config/nvim"
fi

# Enlaces para Zsh (.zshrc en home)
if [[ -f "${DOTFILES}/zsh/.zshrc" ]]; then
    safe_link "${DOTFILES}/zsh/.zshrc" "${HOME}/.zshrc"
fi
# También puedes enlazar otros archivos como .zshenv, .zprofile, etc.
if [[ -f "${DOTFILES}/zsh/.zshenv" ]]; then
    safe_link "${DOTFILES}/zsh/.zshenv" "${HOME}/.zshenv"
fi

# Enlaces para Kitty (~/.config/kitty)
if [[ -d "${DOTFILES}/kitty" ]]; then
    safe_link "${DOTFILES}/kitty" "${HOME}/.config/kitty"
fi

# -----------------------------------------------------------------------------
# 5. Cambiar el shell por defecto a Zsh
# -----------------------------------------------------------------------------

if command -v zsh &>/dev/null; then
    if [[ "$SHELL" != *"zsh" ]]; then
        echo -e "${GREEN}🐚 Cambiando shell por defecto a Zsh...${NC}"
        # chsh requiere la ruta completa del shell
        ZSH_PATH="$(which zsh)"
        if [[ -f "$ZSH_PATH" ]]; then
            sudo chsh -s "$ZSH_PATH" "$USER" 2>/dev/null || {
                echo -e "${YELLOW}⚠️  No se pudo cambiar el shell automáticamente. Ejecuta manualmente: chsh -s $(which zsh)${NC}"
            }
        fi
    else
        echo -e "${GREEN}✅ El shell ya es Zsh${NC}"
    fi
fi

# -----------------------------------------------------------------------------
# 6. Mensaje final
# -----------------------------------------------------------------------------

echo -e "${GREEN}✅ ¡Configuración completada!${NC}"
echo -e "${YELLOW}📌 Recomendación: reinicia tu sesión o abre una nueva terminal.${NC}"
