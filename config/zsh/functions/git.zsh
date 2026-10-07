# ============================================================
# Git Utilities
# ============================================================

# ------------------------------------------------------------
# Current Branch
# ------------------------------------------------------------

function git_branch_name() {
    command git branch --show-current 2>/dev/null
}


# ------------------------------------------------------------
# Commit
# ------------------------------------------------------------

function gac() {
    (( $# )) || {
        print -u2 'Uso: gac "mensaje"'
        return 1
    }

    command git add --all &&
        command git commit -m "$*"
}


function gacp() {
    gac "$@" &&
        command git push
}


# ------------------------------------------------------------
# Branches
# ------------------------------------------------------------

function gnew() {
    (( $# == 1 )) || {
        print -u2 "Uso: gnew rama"
        return 1
    }

    command git switch -c "$1"
}


function gdel() {
    (( $# == 1 )) || {
        print -u2 "Uso: gdel rama"
        return 1
    }

    command git branch -d -- "$1"
}


# ------------------------------------------------------------
# Repository Root
# ------------------------------------------------------------

function groot() {
    local root

    root=$(command git rev-parse --show-toplevel) || return

    cd -- "$root"
}


# ------------------------------------------------------------
# Synchronization
# ------------------------------------------------------------

function gsync() {
    local upstream

    upstream=$(
        command git rev-parse \
            --abbrev-ref \
            '@{upstream}' \
            2>/dev/null
    ) || {
        print -u2 "Esta rama no tiene upstream."
        return 1
    }

    print -r -- "Sincronizando con $upstream"

    command git fetch --prune &&
        command git pull --rebase
}


# ------------------------------------------------------------
# Repository Information
# ------------------------------------------------------------

function ginfo() {
    command git rev-parse --show-toplevel &&
        command git remote -v &&
        command git status --short --branch
}


# ------------------------------------------------------------
# Remove Merged Branches
# ------------------------------------------------------------

function gcleanmerged() {
    local current
    local branch
    local merged

    current=$(command git branch --show-current) || return

    [[ -n "$current" ]] || {
        print -u2 "HEAD separado; selecciona una rama."
        return 1
    }

    merged=$(
        command git for-each-ref \
            --merged=HEAD \
            --format='%(refname:short)' \
            refs/heads
    ) || return

    for branch in "${(@f)merged}"; do

        case "$branch" in
            ""|main|master|develop|"$current")
                continue
                ;;
        esac

        command git branch -d -- "$branch" || return

    done
}


# ============================================================
# Interactive Git Selectors
# ============================================================

# ------------------------------------------------------------
# Branch Selector
# ------------------------------------------------------------

function dotfiles_git_pick_branch() {
    dotfiles_need fzf || return

    local branch

    branch=$(
        command git for-each-ref \
            --sort=-committerdate \
            --format='%(refname:short)' \
            refs/heads |
            fzf --prompt='Rama > '
    ) || return

    [[ -n "$branch" ]] &&
        command git switch -- "$branch"
}


# ------------------------------------------------------------
# Commit Selector
# ------------------------------------------------------------

function dotfiles_git_pick_commit() {
    dotfiles_need fzf || return

    local line

    line=$(
        command git log --oneline -200 |
            fzf --prompt='Commit > '
    ) || return

    [[ -n "$line" ]] &&
        command git show "${line%% *}"
}
