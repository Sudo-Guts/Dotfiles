#!/usr/bin/env bash

# ============================================================
# Docker Installation
# ============================================================
#
# GUTS Dotfiles
#
# Instala Docker Engine desde el repositorio oficial de Docker.
#
# Soporta:
#
#   - Ubuntu
#   - Debian
#
# El script:
#
#   - Configura la clave GPG oficial
#   - Agrega el repositorio APT de Docker
#   - Instala Docker Engine
#   - Instala Buildx
#   - Instala Docker Compose
#   - Habilita el servicio cuando systemd está disponible

# No modifica automáticamente el grupo "docker".
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Distribution Detection
# ============================================================

[[ -r /etc/os-release ]] ||
    die "No se encontró /etc/os-release."

source /etc/os-release


case "$ID" in

    ubuntu|debian)
        distro="$ID"
        ;;

    *)
        die "Docker requiere una instalación oficial de Ubuntu o Debian."
        ;;

esac


# ============================================================
# Distribution Codename
# ============================================================

# Ubuntu puede proporcionar UBUNTU_CODENAME.
# Debian utiliza VERSION_CODENAME.

if [[ "$distro" == "ubuntu" ]]; then
    codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
else
    codename="${VERSION_CODENAME:-}"
fi

[[ -n "$codename" ]] ||
    die "No se pudo determinar el codename de la distribución."


# ============================================================
# Dependencies
# ============================================================

apt_install \
    ca-certificates \
    curl


# ============================================================
# Temporary Workspace
# ============================================================

work="$(mktemp -d)"

trap 'rm -rf -- "$work"' EXIT


# ============================================================
# Docker GPG Key
# ============================================================

log "Descargando clave GPG oficial de Docker..."

download \
    "https://download.docker.com/linux/$distro/gpg" \
    "$work/docker.asc"

as_root install \
    -d \
    -m 0755 \
    /etc/apt/keyrings

as_root install \
    -m 0644 \
    "$work/docker.asc" \
    /etc/apt/keyrings/docker.asc


# ============================================================
# Docker Repository
# ============================================================

architecture="$(dpkg --print-architecture)"

cat > "$work/docker.sources" <<EOF
Types: deb
URIs: https://download.docker.com/linux/$distro
Suites: $codename
Components: stable
Architectures: $architecture
Signed-By: /etc/apt/keyrings/docker.asc
EOF

as_root install \
    -m 0644 \
    "$work/docker.sources" \
    /etc/apt/sources.list.d/docker.sources

# El índice anterior puede haberse obtenido antes de añadir este repositorio.
if [[ -n "${DOTFILES_APT_STAMP:-}" ]]; then rm -f -- "$DOTFILES_APT_STAMP"; fi


# ============================================================
# Docker Packages
# ============================================================

log "Instalando Docker Engine..."

apt_install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin


# ============================================================
# Docker Service
# ============================================================

if [[ -d /run/systemd/system ]] &&
   command -v systemctl >/dev/null 2>&1; then

    log "Habilitando servicio Docker..."

    as_root systemctl enable --now docker

fi


# ============================================================
# Verification
# ============================================================

require_command docker

docker --version
docker compose version


# ============================================================
# Done
# ============================================================

log "Docker instalado correctamente."
log "Usa sudo docker; el grupo docker no se modifica automáticamente."
