# ============================================================
# Functions
# ============================================================

# ============================================================
# Prompt
# ============================================================

ghost_icon() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%B%F{magenta}󱙝 %f%b"
    else
        echo "%B%F{magenta}󱙜 %f%b"
    fi
}

arrow() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%F{magenta}➤  %f"
    else
        echo "%F{red}➤  %f"
    fi
}

LH() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%B%F{blue}╭──%f%b"
    else
        echo "%B%F{red}╭──%f%b"
    fi
}

LL() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%B%F{blue}╰──%f%b"
    else
        echo "%B%F{red}╰──%f%b"
    fi
}

RH() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%B%F{blue}──╮%f%b"
    else
        echo "%B%F{red}──╮%f%b"
    fi
}

RL() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%B%F{blue}──╯%f%b"
    else
        echo "%B%F{red}──╯%f%b"
    fi
}

BAR() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%B%F{blue} ${(e)PR_FILLBAR} %f%b"
    else
        echo "%B%F{red} ${(e)PR_FILLBAR} %f%b"
    fi
}

# ------------------------------------------------------------
# Update prompt bar
# ------------------------------------------------------------

update_prompt_bar() {
    PR_FILLBAR=""
    PR_PWDLEN=""

    local promptsize=${#${(%):-──[    ][  ] ~~ [ %n ]──}}
    local pwdsize=${#${(%):-%/}}
    local TERMWIDTH

    (( TERMWIDTH = COLUMNS - 1 ))

    if (( promptsize + pwdsize > TERMWIDTH )); then
        (( PR_PWDLEN = TERMWIDTH - promptsize ))
    else
        PR_FILLBAR="\${(l.(($TERMWIDTH - ($promptsize + $pwdsize)))..${PR_HBAR}.)}"
    fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd update_prompt_bar


# ============================================================
# Git Prompt Functions
# ============================================================

# ------------------------------------------------------------
# Git icon
# ------------------------------------------------------------

GITIF() {
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "%B%F{cyan} %f%b"
    fi
}

# ------------------------------------------------------------
# Current branch
# ------------------------------------------------------------

git_branch_name() {
    git branch --show-current 2>/dev/null
}

# ------------------------------------------------------------
# Ahead / Behind remote
# ------------------------------------------------------------

git_ahead_behind() {
    git rev-parse --is-inside-work-tree &>/dev/null || return

    local upstream
    local counts
    local ahead
    local behind

    upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || return

    counts=$(git rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)

    ahead=${counts%%[[:space:]]*}
    behind=${counts##*[[:space:]]}

    (( ahead > 0 )) && echo -n "%F{green}⇡${ahead}%f "
    (( behind > 0 )) && echo -n "%F{red}⇣${behind}%f "
}

# ------------------------------------------------------------
# Stash counter
# ------------------------------------------------------------

git_stash_count() {
    git rev-parse --is-inside-work-tree &>/dev/null || return

    local count

    count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

    (( count > 0 )) && echo -n "%F{yellow}󰏗 ${count}%f "
}

# ============================================================
# Git Utility Functions
# ============================================================

# ------------------------------------------------------------
# Add + Commit
#
# gac "mensaje"
# ------------------------------------------------------------

gac() {
    if [[ -z "$1" ]]; then
        echo "Uso: gac \"mensaje del commit\""
        return 1
    fi

    git add --all &&
    git commit -m "$*"
}

# ------------------------------------------------------------
# Add + Commit + Push
#
# gacp "mensaje"
# ------------------------------------------------------------

gacp() {
    if [[ -z "$1" ]]; then
        echo "Uso: gacp \"mensaje del commit\""
        return 1
    fi

    git add --all &&
    git commit -m "$*" &&
    git push
}

# ------------------------------------------------------------
# Create branch
#
# gnew feature/wishbone
# ------------------------------------------------------------

gnew() {
    if [[ -z "$1" ]]; then
        echo "Uso: gnew <nombre-rama>"
        return 1
    fi

    git switch -c "$1"
}

# ------------------------------------------------------------
# Delete branch
#
# gdel feature/test
# ------------------------------------------------------------

gdel() {
    if [[ -z "$1" ]]; then
        echo "Uso: gdel <nombre-rama>"
        return 1
    fi

    git branch -d "$1"
}

# ------------------------------------------------------------
# Repository root
# ------------------------------------------------------------

groot() {
    local root

    root=$(git rev-parse --show-toplevel 2>/dev/null)

    if [[ -z "$root" ]]; then
        echo "No estás dentro de un repositorio Git."
        return 1
    fi

    cd "$root"
}

# ------------------------------------------------------------
# Synchronize branch
# ------------------------------------------------------------

gsync() {
    local branch

    branch=$(git branch --show-current)

    if [[ -z "$branch" ]]; then
        echo "No estás en una rama Git."
        return 1
    fi

    echo "󰘬 Fetch origin..."

    git fetch origin --prune || return 1

    echo "󰜮 Pull --rebase origin/$branch..."

    git pull --rebase origin "$branch"
}

# ------------------------------------------------------------
# Repository information
# ------------------------------------------------------------

ginfo() {
    git rev-parse --is-inside-work-tree &>/dev/null || {
        echo "No estás dentro de un repositorio Git."
        return 1
    }

    local root
    local branch
    local remote

    root=$(git rev-parse --show-toplevel)
    branch=$(git branch --show-current)
    remote=$(git remote get-url origin 2>/dev/null)

    echo
    echo "%B%F{magenta}Git Repository%f%b"
    echo
    echo "%F{cyan}Repository:%f $(basename "$root")"
    echo "%F{cyan}Branch:%f     ${branch:-DETACHED}"

    if [[ -n "$remote" ]]; then
        echo "%F{cyan}Origin:%f     $remote"
    fi

    echo
    git status --short --branch
}

# ------------------------------------------------------------
# Remove merged branches
# ------------------------------------------------------------

gcleanmerged() {
    git rev-parse --is-inside-work-tree &>/dev/null || {
        echo "No estás dentro de un repositorio Git."
        return 1
    }

    local current

    current=$(git branch --show-current)

    git branch --merged |
        sed 's/^[* ]*//' |
        grep -vE "^(main|master|develop|${current})$" |
        xargs -r git branch -d
}


# ============================================================
# GitHub CLI Functions
# ============================================================

ghrepo() {
    if ! command -v gh &>/dev/null; then
        echo "GitHub CLI (gh) no está instalado."
        return 1
    fi

    gh repo view --web
}

ghbranch() {
    if ! command -v gh &>/dev/null; then
        echo "GitHub CLI (gh) no está instalado."
        return 1
    fi

    local branch

    branch=$(git branch --show-current)

    if [[ -z "$branch" ]]; then
        echo "No se pudo determinar la rama actual."
        return 1
    fi

    gh browse --branch "$branch"
}

ghpr() {
    if ! command -v gh &>/dev/null; then
        echo "GitHub CLI (gh) no está instalado."
        return 1
    fi

    gh pr view --web
}

ghprc() {
    if ! command -v gh &>/dev/null; then
        echo "GitHub CLI (gh) no está instalado."
        return 1
    fi

    gh pr create
}

ghinfo() {
    if ! command -v gh &>/dev/null; then
        echo "GitHub CLI (gh) no está instalado."
        return 1
    fi

    gh repo view \
        --json nameWithOwner,description,url,defaultBranchRef \
        --template \
'Repository:  {{.nameWithOwner}}
Branch:      {{.defaultBranchRef.name}}
URL:         {{.url}}
Description: {{.description}}
'
}


# ============================================================
# Xilinx
# ============================================================

ise() {
    echo "Iniciando Xilinx ISE 14.7..."

    bash -c "source /opt/Xilinx/14.7/ISE_DS/settings64.sh && ise"
}

digilent() {
    if [[ -z "$1" ]]; then
        echo "Error: Debes proporcionar la ruta al archivo .bit"
        echo "Uso: digilent /ruta/al/archivo.bit"
        return 1
    fi

    local BIT_FILE="${1:A}"

    if [[ ! -f "$BIT_FILE" ]]; then
        echo "Error: El archivo '$BIT_FILE' no existe."
        return 1
    fi

    echo "🔌 Detectando tarjeta Nexys 3..."

    djtgcfg init -d Nexys3 || return 1

    echo "🚀 Programando FPGA con '$BIT_FILE'..."

    djtgcfg prog \
        -d Nexys3 \
        -i 0 \
        -f "$BIT_FILE"
}
