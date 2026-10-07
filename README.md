# GUTS Dotfiles

Configuración personal para un entorno de desarrollo en Debian y Ubuntu. Incluye Zsh, Kitty y Neovim, además de un instalador que prepara herramientas y enlaza las configuraciones.

## Qué incluye

- Configuración de Zsh y Kitty.
- Neovim con herramientas para C/C++, Python, Verilog/SystemVerilog y VHDL.
- Desde Neovim puedes compilar y ejecutar proyectos C/C++, depurar C/C++ y Python, y simular proyectos HDL.
- Opciones de instalación para RISC-V, Docker e integración con GNOME.

## Instalación

Requiere Git e Internet. Ejecuta el instalador como usuario normal; puede pedir permisos para instalar paquetes.

```bash
git clone https://github.com/Sudo-Guts/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
bash bin/dotfiles install
```

Abre una terminal nueva al terminar. Si el instalador reemplaza una configuración existente, guarda una copia de respaldo junto al archivo original. No ejecuta una actualización general del sistema.

Para añadir componentes opcionales:

```bash
dotfiles install --with-riscv
dotfiles install --with-docker
dotfiles install --with-gnome
```

El shell predeterminado solo cambia si se solicita con `--change-shell`.

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

