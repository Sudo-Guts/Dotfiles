# ============================================================
# GitHub CLI
# ============================================================

function ghrepo() {
    dotfiles_need gh || return

    command gh repo view --web "$@"
}


function ghbranch() {
    dotfiles_need gh || return

    local branch

    branch=$(command git branch --show-current) || return

    [[ -n "$branch" ]] || {
        print -u2 "HEAD separado."
        return 1
    }

    command gh browse --branch "$branch"
}


function ghpr() {
    dotfiles_need gh || return

    command gh pr view --web "$@"
}


function ghprc() {
    dotfiles_need gh || return

    command gh pr create "$@"
}


function ghinfo() {
    dotfiles_need gh || return

    command gh repo view \
        --json nameWithOwner,description,url,defaultBranchRef \
        --template 'Repository: {{.nameWithOwner}}{{"\n"}}Branch: {{.defaultBranchRef.name}}{{"\n"}}URL: {{.url}}{{"\n"}}{{.description}}{{"\n"}}'
}


# ============================================================
# Interactive GitHub Selectors
# ============================================================

function dotfiles_gh_pick_repo() {
    dotfiles_need gh || return
    dotfiles_need fzf || return

    local repo

    repo=$(
        command gh repo list \
            --limit 100 \
            --json nameWithOwner \
            --jq '.[].nameWithOwner' |
            fzf --prompt='GitHub > '
    ) || return

    [[ -n "$repo" ]] &&
        command gh repo view "$repo" --web
}
