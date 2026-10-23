# GUTS Dotfiles

Configuración personal para un entorno de desarrollo en Debian y Ubuntu. Incluye Zsh, Kitty y Neovim, además de un instalador que prepara herramientas y enlaza las configuraciones.

## Qué incluye

- Configuración de Zsh y Kitty.
- Neovim con herramientas para C/C++, Python, Verilog/SystemVerilog y VHDL.
- Desde Neovim puedes compilar y ejecutar proyectos C/C++, depurar C/C++ y Python, y simular proyectos HDL.
- Opciones de instalación para STM32/Ophyra, AVR/ATmega, RISC-V, Docker, GNOME, Apache y OpenSSH.

En C/C++, el estilo predeterminado usa cuatro espacios y alinea los `break;`
directos de cada caso con `case` o `default`. Se aplica al guardar o con
`Espacio cf`; un `.clang-format` o `_clang-format` del proyecto tiene prioridad.
La alineación de `break;` es un ajuste de Neovim, no de `clang-format` al ejecutarlo solo.

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
dotfiles install --with-stm32
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

### STM32 / Ophyra por USB DFU

Esta integración reutiliza los proyectos **GNU Arm GCC de STM32CubeIDE**
(`.project` y `.cproject`), incluso dentro de `C0DE/ophyra/voxid/`. Conserva
`Core/`, `Drivers/`, `.ioc`, startup, enlazador, includes y flags del proyecto.
CubeIDE sigue administrando la compilación; CubeMX configura pines y periféricos.
No necesitas mover archivos ni crear otro Makefile. Los proyectos CMake siguen
usando su flujo C/C++ existente; este puente está dedicado a los proyectos
administrados por CubeIDE.

Instala STM32CubeIDE y STM32CubeProgrammer desde ST y después ejecuta:

```bash
dotfiles install --with-stm32
```

La opción prepara `make`, `bear`, `libusb-1.0-0` y, si faltan, los encabezados
básicos correspondientes a tu versión de clangd. Reutiliza GNU Arm incluido en
CubeIDE y conserva la selección en próximas actualizaciones.
No descarga otro SDK ni instala plugins nuevos de Neovim.

Se buscan las herramientas en PATH, `/opt/st/stm32cubeide*`, `~/st/stm32cubeide*`,
`~/STMicroelectronics/STM32Cube/STM32CubeProgrammer/` y
`/opt/st/stm32cubeprogrammer/`. Para una instalación en otra ruta, agrega a
`~/.zshrc.local` las rutas completas, ajustándolas a tu computadora:

```bash
export STM32_CUBEIDE="/ruta/stm32cubeide/headless-build.sh"
export STM32_PROGRAMMER_CLI="/ruta/STM32CubeProgrammer/bin/STM32_Programmer_CLI"
# Solo si GNU Arm está separado de CubeIDE:
export STM32_ARM_GCC="/ruta/gnu-arm/bin/arm-none-eabi-gcc"
```

Abre una terminal nueva y comprueba `dotfiles doctor`. CubeProgrammer debe
funcionar como usuario normal con sus reglas USB oficiales; la carga desde
Neovim no ejecuta sudo ni cambia permisos de dispositivos.

Abre un `.c` dentro del proyecto CubeIDE. Su `.cproject` define la raíz, aunque
exista otro Makefile en `C0DE/`. Empieza con `Espacio rt` para elegir Debug o
Release y luego `Espacio rg` para preparar `gd`:

| Atajo | Acción STM32 |
|---|---|
| `Espacio rp` | Panel y rutas de herramientas |
| `Espacio rt` | Elegir una configuración existente de CubeIDE |
| `Espacio rg` | Recompilar esa configuración con CubeIDE y Bear; generar el índice |
| `Espacio rc` | Compilar y convertir el ELF resultante a Intel HEX |
| `Espacio rf` | Compilar, elegir una placa DFU y grabar con verificación |
| `Espacio rl` | Salida en vivo y errores |
| `Espacio rx` | Cancelar el proceso y sus hijos |

La selección queda en `.nvim/cpp.json`; no hay que escribir los flags a mano.
El workspace de compilación queda en `${XDG_STATE_HOME:-~/.local/state}/dotfiles/stm32/`,
separado del workspace gráfico de CubeIDE. `rg` usa `-cleanBuild` y reemplaza
`compile_commands.json` solo si la recompilación y la captura de comandos terminan
bien. Vuelve a preparar el índice al cambiar configuración, includes o fuentes.
El índice omite únicamente `-fcyclomatic-complexity`, un flag de informes de ST
que clangd no reconoce; las opciones de compilación de CubeIDE se conservan.
El `.hex` queda junto al `.elf` de la configuración elegida.

La grabación DFU de esta versión está limitada al **STM32F407VG de Ophyra**.
Primero entra en modo DFU como lo haces con CubeProgrammer; `rf` muestra el número
de serie incluso si hay una sola placa y vuelve a comprobarlo antes de grabar.
Valida el HEX dentro de la Flash interna y verifica la escritura. No solicita
borrado total ni modifica option bytes. Después sal del modo DFU y reinicia como
de costumbre. USB DFU no permite los puntos de interrupción de `F5`/`F9`; esa
depuración requiere una sonda SWD como ST-Link.

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

