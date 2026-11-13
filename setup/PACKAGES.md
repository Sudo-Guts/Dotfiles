# Gestion de paquetes: Fase 3.1

La fachada separa las solicitudes de paquetes del detalle APT. El unico backend
implementado es APT para Ubuntu y Debian. Arch se reconoce y se rechaza antes
de ejecutar operaciones de paquetes. No se modifica el catalogo ni el estado.

## Responsabilidades e interfaces

| Archivo | Responsabilidad |
|---|---|
| `lib/common.sh` | Entorno, logging, errores, privilegios, descargas, versiones, Git y compatibilidad de nombres |
| `lib/packages.sh` | Interfaz comun, resolucion de paquetes del modulo y validacion de plataforma |
| `lib/packages/apt.sh` | Detalle de dpkg-query, apt-get y marcadores |
| `lib/modules.sh` | Catalogo, seleccion logica y dependencias; sin cambios |
| `lib/platform.sh` | Identificacion central; reutilizada sin duplicar el lector |

Cargar common.sh deja disponibles las interfaces sin detectar el sistema ni
invocar gestores. Los modulos actuales conservan sus llamadas:

- `apt_install` delega en `dotfiles_packages_install`.
- `apt_install_module` delega en `dotfiles_packages_install_module`.

La nueva interfaz recibe nombres nativos del backend o un modulo existente:

```bash
source lib/common.sh
dotfiles_packages_install curl
dotfiles_packages_install_module cpp
```

Estos ejemplos realizan instalaciones; las pruebas los sustituyen por mocks.
El backend usa `as_root` de common.sh. No hay una segunda politica de sudo.
La resolucion de paquetes no activa opcionales ni cambia sus dependencias.
Un modulo sin paquetes no ejecuta APT. Un modulo desconocido produce error.

Antes de una solicitud se utiliza `dotfiles_platform_detect`. No se acepta
`ID_LIKE` como habilitacion de derivadas ni se confia en un backend indicado por
variables del entorno. La validacion tambien protege las funciones historicas
cuando se usan fuera de la CLI.

El preflight de la Fase 2 sigue siendo la primera barrera de install/update,
anterior a bloqueo, estado, enlaces y sincronizacion Git. link sigue siendo
independiente del gestor; doctor y check mantienen sus contratos.

## Semantica APT

| Situacion | Comportamiento |
|---|---|
| Paquete instalado, operacion normal | No se reinstala ni se refresca el indice |
| Paquete ausente o sin configurar | Se solicita instalacion con `-y --no-install-recommends` |
| Solicitud sin paquetes | No hay refresco ni instalacion |
| `DOTFILES_UPDATE=1` | Se reconcilian los paquetes solicitados; no se actualiza todo el SO |
| Paquete ya procesado en esta ejecucion | Se omite, tambien durante update |
| Paquetes repetidos en la misma llamada | Se conserva la primera aparicion y su orden |
| Fallo de refresco | Se devuelve el error sin marcar el indice ni ejecutar install |
| Fallo de instalacion | Se devuelve el error sin registrar los paquetes |
| Reintento tras refresco exitoso e install fallido | Se reutiliza el indice y se reintenta la instalacion |

Se conservan `DOTFILES_APT_STAMP` y `DOTFILES_APT_PACKAGES`. La CLI sigue
creando sus rutas temporales por ejecucion y eliminandolas al terminar.
Los modulos hijos comparten esos archivos; no se introducen caches globales
en memoria, un nuevo esquema de estado ni nuevos directorios persistentes.
Sin marcadores, las llamadas independientes conservan el comportamiento
anterior: consultan dpkg y, si necesitan instalar, refrescan el indice.

Docker sigue invalidando DOTFILES_APT_STAMP cuando cambia su repositorio.
Su codigo, claves, servicios y grupos permanecen sin cambios.
RISC-V conserva tanto la solicitud por modulo como sus dependencias APT
adicionales para --source, sin cambiar compilacion, prefijos ni versiones.

## Correcciones acotadas

La extraccion conserva los casos validos y corrige errores reproducidos:

1. La lista antigua podia repetir paquetes en una sola llamada antes de
   escribir el registro compartido. Ahora se deduplica tambien dentro de ella.
2. Errexit no garantiza el corte cuando una funcion se usa desde un if.
   Los errores de APT y de escritura de marcadores se devuelven expresamente.
3. dpkg-query con codigo 1 indica ausencia; otros fallos se propagan antes
   de instalar. Un error fatal ya no se confunde con un paquete ausente.
4. Se rechaza un nombre de paquete vacio sin ejecutar APT.
5. El diagnostico comun admite BASH_SOURCE vacio en bash -c, conservando
   el codigo de error en ese contexto.

Referencia de los codigos dpkg:
[dpkg-query, EXIT STATUS](https://manpages.debian.org/trixie/dpkg/dpkg-query.1.en.html#EXIT_STATUS).

## Verificacion

```bash
python3 tests/packages.py
python3 tests/platform.py
python3 tests/install.py
bash bin/dotfiles check
git diff --check
```

Las pruebas de paquetes usan archivos temporales y sustitutos de dpkg-query,
apt-get y as_root. Cubren ambos nombres historicos, la interfaz comun, peticiones
vacias/repetidas, paquetes compartidos, fallos, reintentos, update y rechazos de
Arch/derivadas. Los casos RISC-V ejecutan el modulo real con APT simulado;
--source se detiene antes de clonar o compilar.

Las regresiones Docker preparan un marcador previo y comprueban su invalidacion
en Debian y Ubuntu. La bateria general conserva las pruebas de estado, flags,
enlaces, CLI, preflight y Neovim.

Las simulaciones no certifican una instalacion real. Las comprobaciones
omitidas deben registrarse; no equivalen a resultados satisfactorios.

## Limites para la siguiente fase

Los nombres del catalogo y los argumentos historicos siguen siendo APT.
La futura ruta Arch debe resolver sus propios paquetes y comandos, y definir
su politica de actualizacion. Esta fachada no traduce nombres ni implementa
Pacman, AUR, proveedores HDL, perfiles o configuracion de escritorio.

El bootstrap continua usando su bloqueo global; no se introdujo coordinacion
de gestores concurrentes ni una transaccion para revertir paquetes instalados.
