# GUTS Dotfiles

Configuración personal para un entorno de desarrollo en Debian y Ubuntu. Incluye Zsh, Kitty y Neovim, además de un instalador que prepara herramientas y enlaza las configuraciones.

## Qué incluye

- Configuración de Zsh y Kitty.
- Neovim con herramientas para C/C++, Python, Verilog/SystemVerilog y VHDL.
- Desde Neovim puedes compilar y ejecutar proyectos C/C++, depurar C/C++ y Python, y simular proyectos HDL.
- Opciones de instalación para RISC-V, Docker, GNOME, Apache y OpenSSH.

## Instalación

Requiere Git e Internet. Ejecuta el instalador como usuario normal; puede pedir permisos para instalar paquetes.

```bash
git clone https://github.com/Sudo-Guts/Dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash bin/dotfiles install
```

Abre una terminal nueva al terminar. Si el instalador reemplaza una configuración existente, guarda una copia de respaldo junto al archivo original. No ejecuta una actualización general del sistema.

La preparación de Neovim usa cachés temporales para evitar bloqueos de Tree-sitter
dejados por una ejecución interrumpida. Las elimina al terminar o fallar;
plugins, herramientas y parsers permanecen en sus rutas de datos habituales.

Para añadir componentes opcionales:

```bash
dotfiles install --with-riscv
dotfiles install --with-docker
dotfiles install --with-gnome
dotfiles install --with-apache --with-ssh
```

El shell predeterminado solo cambia si se solicita con `--change-shell`.

Apache y OpenSSH son opcionales e independientes. Se instalan mediante APT y
su selección se conserva para los siguientes `install` y `update`; omitir una
opción después no desinstala el componente. El estado anterior se adapta
automáticamente, sin volver a usar `--migrate-state`.

APT puede activar estos servicios al instalarlos. Según su configuración, pueden
aceptar conexiones de red (puertos predeterminados: HTTP 80 y SSH 22). Los módulos
conservan tus sitios, permisos de `/var/www`, autenticación y claves existentes,
y dejan las reglas del firewall bajo tu control. `doctor` comprueba que estén
disponibles los ejecutables seleccionados; no prueba una conexión de red.

### Si ya usabas el repositorio anterior

Este repositorio empieza con un historial Git nuevo. El estado de una instalación
anterior puede impedir `install` porque su commit ya no existe aquí. En el clon
del nuevo repositorio, ejecuta una sola vez:

```bash
bash bin/dotfiles install --migrate-state
```

La opción respalda el estado anterior en
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/install.state.backup.XXXXXX` y conserva
los componentes opcionales seleccionados. El nuevo commit solo queda
registrado como aplicado al terminar. Si falla, corrige el error y repite `install`.
`update` mantiene la protección frente a revisiones antiguas; la migración nunca
se hace automáticamente. El repositorio debe estar sin cambios locales.

Si `~/.dotfiles` ya existe, consérvalo y clona este repositorio en otra carpeta;
ejecuta el comando anterior dentro del nuevo clon.

## Comandos

| Comando | Uso |
|---|---|
| `dotfiles help` | Ver comandos y opciones |
| `dotfiles update` | Actualizar el repositorio y sus componentes |
| `dotfiles doctor` | Revisar enlaces y herramientas instaladas |
| `dotfiles check` | Comprobar sintaxis y configuración |
| `dotfiles link` | Aplicar los enlaces de configuración |

## Organización

- `config/`: archivos de Zsh, Kitty, Neovim y Ruff.
- `setup/`: módulos de instalación y versiones de herramientas.
- `bin/`: comandos `dotfiles`, `check` y `doctor`.
- `lib/`: funciones compartidas por el instalador.

