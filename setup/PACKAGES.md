# Gestion de paquetes: APT y Pacman

La fachada selecciona APT en Ubuntu/Debian y Pacman en Arch mediante
`lib/platform.sh`. El backend Pacman esta implementado y probado con
simulaciones. Esto no habilita la instalacion Core en Arch: GHDL sigue siendo
obligatorio y su proveedor esta pendiente de aprobacion y validacion.

## Responsabilidades e interfaces

| Archivo | Responsabilidad |
|---|---|
| `lib/common.sh` | Entorno, privilegios e interfaces historicas |
| `lib/packages.sh` | Seleccion del backend y resolucion de paquetes/comandos por modulo |
| `lib/packages/apt.sh` | dpkg-query, apt-get y marcadores APT; sin cambios en esta fase |
| `lib/packages/pacman.sh` | Consulta de dependencias y solicitud de paquetes faltantes |
| `lib/modules.sh`, `setup/modules.conf` | Identidad, seleccion, dependencias, orden y datos historicos APT |
| `setup/packages/arch.conf` | Diferencias de paquetes/comandos y estado de disponibilidad en Arch |
| `lib/platform.sh` | Deteccion central y preflight temprano |

Cargar common.sh solo define funciones. No detecta el sistema ni invoca gestores.
Las solicitudes publicas son:

- `dotfiles_packages_install paquetes...`: nombres nativos de la distribucion
  detectada, sin traduccion de argumentos.
- `dotfiles_packages_install_module modulo`: resuelve el catalogo de esa
  distribucion, sin activar opcionales ni resolver otro grafo.
- `apt_install paquetes...`: compatibilidad exclusiva con APT. Rechaza Arch,
  incluso con lista vacia, antes de ejecutar un gestor.
- `apt_install_module modulo`: alias historico de la solicitud por modulo;
  admite Arch cuando el modulo tiene paquetes nativos definidos.

`dotfiles_packages_resolve_module modulo` permite consultar sin instalar.
Deja `DOTFILES_RESOLVED_PACKAGES` (array), `DOTFILES_RESOLVED_COMMANDS`,
`DOTFILES_RESOLVED_STATE` y `DOTFILES_RESOLVED_REASON`. No modifica estado.
Los resultados de plataforma se detectan de nuevo; una variable del entorno
no puede habilitar un gestor ni una distribucion derivada.

## Catalogo Arch

Formato de cinco campos separados por `|`:

```text
modulo|estado|paquetes|comandos distintos de doctor|motivo o mecanismo
```

`native` exige paquetes no vacios. `none` exige paquetes vacios y un
mecanismo explicado. `pending` exige un motivo y puede registrar paquetes
conocidos como candidatos; no instala ninguno ni informa exito.

Comandos vacios heredan `setup/modules.conf`. Un campo no vacio reemplaza la
lista de diagnostico, con el formato existente `comando[:/ruta/alternativa]`.
El lector valida campos, controles, nombres, duplicados, estados, paquetes y
comandos. No ejecuta el archivo. Una entrada ausente causa error al solicitar
el modulo; no significa `none`. El catalogo no repite tipo ni dependencias.

### Matriz de compatibilidad Arch

"Adaptado" significa paquetes y comandos resueltos con pruebas simuladas.
Ninguna fila certifica ejecucion real ni una instalacion completa de Arch.

| Modulo | Estado del catalogo | Alcance y limitacion |
|---|---|---|
| base | native; adaptado | fd, xz y python reemplazan los nombres APT |
| git | native; adaptado | github-cli proporciona gh |
| zsh | native; adaptado | zsh, fzf y git; plugins existentes sin cambios |
| cpp | native; adaptado | gcc, make, bear, cmake, ninja, pkgconf, clang, gdb |
| python | native; adaptado | python con venv/ensurepip, nodejs y npm |
| apache | native; adaptado | apachectl; servicio httpd administrado por el usuario |
| ssh | native; adaptado | openssh proporciona sshd; servicio administrado por el usuario |
| avr | native; adaptado | avr-gcc, avr-binutils, avr-libc, avrdude y make; toolchain sin cambios |
| serie | none; disponible sin probar | Instalador upstream fijado existente |
| kitty | none; disponible sin probar | Instalador upstream fijado existente |
| nvim | none; disponible sin probar | Instalador upstream fijado existente |
| fonts | none; disponible sin probar | Archivo upstream fijado existente |
| treesitter-cli | none; disponible sin probar | Instalador upstream fijado existente |
| gnome | none; disponible sin probar | Integra una sesion GNOME activa; no instala GNOME |
| nvim-tools | none; disponible sin probar | Preparacion existente; Mason/servidores/parsers sin validar en Arch |
| hdl | pending; proveedor obligatorio | Icarus/GTKWave oficiales verificados; falta GHDL aprobado y comprobado |
| riscv | pending; contrato incompatible aun | Prefijo riscv64-elf, frente a riscv64-unknown-elf; depuracion pendiente |
| docker | pending; instalador no portado | Paquetes oficiales identificados; script actual exclusivo APT |

### Equivalencias verificadas

Se consultaron metadatos y listas de archivos de los repositorios oficiales
core/extra para x86_64 y any. Son evidencia de empaquetado, no pruebas de
ejecucion ni una politica de versiones fijadas para Arch.

| Ubuntu/Debian | Arch oficial | Capacidad comprobada |
|---|---|---|
| fd-find | [fd](https://archlinux.org/packages/extra/x86_64/fd/files/) | usr/bin/fd |
| xz-utils | [xz](https://archlinux.org/packages/core/x86_64/xz/files/) | usr/bin/xz |
| gh | [github-cli](https://archlinux.org/packages/extra/x86_64/github-cli/files/) | usr/bin/gh |
| python3, python3-venv | [python](https://archlinux.org/packages/core/x86_64/python/files/) | python, python3, venv, ensurepip y rueda pip incluida |
| build-essential | [gcc](https://archlinux.org/packages/core/x86_64/gcc/), [make](https://archlinux.org/packages/core/x86_64/make/) | gcc/g++; gcc depende de binutils y glibc, que incluyen ld y encabezados C |
| ninja-build | [ninja](https://archlinux.org/packages/extra/x86_64/ninja/files/) | usr/bin/ninja |
| pkg-config | [pkgconf](https://archlinux.org/packages/core/x86_64/pkgconf/files/) | usr/bin/pkg-config |
| clangd, clang-format | [clang](https://archlinux.org/packages/extra/x86_64/clang/files/) | Ambos binarios en el mismo paquete |
| nodejs, npm | [nodejs](https://archlinux.org/packages/extra/x86_64/nodejs/), [npm](https://archlinux.org/packages/extra/any/npm/) | Entorno Node y gestor npm oficiales |
| iverilog | [iverilog](https://archlinux.org/packages/extra/x86_64/iverilog/files/) | usr/bin/iverilog y usr/bin/vvp |
| gtkwave | [gtkwave](https://archlinux.org/packages/extra/x86_64/gtkwave/files/) | usr/bin/gtkwave |
| gcc-riscv64-unknown-elf | [riscv64-elf-gcc](https://archlinux.org/packages/extra/x86_64/riscv64-elf-gcc/files/) | usr/bin/riscv64-elf-gcc; prefijo distinto |
| binutils-riscv64-unknown-elf | [riscv64-elf-binutils](https://archlinux.org/packages/extra/x86_64/riscv64-elf-binutils/files/) | usr/bin/riscv64-elf-objdump; prefijo distinto |
| qemu-system-misc | [qemu-system-riscv](https://archlinux.org/packages/extra/x86_64/qemu-system-riscv/files/) | qemu-system-riscv32 y qemu-system-riscv64 |
| gdb-multiarch | [gdb](https://archlinux.org/packages/extra/x86_64/gdb/) como candidato | No se afirma equivalencia para depurar RISC-V; falta validacion |
| gcc-avr, binutils-avr | [avr-gcc](https://archlinux.org/packages/extra/x86_64/avr-gcc/files/), [avr-binutils](https://archlinux.org/packages/extra/x86_64/avr-binutils/files/) | avr-gcc, avr-objcopy, avr-size, avr-objdump |
| avr-libc, avrdude | [avr-libc](https://archlinux.org/packages/extra/any/avr-libc/files/), [avrdude](https://archlinux.org/packages/extra/x86_64/avrdude/files/) | avr/io.h y usr/bin/avrdude |
| apache2 | [apache](https://archlinux.org/packages/extra/x86_64/apache/files/) | apachectl, httpd y httpd.service |
| openssh-server | [openssh](https://archlinux.org/packages/core/x86_64/openssh/files/) | sshd y sshd.service |
| Docker CE, CLI, Buildx y Compose | [docker](https://archlinux.org/packages/extra/x86_64/docker/files/), [docker-buildx](https://archlinux.org/packages/extra/x86_64/docker-buildx/files/), [docker-compose](https://archlinux.org/packages/extra/x86_64/docker-compose/files/) | docker/dockerd y plugins docker-buildx/docker-compose; candidatos pendientes |

No se agrega python-pip global: el paquete python inspeccionado contiene venv,
ensurepip y su rueda pip; las herramientas del editor conservan su instalador.
Los paquetes auxiliares del catalogo tambien se verificaron en la
[busqueda oficial](https://archlinux.org/packages/). El mapeo de C/C++ cubre
las herramientas del modulo; no pretende replicar todos los usos de
build-essential. No se modifican Makefiles, prefijos ni la configuracion DAP.

## Politica Pacman

El usuario mantiene Arch coherente mediante una actualizacion completa
explicita, siguiendo [System maintenance](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported).
El bootstrap depende de esa base y no puede demostrar que todo el sistema
esta actualizado o integro.

Comandos del backend, en install y con `DOTFILES_UPDATE=1`:

```text
pacman -T -- paquetes-unicos...
as_root pacman -S --needed -- paquetes-faltantes...
```

La consulta no requiere privilegios. `-T` admite dependencias satisfechas por
un proveedor instalado. Codigo 0 sin salida significa satisfechas; 127 con
la lista de faltantes permite instalar. Otros errores se propagan. Una
respuesta inconsistente o ajena a la solicitud se rechaza. Se conserva el
orden original de los faltantes y se deduplica cada solicitud.

La instalacion usa `as_root` y `--needed`, conservando la confirmacion de
Pacman. Una lista vacia o satisfecha no instala nada. Los errores y bloqueos
se devuelven sin borrar la BD ni db.lck. No hay marcadores Pacman: cada
reintento consulta la BD local y solicita solo lo que falta, incluso entre
procesos de distintos modulos.

`update` actualiza los dotfiles; en Pacman solo reconcilia dependencias
faltantes. No reinstala ni actualiza selectivamente paquetes ya satisfechos.
Esta semantica difiere de APT y no transporta su modo de reconciliacion.

No se ejecutan refrescos, actualizaciones generales ni sus equivalentes:
`-Sy`, `-Syy`, `-Syu`, `--refresh`, `--sysupgrade` o secuencias de
sincronizacion seguidas de instalacion. Tampoco se usa `--noconfirm`,
AUR, helpers, eliminacion de bloqueos ni reparacion automatica de bases.

Fuentes primarias: [manual pacman(8)](https://man.archlinux.org/man/pacman.8.en)
y [pacman_deptest, version 7.1.0](https://gitlab.archlinux.org/pacman/pacman/-/blob/v7.1.0/src/pacman/deptest.c).
La segunda fuente documenta en codigo la distincion 0/127.

## Semantica APT conservada

| Situacion | Comportamiento |
|---|---|
| Paquete instalado, operacion normal | No se reinstala ni se refresca el indice |
| Paquete ausente o sin configurar | Instalacion con -y --no-install-recommends |
| Solicitud sin paquetes | Sin refresco ni instalacion |
| DOTFILES_UPDATE=1 | Reconciliacion de los paquetes solicitados, una vez por ejecucion |
| Paquete ya procesado | Se omite tambien durante update |
| Argumentos repetidos | Primera aparicion y su orden |
| Error de consulta distinto de 1 | Se propaga sin instalar |
| Fallo de refresco | Sin marcador ni install |
| Fallo de instalacion | Sin registro del paquete; reintento permitido |

Se conservan `DOTFILES_APT_STAMP` y `DOTFILES_APT_PACKAGES`, su limpieza
por la CLI y su uso compartido entre procesos. Docker sigue invalidando el
marcador al cambiar su repositorio. RISC-V mantiene ambas rutas APT existentes.
El archivo `lib/packages/apt.sh` permanece identico a la Fase 3.1.

La extraccion previa corrigio duplicados, propagacion expresa de errores aun
dentro de un if, errores fatales de dpkg-query, nombres vacios y BASH_SOURCE
vacio. Referencia: [dpkg-query, EXIT STATUS](https://manpages.debian.org/trixie/dpkg/dpkg-query.1.en.html#EXIT_STATUS).

## Preflight, diagnostico y pruebas

La CLI mantiene el rechazo temprano de install/update en Arch por GHDL antes
del bloqueo, carga o migracion del estado, enlaces y fetch. No se habilita la
ruta completa por disponer del backend. link sigue siendo independiente del
gestor. doctor usa los comandos Arch de los modulos seleccionados y registra
los pendientes aunque encuentre sus binarios; no instala paquetes.

```bash
python3 tests/packages.py
python3 tests/pacman.py
python3 tests/platform.py
python3 tests/install.py
bash bin/dotfiles check
git diff --check
```

Las pruebas sustituyen gestores y privilegios en copias temporales. Cubren
idempotencia, proveedores, paquetes compartidos, errores, reintentos, modo
update, catalogo invalido, comandos Arch, compatibilidad historica y rechazos
sin efectos. La bateria general conserva estado, enlaces, CLI, flags,
Docker/RISC-V APT y las comprobaciones disponibles de Neovim. No instala
paquetes reales. Las omisiones se registran en la entrega.

## Pendientes para habilitar Core Arch

Aprobar y verificar GHDL sin volverlo opcional; validar previamente todos los
modulos/proveedores seleccionados antes de cualquier escritura; probar los
instaladores upstream, Mason y herramientas reales; despues realizar pruebas
Arch de instalacion limpia, repeticion, actualizacion y recuperacion.
Docker y RISC-V requieren adaptacion propia antes de habilitar sus opcionales.
No hay nueva transaccion para revertir paquetes ni coordinacion adicional
fuera del bloqueo existente del bootstrap.
