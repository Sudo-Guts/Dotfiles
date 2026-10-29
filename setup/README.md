# Núcleo y mantenimiento de Dotfiles

La terminal se orienta al desarrollo HDL y conserva Python y C/C++ dentro del
núcleo. Esta revisión documenta la base antes de reorganizar instaladores o
configuraciones de Neovim.

## Fase 1: base protegida

- [x] Continuar `refactor/dotfiles-core`, creada desde `main`, conservando sus commits previos de GNOME y pruebas.
- [x] Documentar el núcleo, la integración por entorno y los módulos opcionales.
- [x] Conservar `config/`, `bin/`, `lib/` y `setup/` como estructura principal.
- [x] Revisar duplicaciones y dependencias antes de mover o eliminar archivos.
- [x] Mantener `feature/stm32-dfu` independiente durante la reorganización.

La revisión parte de `a629c90` en `refactor/dotfiles-core`, que contiene los
ocho commits posteriores a `main` (`9bb6e79`). La integración STM32 permanece
en `feature/stm32-dfu` (`abdc2ba`); esta fase no incorpora su código. El campo
`stm32` del estado persistente sigue conservándose entre ramas.

## Responsabilidades

| Ubicación | Responsabilidad |
|---|---|
| `config/` | Configuraciones de terminal, editor y herramientas |
| `bin/` | Interfaz `dotfiles` y comandos de comprobación |
| `lib/` | Funciones compartidas, enlaces, estado y sincronización |
| `setup/` | Instaladores, versiones y preparación de Neovim |

`tests/` contiene las comprobaciones auxiliares. Esta fase añade pruebas de
protección de enlaces y respaldos sin mover las responsabilidades anteriores.

## Inventario de módulos

Los nombres corresponden a los scripts existentes en `setup/modules/`.
Esta tabla describe el comportamiento actual; no introduce otro manifiesto
ejecutable ni modifica el orden de instalación.

| Selección | Módulos | Responsabilidad y dependencias |
|---|---|---|
| Núcleo | `base` | Descargas, búsqueda, Python 3, portapapeles, fuentes y ShellCheck mediante APT |
| Núcleo | `git`, `serie` | Git/GitHub CLI y grafo interactivo; Serie se instala desde su binario oficial con SHA-256 |
| Núcleo | `zsh` | Zsh, fzf, Oh My Zsh y plugins obtenidos mediante Git |
| Núcleo | `kitty`, `fonts` | Terminal e Iosevka Nerd Font; utilizan las dependencias de descarga de `base` |
| Núcleo | `nvim` | Ejecutable local de Neovim con versión administrada |
| Núcleo | `cpp` | Compiladores, construcción, índice con Bear, clangd, formato y GDB mediante APT |
| Núcleo | `python` | Python/venv y Node/npm, requeridos para el entorno Python y Pyright |
| Núcleo | `hdl` | GHDL, GTKWave e Icarus Verilog mediante APT |
| Núcleo | `treesitter-cli` | CLI de Tree-sitter; utiliza descarga y extracción preparadas por `base` |
| Núcleo | `nvim-tools` | Restaura plugins, instala herramientas Mason y compila parsers después de preparar Neovim, C/C++, Python, HDL y Tree-sitter CLI |
| Según sesión | `gnome` | Configura el atajo de Kitty solo en GNOME; requiere Kitty, Python 3 y `gsettings` de esa sesión |
| `--with-avr` | `avr` | GCC/Binutils AVR, AVR-LibC, AVRDUDE y Make |
| `--with-riscv` | `riscv` | GCC/Binutils bare-metal, GDB multiarch y QEMU mediante APT |
| `--with-docker` | `docker` | Docker Engine, Buildx y Compose desde el repositorio oficial |
| `--with-apache` | `apache` | Servidor Apache mediante APT |
| `--with-ssh` | `ssh` | Servidor OpenSSH mediante APT |

`nvim-tools` obtiene la lista de herramientas de
`config/nvim/lua/config/nvim/tools.lua`: Lua LS, StyLua, shfmt, Verible,
VHDL LS, CodeLLDB, Pyright, Ruff y debugpy. Los parsers se declaran en
`config/nvim/lua/config/nvim/parsers.lua`. Clangd, clang-format y ShellCheck
proceden de APT. Estas responsabilidades deben conservarse al construir el
manifiesto de módulos de la fase 2.

Python 3 también ejecuta la integración GNOME y la serialización de perfiles
de C/C++ y HDL desde Neovim. Node/npm ejecutan e instalan Pyright. No se
consideran dependencias prescindibles por tener instalados otros intérpretes.

El modo `riscv.sh --source` sigue siendo una operación manual distinta del
flag público `--with-riscv`. Las funciones Zsh para KiCad, ISE y STM32 abren
aplicaciones instaladas por separado; su presencia no implica que pertenezcan
al núcleo ni que el instalador deba descargarlas.

## Duplicaciones y dependencias revisadas

| Hallazgo | Evidencia | Decisión en esta fase |
|---|---|---|
| Paquetes APT repetidos | Git y fzf aparecen en `base` y otros módulos; Python/venv en `base` y `python` | Conservarlos: `apt_install` consulta el estado y comparte un índice APT por ejecución. Centralizar sus declaraciones en la fase 2 |
| Posibles dependencias sobrantes | `wget` y el ejecutable `jq` no tienen llamadas directas identificadas en los scripts actuales; `gh --jq` es una opción de GitHub CLI | Registrar candidatos y revisar instaladores externos antes de eliminarlos |
| Comprobación local de archivos | `has` en `cpp.lua` y `project.lua` realiza la misma consulta breve | Mantener los helpers locales; extraerlos por sí solos añadiría otra dependencia entre módulos |
| Serialización de perfiles | `cpp.store` y `tasks.store_profile` utilizan `python3 -m json.tool` | Revisar una función compartida en la fase 3, conservando la diferencia entre el perfil C/C++ y los perfiles HDL combinados |
| Código Verilog/VHDL parecido | Ambos usan `tasks.project_root`, perfiles, archivos, procesos y testbenches | La infraestructura común ya se comparte. Mantener separados los índices y comandos de cada lenguaje |
| Validación de comandos | `require_command` en Bash y `dotfiles_need` en Zsh | Conservar separados: los instaladores terminan ante un fallo; el shell interactivo debe devolver el control al usuario |

La revisión no identifica todavía una eliminación segura de dependencias.
No se eliminan paquetes, archivos ni interfaces públicas por similitud visual.

## Comprobaciones y alcance

Ejecutar desde la raíz del repositorio:

```bash
bash bin/dotfiles check
```

El comando comprueba sintaxis Bash/Zsh y ejecuta las regresiones de estado,
CLI, GNOME y enlaces. Las pruebas de enlaces usan una copia temporal de los
archivos gestionados y un directorio de usuario aislado. Cubren respaldos de
archivos, directorios y enlaces rotos, rutas con espacios, un `XDG_CONFIG_HOME`
externo al directorio de usuario, dos ejecuciones consecutivas, destinos
protegidos, orígenes ausentes y recuperación si falla la creación de un enlace.
Las preferencias reales de GNOME no se modifican.

La comprobación inicial de esta fase pasó las pruebas disponibles de Bash,
Zsh, estado, CLI y GNOME. En el entorno de revisión no están instalados
ShellCheck ni Neovim; `check` avisa que omite esas comprobaciones. Esto no
equivale a validar una instalación completa, LSP, parsers, depuración o
hardware. `dotfiles check --nvim` y las pruebas de funcionamiento quedan
para un entorno con Neovim y sus herramientas instaladas.

## Siguientes fases

La fase 2 debe centralizar módulos y dependencias, conservando HDL y Python
en el núcleo y los flags existentes. No se añadirán `--with-hdl` ni
`--with-python`. La selección persistente de los opcionales y la compatibilidad
con los estados anteriores deben protegerse con las pruebas de migración.

La fase 3 debe revisar carga por lenguaje, versiones, parsers y recuperación
del editor. Incluye alinear el formato predeterminado con el estándar de
programación: cuatro espacios, llaves en la misma línea y firmas y llamadas
sin fragmentar. La configuración `.clang-format` actual todavía necesita
ese ajuste; no se cambia durante esta revisión de la base.

Las fases 4 y 5 completarán las pruebas de instalación, actualización y
funcionamiento, la limpieza respaldada por evidencia y la documentación
final antes de fusionar a `main`.
