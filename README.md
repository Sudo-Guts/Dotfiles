# GUTS Dotfiles

Configuración personal para un entorno de desarrollo en Debian y Ubuntu. Incluye Zsh, Kitty y Neovim, además de un instalador que prepara herramientas y enlaza las configuraciones.

## Qué incluye

- Configuración de Zsh y Kitty.
- Serie para explorar el grafo de ramas y commits desde la terminal con `glpick`.
- Neovim con herramientas para C/C++, Python, Verilog/SystemVerilog y VHDL.
- Desde Neovim puedes compilar y ejecutar proyectos C/C++, depurar C/C++ y Python, y simular proyectos HDL.
- Integración automática de Kitty con GNOME para abrir la terminal con `Ctrl+T`.
- Opciones de instalación para AVR/ATmega, RISC-V, Docker, Apache y OpenSSH.

En C/C++, el estilo predeterminado usa cuatro espacios y alinea los `break;`
directos de cada caso con `case` o `default`. Se aplica al guardar o con
`Espacio cf`; un `.clang-format` o `_clang-format` del proyecto tiene prioridad.
La alineación de `break;` es un ajuste de Neovim, no de `clang-format` al ejecutarlo solo.

## Núcleo y componentes opcionales

El entorno está orientado al desarrollo HDL. Una instalación normal incluye
Verilog/SystemVerilog, VHDL, Python y C/C++; no requieren flags adicionales.

| Parte del núcleo | Herramientas incluidas |
|---|---|
| Terminal y Git | Zsh, Oh My Zsh y sus plugins, Kitty, Git, GitHub CLI y Serie |
| Utilidades | ripgrep, fd, fzf, tree, portapapeles X11/Wayland e Iosevka Nerd Font |
| C/C++ | GCC/G++, Make, CMake, Ninja, Bear, clangd, clang-format, GDB y CodeLLDB |
| HDL | Icarus Verilog/vvp, GHDL, GTKWave, Verible y VHDL LS |
| Python | Python 3, soporte para entornos virtuales, Pyright, Ruff y debugpy; Node/npm para Pyright |
| Neovim | Plugins fijados, parsers de Tree-sitter y herramientas auxiliares para Lua y shell |

AVR, RISC-V, Docker, Apache y OpenSSH son opcionales y se añaden mediante
`--with-avr`, `--with-riscv`, `--with-docker`, `--with-apache` y `--with-ssh`.
Su selección se conserva al repetir `install` o ejecutar `update`; omitir un
flag no desinstala ni desactiva un componente ya seleccionado.

La integración con GNOME depende de la sesión activa. Configura Kitty cuando
detecta GNOME y se omite en otros entornos; no instala el escritorio. La opción
`--with-gnome` se conserva como alias de compatibilidad. HDL y Python forman
parte del núcleo, por lo que no existen `--with-hdl` ni `--with-python`.

El inventario de módulos, sus dependencias y la revisión de duplicaciones se
documentan en [setup/README.md](setup/README.md).

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

Los parsers de Treesitter se compilan de uno en uno, tanto durante la instalación
como al actualizar el plugin desde Lazy, para reducir el consumo simultáneo de memoria.

Para añadir componentes opcionales:

```bash
dotfiles install --with-avr
dotfiles install --with-riscv
dotfiles install --with-docker
dotfiles install --with-apache --with-ssh
```

En sesiones GNOME, `dotfiles install` y `dotfiles update` configuran automáticamente
el atajo `Ctrl+T` para abrir Kitty, sin borrar otros atajos personalizados ni
duplicar su entrada. En otros escritorios se omite este paso; no se instala GNOME.
La opción antigua `--with-gnome` sigue aceptándose por compatibilidad, pero ya
no es necesaria.

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

### Estado compartido entre ramas

Se admiten los formatos de estado 1 a 4. La selección `stm32` del formato 4
se conserva al instalar o actualizar desde `main`, para seguir utilizándola
en la rama de integración STM32.

Si una versión anterior muestra `Versión de estado no soportada`, descarga
primero la corrección con Git, porque `dotfiles update` lee el estado antes
de sincronizar el repositorio. Desde `main`:

```bash
git pull --ff-only
bash bin/dotfiles install --migrate-state
```

La migración respalda el estado cuando la revisión aplicada pertenece a una
rama divergente o a otro historial y conserva los componentes opcionales.
`dotfiles check` incluye pruebas de lectura, escritura y migración del estado.

## Comandos

| Comando | Uso |
|---|---|
| `dotfiles help` | Ver comandos y opciones |
| `dotfiles update` | Actualizar el repositorio y sus componentes |
| `dotfiles doctor` | Revisar enlaces y herramientas instaladas |
| `dotfiles check` | Comprobar sintaxis y configuración |
| `dotfiles link` | Aplicar los enlaces de configuración |

### Grafo de Git desde la terminal

Serie forma parte de la instalación predeterminada y de `dotfiles update`.
Se descarga el binario oficial para Linux x86_64 o ARM64, se comprueban su
SHA-256 y versión, y se instala en `~/.local/bin/serie`. Las versiones se
administran en `setup/versions.sh`; `dotfiles doctor` comprueba Serie.

Dentro de un repositorio Git, ejecuta:

```zsh
glpick
```

| Tecla | Acción |
|---|---|
| `↑` / `↓` o `j` / `k` | Recorrer los commits |
| `Enter` | Consultar el detalle del commit |
| `Tab` | Abrir la lista de referencias |
| `/` | Buscar |
| `q` | Regresar a la terminal |

`glpick` acepta opciones de Serie, por ejemplo `glpick --max-count 500`.
El grafo usa el protocolo gráfico de la terminal; ejecútalo en Kitty u otra
[terminal compatible](https://lusingander.github.io/serie/getting-started/compatibility.html).

### Aplicaciones STM32 desde Zsh

| Comando | Acción |
|---|---|
| `cubeide` | Abrir STM32CubeIDE como usuario normal |
| `cubeprog` | Abrir STM32CubeProgrammer con `sudo` |

Las aplicaciones deben estar instaladas. `cubeide` busca `stm32cubeide` en el
`PATH`, en `/opt/st/stm32cubeide*/` y en `~/st/stm32cubeide*/`.
`cubeprog` utiliza
`~/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32CubeProgrammer`.
Ambos conservan la salida en la terminal y aceptan argumentos adicionales.

Si tu instalación está en otra ubicación, puedes indicar el ejecutable completo:

```zsh
STM32_CUBEIDE_GUI="/ruta/STM32CubeIDE/stm32cubeide" cubeide
STM32_PROGRAMMER_GUI="/ruta/STM32CubeProgrammer/bin/STM32CubeProgrammer" cubeprog
```

## Organización

- `config/`: archivos de Zsh, Kitty, Neovim y Ruff.
- `setup/`: módulos de instalación y versiones de herramientas.
- `bin/`: comandos `dotfiles`, `check` y `doctor`.
- `lib/`: funciones compartidas por el instalador.

