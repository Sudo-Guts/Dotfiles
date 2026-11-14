# Plataforma y preflight

La deteccion central prepara la portabilidad del bootstrap. No constituye
soporte completo de Arch ni certifica todas las versiones de Debian/Ubuntu.

## Interfaz

`lib/platform.sh` requiere las funciones de `lib/common.sh`. Cargarla no lee el
sistema ni crea archivos. Expone:

- `dotfiles_platform_detect [primary] [fallback] [architecture]`: identifica el
  sistema, devuelve 0 si los datos son validos o 1 con
  `DOTFILES_PLATFORM_ERROR`. No termina el proceso ni escribe archivos.
- `dotfiles_platform_report`: muestra los datos detectados.
- `dotfiles_platform_preflight install|update|link`: comprueba la operacion y
  termina con un error claro si no puede continuar. No instala herramientas.

Sin argumentos, la deteccion usa `/etc/os-release`, con
`/usr/lib/os-release` como alternativa solo si el primero no existe.
Un archivo principal invalido, ilegible o un enlace roto causa error; no se
mezclan datos de ambos archivos. La arquitectura procede de `uname -m`.

Los resultados son `DOTFILES_PLATFORM_ID`, `DOTFILES_PLATFORM_NAME`,
`DOTFILES_PLATFORM_VERSION`, `DOTFILES_PLATFORM_ARCH`,
`DOTFILES_PLATFORM_PACKAGE_FAMILY`, `DOTFILES_PLATFORM_ID_LIKE` y
`DOTFILES_PLATFORM_OS_RELEASE`. Los campos `DOTFILES_PLATFORM_VERSION_CODENAME`
y `DOTFILES_PLATFORM_UBUNTU_CODENAME` conservan la seleccion del repositorio
Docker existente. Cada deteccion reinicia los resultados anteriores.

Solo los ID `arch`, `ubuntu` y `debian` estan reconocidos para operaciones con
efectos persistentes. Una derivada conserva su ID real y `ID_LIKE` como dato
informativo; no hereda soporte. `VERSION_ID` es opcional, incluido Arch.

El lector valida asignaciones y los campos utilizados, admite comillas simples
y dobles y decodifica escapes de comillas dobles. No usa `source` ni `eval`,
no expande variables ni ejecuta sustituciones. Ignora claves desconocidas y
conserva el ultimo valor si una clave se repite. Rechaza bytes NUL, controles
en los valores utilizados y campos incompletos o mal formados.

Referencia del formato:
[os-release de systemd](https://www.freedesktop.org/software/systemd/man/latest/os-release.html).

## Politica por comando

| Comando | Ubuntu/Debian | Arch | ID desconocido o derivada |
|---|---|---|---|
| `install`, `update` | Preflight APT y flujo existente | Rechazo temprano por GHDL obligatorio sin proveedor aprobado y validado | Rechazo antes de escribir |
| `link` | Enlaces y respaldos existentes | Permitido sin backend de paquetes | Rechazado |
| `doctor` | Informa plataforma y conserva diagnostico | Usa comandos Arch y registra modulos pendientes | Informa falta de soporte y conserva diagnostico |
| `help`, `--help` | Sin requisito de plataforma | Sin requisito de plataforma | Sin requisito de plataforma |
| `check` | Comprobaciones existentes y nuevas | No exige backend | No exige backend |

En `bin/dotfiles`, el preflight sigue al parser y a la proteccion de root;
precede a la carga de enlaces, el bloqueo del estado, la migracion, la escritura
de `pending_commit`, el `fetch` de `update` y cualquier modulo.
Las ayudas no requieren deteccion. `doctor` informa errores de deteccion como
pendientes y continua; no exige APT ni la arquitectura de los binarios core.

`install`/`update` admiten x86_64 y ARM64 (`aarch64` o `arm64`), conforme a los
artefactos existentes. Comprueban `apt-get`, `dpkg-query`, Git, flock y utilidades
basicas del bootstrap; como usuario normal requieren sudo disponible.
`--change-shell` comprueba chsh antes de escribir estado, sin ejecutarlo en el
preflight. La instalacion real de paquetes puede solicitar privilegios despues.

`link` solo exige las utilidades de rutas, enlaces y respaldos que utiliza.
No requiere Git, APT, Pacman, sudo ni una arquitectura de los binarios core.
Conserva la validacion de todos los destinos, los respaldos y la recuperacion
por destino de `lib/links.sh`.

El preflight no requiere Neovim, Zsh, curl, GCC, Python, Node ni simuladores:
su instalacion corresponde a los modulos. Tampoco valida conectividad,
credenciales sudo, disponibilidad remota ni toda la ejecucion futura. El estado
pendiente y la recuperacion existentes siguen cubriendo fallos posteriores.

El esquema de estado sigue en 4; no cambian flags, seleccion de opcionales,
`--migrate-state`, `--change-shell` ni versiones fijadas. Docker reutiliza la
deteccion central y conserva la prioridad de `UBUNTU_CODENAME` en Ubuntu.

## Pruebas reproducibles

```bash
python3 tests/platform.py
python3 tests/install.py
bash bin/dotfiles check
git diff --check
```

`check` incorpora las pruebas nuevas y conserva las anteriores. ShellCheck,
Zsh y Neovim deben estar disponibles para ejecutar sus comprobaciones;
un aviso de omision no equivale a una prueba superada.

Las pruebas de plataforma usan archivos y repositorios temporales. La
inyeccion se realiza mediante parametros de la biblioteca y sustitucion de
rutas exclusivamente en copias de prueba. La CLI de produccion no acepta
variables de entorno ni flags para reemplazar os-release o sus resultados.

Se cubren Arch, Ubuntu, Debian, derivadas, archivos ausentes/invalidos,
precedencia del archivo principal, escapes sin ejecucion, arquitecturas,
repeticion y requisitos minimos. Los rechazos comparan contenido, enlaces,
permisos y fechas de modificacion de la copia completa, incluida `.git`.
Los sustitutos registran cualquier llamada inesperada a gestores, Git,
privilegios o comandos de escritura.

Las regresiones de instalacion fijan datos Ubuntu o Debian en sus copias y
usan sustitutos APT/modulos. Comprueban ambos flujos de actualizacion,
persistencia de opcionales, esquemas antiguos, interrupcion y reanudacion,
deduplicacion, diagnostico y Docker con las dos distribuciones.
No sustituyen una instalacion real ni certifican paquetes disponibles.

## Limites y siguiente fase

El backend Pacman y las equivalencias Arch estan implementados y probados con
simulaciones; consulta [gestion de paquetes](PACKAGES.md). No hay proveedor
GHDL aprobado y validado. Neovim, toolchains, shell, temas y almacenamiento
conservan su configuracion.

Antes de habilitar Core en Arch se debe resolver GHDL y validar todos los
modulos/proveedores seleccionados antes de escribir estado o crear enlaces.
Faltan pruebas de instalacion/repeticion/recuperacion y herramientas reales.
Docker y RISC-V conservan sus bloqueos por adaptacion pendiente. La politica
Pacman deja el mantenimiento completo al usuario y solo solicita faltantes.
No se resuelve esta espera ejecutando APT en Arch ni introduciendo
actualizaciones parciales con Pacman.
