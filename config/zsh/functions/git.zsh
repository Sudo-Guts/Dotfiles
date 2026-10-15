# =============================================================================
#   Proyecto : Dotfiles
#   Archivo  : git.zsh
#   Autor    : Gustavo Ruiz Luis
# =============================================================================
#
#   Git - Funciones para administrar repositorios locales
#
#   Requisitos:
#       - git: necesario para todas las operaciones del repositorio.
#       - fzf: necesario para los selectores interactivos.
#
#   Nota:
#       - dotfiles_need() se define en functions/utils.zsh.
#       - Este archivo se carga desde config/zsh/.zshrc.
#
# =============================================================================


# =============================================================================
#   Rama actual
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: git_branch_name
# -----------------------------------------------------------------------------
#
#   Obtiene el nombre de la rama actual del repositorio.
#
#   Oculta los mensajes de error de Git.
#   Si HEAD esta separado, no devuelve ningun nombre.
#
# -----------------------------------------------------------------------------

function git_branch_name() {
    command git branch --show-current 2>/dev/null
}


# =============================================================================
#   Commits
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: gac "mensaje"
# -----------------------------------------------------------------------------
#
#   Agrega todos los cambios del repositorio y crea un commit.
#
#   El mensaje es obligatorio y puede contener varias palabras.
#   Si git add falla, no se ejecuta git commit.
#
# -----------------------------------------------------------------------------

function gac() {
    (( $# )) || {
        print -u2 'Uso: gac "mensaje"'
        return 1
    }

    command git add --all && command git commit -m "$*"
}


# -----------------------------------------------------------------------------
#   Uso: gacp "mensaje"
# -----------------------------------------------------------------------------
#
#   Agrega los cambios, crea un commit y ejecuta git push.
#
#   Utiliza gac() para preparar y registrar los cambios.
#   El push solo se ejecuta si el commit termina correctamente.
#
#   Nota:
#       - Requiere que el push pueda resolver su destino remoto.
#
# -----------------------------------------------------------------------------

function gacp() {
    gac "$@" && command git push
}


# =============================================================================
#   Push
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: gpush [opciones]
# -----------------------------------------------------------------------------
#
#   Publica los commits locales en el repositorio remoto.
#
#   Operaciones:
#       1. Comprueba que Git este disponible.
#       2. Detecta la rama local actual.
#       3. Utiliza el upstream si ya esta configurado.
#       4. Si no existe upstream, publica en origin y lo configura.
#
#   Nota:
#       - No crea commits automaticamente.
#       - No realiza push forzado.
#       - Los argumentos adicionales se envian directamente a git push.
#
# -----------------------------------------------------------------------------

function gpush() {
    dotfiles_need git || return

    # Permitir argumentos personalizados.
    if (( $# > 0 )); then
        command git push "$@"
        return $?
    fi

    local branch

    branch=$(command git branch --show-current) || return

    [[ -n "$branch" ]] || {
        print -u2 -- "Error: HEAD separado; selecciona una rama."
        return 1
    }

    # Utilizar el upstream existente.
    if command git rev-parse \
        --abbrev-ref \
        --symbolic-full-name \
        '@{upstream}' >/dev/null 2>&1; then

        command git push
        return $?
    fi

    # Comprobar que origin exista.
    command git remote get-url origin >/dev/null 2>&1 || {
        print -u2 -- "Error: no existe el remoto origin."
        return 1
    }

    # Publicar y configurar el upstream.
    print -r -- "Configurando upstream: origin/$branch"

    command git push --set-upstream origin "$branch"
}


# =============================================================================
#   Ramas
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: gnew nombre_rama
# -----------------------------------------------------------------------------
#
#   Crea una nueva rama local y cambia automaticamente a ella.
#
#   Requiere exactamente un argumento con el nombre de la rama.
#   Si la rama ya existe, Git muestra el error correspondiente.
#
# -----------------------------------------------------------------------------

function gnew() {
    (( $# == 1 )) || {
        print -u2 "Uso: gnew rama"
        return 1
    }

    command git switch -c "$1"
}


# -----------------------------------------------------------------------------
#   Uso: gdel nombre_rama
# -----------------------------------------------------------------------------
#
#   Elimina una rama local de forma segura.
#
#   Git solo permite eliminarla si sus cambios estan integrados
#   de acuerdo con las comprobaciones de git branch -d.
#
#   No elimina ramas del repositorio remoto.
#
# -----------------------------------------------------------------------------

function gdel() {
    (( $# == 1 )) || {
        print -u2 "Uso: gdel rama"
        return 1
    }

    command git branch -d -- "$1"
}


# =============================================================================
#   Navegacion
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: groot
# -----------------------------------------------------------------------------
#
#   Cambia el directorio actual a la raiz del repositorio Git.
#
#   Permite regresar a la carpeta principal del proyecto desde
#   cualquier subdirectorio que pertenezca al repositorio.
#
# -----------------------------------------------------------------------------

function groot() {
    local root

    root=$(command git rev-parse --show-toplevel) || return

    cd -- "$root"
}


# =============================================================================
#   Sincronizacion
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: gsync
# -----------------------------------------------------------------------------
#
#   Sincroniza la rama actual con su rama de seguimiento remota.
#
#   Operaciones:
#       1. Comprueba que exista una rama local y un upstream.
#       2. Detecta modificaciones locales sin commit.
#       3. Descarga los cambios del remoto con git fetch.
#       4. Compara los commits locales y remotos.
#       5. Actualiza mediante fast-forward o rebase.
#
#   Seguridad:
#       - No elimina modificaciones locales.
#       - No ejecuta stash automaticamente.
#       - No realiza push al repositorio remoto.
#       - Cancela si existen cambios locales sin commit.
#
#   Nota:
#       - Si ocurre un conflicto durante el rebase, Git detiene
#         la operacion para permitir su resolucion manual.
#
# -----------------------------------------------------------------------------

function gsync() {
    dotfiles_need git || return

    local branch upstream remote changes
    local -i ahead behind

    # Verificar la rama actual.
    branch=$( command git branch --show-current 2>/dev/null ) || {
        print -u2 -- "Error: no estas dentro de un repositorio Git."
        return 1
    }

    [[ -n "$branch" ]] || {
        print -u2 -- "Error: HEAD separado; selecciona una rama."
        return 1
    }

    # Comprobar la rama de seguimiento.
    upstream=$( command git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null ) || {
        print -u2 -- "Error: la rama $branch no tiene upstream valido."
        print -u2 -- "Publicala primero con: gpush"
        return 1
    }

    # Detectar modificaciones locales sin commit.
    changes=$( command git status --porcelain --untracked-files=normal ) || return

    [[ -z "$changes" ]] || {
        print -u2 -- "Sincronizacion cancelada: existen cambios sin commit."
        print -u2 -- "Revisa: git status"
        print -u2 -- 'Opciones: gac "mensaje" o git stash push -u'
        return 1
    }

    # Obtener el remoto asociado a la rama.
    remote=$( command git config --get "branch.${branch}.remote" ) || {
        print -u2 -- "Error: no se encontro el remoto de seguimiento."
        return 1
    }

    # Actualizar las referencias remotas.
    print -r -- "Consultando $upstream..."

    if [[ "$remote" != "." ]]; then
        command git fetch --prune "$remote" || return
    fi

    # Contar commits locales y remotos pendientes.
    ahead=$( command git rev-list --count '@{upstream}..HEAD' ) || return

    behind=$( command git rev-list --count 'HEAD..@{upstream}' ) || return

    print -r -- "Commits locales pendientes: $ahead"
    print -r -- "Commits remotos pendientes: $behind"

    # No existen commits remotos pendientes.
    if (( behind == 0 )); then

        if (( ahead == 0 )); then
            print -r -- "La rama $branch ya esta actualizada."
        else
            print -r -- "No hay cambios remotos pendientes."
            print -r -- "Tienes $ahead commit(s) locales por publicar con gpush."
        fi

        return 0
    fi

    # Actualizar sin modificar el historial local.
    if (( ahead == 0 )); then

        print -r -- "Actualizando $branch mediante fast-forward..."

        command git merge --ff-only '@{upstream}' || return

    else

        # Reaplicar los commits locales sobre los remotos.
        print -r -- "Historial divergente: reaplicando commits locales..."

        if ! command git rebase '@{upstream}'; then

            print -u2 -- "No se completo el rebase."
            print -u2 -- "Revisa: git status"
            print -u2 -- "Si hay conflictos: resuelvelos, usa git add y git rebase --continue."
            print -u2 -- "Para cancelar un rebase en curso: git rebase --abort"

            return 1
        fi

    fi

    print -r -- "Sincronizacion completada: $branch"
}


# =============================================================================
#   Informacion del repositorio
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: ginfo
# -----------------------------------------------------------------------------
#
#   Muestra informacion general del repositorio Git actual.
#
#   Informacion:
#       - Ruta absoluta de la raiz del repositorio.
#       - Remotos configurados y sus direcciones.
#       - Estado resumido de la rama y archivos modificados.
#
# -----------------------------------------------------------------------------

function ginfo() {
    command git rev-parse --show-toplevel &&
    command git remote -v &&
    command git status --short --branch
}


# =============================================================================
#   Limpieza de ramas
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: gcleanmerged
# -----------------------------------------------------------------------------
#
#   Elimina las ramas locales que ya estan integradas en HEAD.
#
#   Ramas protegidas:
#       - main
#       - master
#       - develop
#       - Rama actual
#
#   Utiliza git branch -d para evitar eliminaciones forzadas.
#
#   Nota:
#       - No elimina ramas remotas.
#       - Si HEAD esta separado, cancela la operacion.
#       - Las ramas se comprueban respecto a HEAD.
#
# -----------------------------------------------------------------------------

function gcleanmerged() {
    local current
    local branch
    local merged

    current=$(command git branch --show-current) || return

    [[ -n "$current" ]] || {
        print -u2 "HEAD separado; selecciona una rama."
        return 1
    }

    merged=$( command git for-each-ref --merged=HEAD --format='%(refname:short)' refs/heads ) || return

    for branch in "${(@f)merged}"; do

        case "$branch" in
            ""|main|master|develop|"$current")
                continue
                ;;
        esac

        command git branch -d -- "$branch" || return

    done
}


# =============================================================================
#   Selectores interactivos de Git
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: dotfiles_git_pick_branch
# -----------------------------------------------------------------------------
#
#   Permite seleccionar una rama local mediante fzf.
#
#   Las ramas se ordenan por la fecha del ultimo commit,
#   mostrando primero las que tienen actividad mas reciente.
#
#   Al seleccionar una rama, ejecuta git switch.
#
#   Requisitos:
#       - git
#       - fzf
#
# -----------------------------------------------------------------------------

function dotfiles_git_pick_branch() {
    dotfiles_need fzf || return

    local branch

    branch=$( command git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads | fzf --prompt='Rama > ' ) || return

    [[ -n "$branch" ]] && command git switch -- "$branch"
}


# -----------------------------------------------------------------------------
#   Uso: dotfiles_git_pick_commit
# -----------------------------------------------------------------------------
#
#   Permite seleccionar un commit del historial mediante fzf.
#
#   Muestra hasta 200 commits en formato resumido.
#
#   Al seleccionar un commit, ejecuta git show para consultar
#   su informacion y los cambios asociados.
#
#   No modifica el historial ni cambia de rama.
#
#   Requisitos:
#       - git
#       - fzf
#
# -----------------------------------------------------------------------------

function dotfiles_git_pick_commit() {
    dotfiles_need fzf || return

    local line

    line=$( command git log --oneline -200 | fzf --prompt='Commit > ' ) || return

    [[ -n "$line" ]] && command git show "${line%% *}"
}
