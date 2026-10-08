#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"

log "Instalando/comprobando el servidor OpenSSH..."
apt_install openssh-server
log "OpenSSH listo. APT administra el servicio y puede iniciarlo al instalarlo."
# El módulo no modifica la autenticación, las claves existentes ni el firewall.
