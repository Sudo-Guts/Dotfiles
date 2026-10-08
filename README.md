# GUTS Dotfiles

Configuración personal para un entorno de desarrollo en Debian y Ubuntu. Incluye Zsh, Kitty y Neovim, además de un instalador que prepara herramientas y enlaza las configuraciones.

## Qué incluye

- Configuración de Zsh y Kitty.
- Neovim con herramientas para C/C++, Python, Verilog/SystemVerilog y VHDL.
- Desde Neovim puedes compilar y ejecutar proyectos C/C++, depurar C/C++ y Python, y simular proyectos HDL.
- Opciones de instalación para AVR/ATmega, RISC-V, Docker, GNOME, Apache y OpenSSH.

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
dotfiles install --with-avr
dotfiles install --with-riscv
dotfiles install --with-docker
dotfiles install --with-gnome
dotfiles install --with-apache --with-ssh
```

El shell predeterminado solo cambia si se solicita con `--change-shell`.

`--with-avr` instala `gcc-avr`, `binutils-avr`, `avr-libc`, `avrdude` y `make`.
La selección se conserva en `install` y `update`; el estado anterior se adapta
automáticamente. `doctor` revisa las herramientas y el encabezado `avr/io.h`.

### Firmware AVR desde Neovim

Abre un archivo C del proyecto. Neovim encuentra el Makefile más cercano, tanto
en la raíz como en `C0DE/`. Detecta AVR si usa `avr-gcc` o `avr-g++`; también puedes
seleccionar el destino con `Espacio rt` y guardarlo en `.nvim/cpp.json`.
En `Inversor-Trifasico-SPWM`, la raíz del firmware es `C0DE/`: allí quedan
`Makefile`, `compile_commands.json` y `.nvim/cpp.json`. Desde terminal usa
`make -C C0DE` si estás en la raíz del repositorio.

| Atajo | Acción |
|---|---|
| `Espacio rp` | Panel del proyecto y herramientas disponibles |
| `Espacio rg` | Generar `compile_commands.json` con Bear para `gd` |
| `Espacio rc` | Compilar con el Makefile |
| `Espacio rm` | Escribir un objetivo: `size`, `disasm`, `clean` o `flash` |
| `Espacio rl` | Ver la salida en vivo |

Para indexar, deja vacío el objetivo de `rg` o elige uno que solo compile.
clangd consulta el compilador AVR instalado para localizar sus encabezados y
usa los flags reales del proyecto, incluidos `-mmcu`, `-I` y `-DF_CPU`.
Los objetivos deben existir en tu Makefile. AVR se reconoce como firmware y
`Espacio re` no lo ejecuta en la PC. La grabación requiere elegir `flash`
manualmente y configurar el programador en el proyecto. El instalador no graba
memorias ni cambia fusibles; `F_CPU` y la frecuencia del reloj se definen en cada proyecto.

### Servidores opcionales

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

