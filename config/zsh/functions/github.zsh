# =============================================================================
#   Proyecto : Dotfiles
#   Archivo  : github.zsh
#   Autor    : Gustavo Ruiz Luis
# =============================================================================
#
#   GitHub CLI - Funciones para repositorios y pull requests
#
#   Requisitos:
#       - gh: GitHub CLI.
#       - git: necesario para detectar la rama local.
#       - fzf: necesario para seleccionar repositorios.
#
#   Nota:
#       - dotfiles_need() se define en functions/utils.zsh.
#       - Este archivo se carga desde config/zsh/.zshrc.
#
# =============================================================================

# =============================================================================
#   Repositorios
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: ghrepo [usuario/repositorio]
# -----------------------------------------------------------------------------
#
#   Abre el repositorio actual o uno indicado en el navegador.
#
# -----------------------------------------------------------------------------

function ghrepo() {
    dotfiles_need gh || return

    command gh repo view --web "$@"
}


# -----------------------------------------------------------------------------
#   Uso: ghbranch [ruta]
# -----------------------------------------------------------------------------
#
#   Abre en GitHub la rama local actual.
#   Si se indica una ruta, abre ese archivo o directorio en la rama.
#   No funciona con HEAD separado ni fuera de un repositorio Git.
#
# -----------------------------------------------------------------------------

function ghbranch() {
    dotfiles_need gh || return
    dotfiles_need git || return

    local branch

    if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print -u2 -- "Error: no estas dentro de un repositorio Git."
        return 1
    fi

    branch=$(command git branch --show-current) || return

    [[ -n "$branch" ]] || {
        print -u2 -- "Error: HEAD separado; selecciona una rama."
        return 1
    }

    command gh browse --branch "$branch" "$@"
}


# -----------------------------------------------------------------------------
#   Uso: ghinfo
# -----------------------------------------------------------------------------
#
#   Muestra el nombre, la rama principal, la URL y la descripcion
#   del repositorio actual sin abrir el navegador.
#
# -----------------------------------------------------------------------------

function ghinfo() {
    dotfiles_need gh || return

    command gh repo view \
        --json nameWithOwner,description,url,defaultBranchRef \
        --template 'Repositorio:    {{.nameWithOwner}}
Rama principal: {{if .defaultBranchRef}}{{.defaultBranchRef.name}}{{else}}(sin rama){{end}}
URL:            {{.url}}
Descripcion:    {{if .description}}{{.description}}{{else}}(sin descripcion){{end}}
'
}


# =============================================================================
#   Pull requests
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: ghpr [numero | URL | rama]
# -----------------------------------------------------------------------------
#
#   Abre un pull request en el navegador.
#   Sin argumentos, busca el pull request de la rama actual.
#
# -----------------------------------------------------------------------------

function ghpr() {
    dotfiles_need gh || return

    command gh pr view --web "$@"
}


# -----------------------------------------------------------------------------
#   Uso: ghprc [opciones]
# -----------------------------------------------------------------------------
#
#   Inicia la creacion de un pull request desde la terminal.
#   Permite pasar opciones directamente al comando gh pr create.
#
# -----------------------------------------------------------------------------

function ghprc() {
    dotfiles_need gh || return

    command gh pr create "$@"
}


# =============================================================================
#   Selectores interactivos
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: dotfiles_gh_pick_repo
#   Alias: ghpick
# -----------------------------------------------------------------------------
#
#   Lista hasta 100 repositorios de la cuenta autenticada en GitHub.
#   Permite elegir uno con fzf y abrirlo en el navegador.
#   ENTER confirma la seleccion; ESC cancela sin abrir nada.
#
# -----------------------------------------------------------------------------

function dotfiles_gh_pick_repo() {
    dotfiles_need gh || return
    dotfiles_need fzf || return

    local repos repo

    repos=$(
        command gh repo list \
            --limit 100 \
            --json nameWithOwner \
            --jq '.[].nameWithOwner'
    ) || return

    [[ -n "$repos" ]] || {
        print -u2 -- "No se encontraron repositorios."
        return 1
    }

    repo=$(
        print -r -- "$repos" |
            command fzf \
                --prompt='GitHub > ' \
                --height=70% \
                --layout=reverse \
                --border=rounded \
                --info=inline \
                --header='ENTER: abrir | ESC: cancelar' \
                --no-multi
    ) || return

    [[ -n "$repo" ]] || return 1

    command gh repo view "$repo" --web
}

# =============================================================================
#   Autenticacion
# =============================================================================

# -----------------------------------------------------------------------------
#   Uso: ghlogin
# -----------------------------------------------------------------------------
#
#   Inicia sesion en GitHub desde el navegador si es necesario.
#   Configura Git para utilizar gh como gestor de credenciales HTTPS.
#   No solicita ni guarda manualmente un token en los Dotfiles.
#
#   Nota:
#       - La configuracion se aplica al usuario local.
#       - Los remotos SSH siguen usando sus propias claves SSH.
#       - GitHub CLI puede guardar el token sin cifrar si no encuentra
#         un almacen seguro de credenciales en el sistema.
#
# -----------------------------------------------------------------------------

function ghlogin() {
    dotfiles_need gh || return
    dotfiles_need git || return

    if ! command gh auth status --hostname github.com >/dev/null 2>&1; then
        command gh auth login \
            --hostname github.com \
            --git-protocol https \
            --web || return
    fi

    command gh auth setup-git --hostname github.com || return

    print -r -- "GitHub: autenticacion HTTPS configurada."
    command gh auth status --active --hostname github.com
}
