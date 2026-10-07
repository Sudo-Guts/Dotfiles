#!/usr/bin/env bash

# ============================================================
# GNOME Desktop Integration
# ============================================================
#
# GUTS Dotfiles
#
# Configura:
#
#   Ctrl + T → Kitty
#
# El script:
#
#   - Solo actúa dentro de una sesión GNOME
#   - Conserva los atajos personalizados existentes
#   - No crea entradas duplicadas
#
# ============================================================


# ============================================================
# Shared Library
# ============================================================

source "$(dirname -- "${BASH_SOURCE[0]}")/../../lib/common.sh"


# ============================================================
# Environment Check
# ============================================================

if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
    log "No hay una sesión GNOME activa; integración omitida."
    exit 0
fi


# ============================================================
# Dependencies
# ============================================================

require_command gsettings
require_command kitty
require_command python3


# ============================================================
# Configure Shortcut
# ============================================================

log "Configurando Ctrl+T para abrir Kitty..."

python3 - <<'PYTHON'
import ast
import shlex
import shutil
import subprocess


# ============================================================
# Configuration
# ============================================================

SCHEMA = "org.gnome.settings-daemon.plugins.media-keys"

SHORTCUT_PATH = (
    "/org/gnome/settings-daemon/"
    "plugins/media-keys/custom-keybindings/guts-kitty/"
)

SHORTCUT_NAME = "Kitty"
SHORTCUT_BINDING = "<Control>t"


# ============================================================
# Helpers
# ============================================================

def gsettings(*args):
    subprocess.run(
        ["gsettings", *args],
        check=True,
    )


# ============================================================
# Kitty Command
# ============================================================

kitty = shutil.which("kitty")

if kitty is None:
    raise RuntimeError("No se encontró Kitty en PATH")

kitty_command = shlex.quote(kitty)


# ============================================================
# Existing Shortcuts
# ============================================================

raw = subprocess.check_output(
    [
        "gsettings",
        "get",
        SCHEMA,
        "custom-keybindings",
    ],
    text=True,
).strip()

# GNOME puede representar una lista vacía como:
#
#   @as []
#
# ast.literal_eval necesita únicamente:
#
#   []

raw = raw.removeprefix("@as ")

shortcuts = ast.literal_eval(raw)


# ============================================================
# Register Shortcut
# ============================================================

if SHORTCUT_PATH not in shortcuts:
    shortcuts.append(SHORTCUT_PATH)

    gsettings(
        "set",
        SCHEMA,
        "custom-keybindings",
        repr(shortcuts),
    )


# ============================================================
# Shortcut Properties
# ============================================================

shortcut_schema = (
    SCHEMA
    + ".custom-keybinding:"
    + SHORTCUT_PATH
)

for key, value in (
    ("name", SHORTCUT_NAME),
    ("command", kitty_command),
    ("binding", SHORTCUT_BINDING),
):
    gsettings(
        "set",
        shortcut_schema,
        key,
        value,
    )
PYTHON


# ============================================================
# Done
# ============================================================

log "Atajo configurado: Ctrl+T → Kitty"
