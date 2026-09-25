# ============================================================
# Aliases
# ============================================================

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

alias Zsh='nvim ~/.zshrc'
alias Kitty='nvim ~/.config/kitty/kitty.conf'
alias Neovim='cd ~/.config/nvim'
alias Dotfiles='cd ~/.dotfiles'

# ------------------------------------------------------------
# General
# ------------------------------------------------------------

alias cls='clear'
alias nv='nvim'

alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# ============================================================
# Git
# ============================================================

alias g='git'

# ------------------------------------------------------------
# Status
# ------------------------------------------------------------

alias gs='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'

# ------------------------------------------------------------
# Add
# ------------------------------------------------------------

alias ga='git add'
alias gaa='git add --all'

# ------------------------------------------------------------
# Commit
# ------------------------------------------------------------

alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'

# ------------------------------------------------------------
# Push / Pull
# ------------------------------------------------------------

alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull'
alias gpr='git pull --rebase'

# ------------------------------------------------------------
# Fetch
# ------------------------------------------------------------

alias gf='git fetch'
alias gfa='git fetch --all --prune'

# ------------------------------------------------------------
# Branch
# ------------------------------------------------------------

alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch -d'
alias gbD='git branch -D'

# ------------------------------------------------------------
# Switch / Checkout
# ------------------------------------------------------------

alias gco='git checkout'
alias gsw='git switch'
alias gswc='git switch -c'

# ------------------------------------------------------------
# Restore
# ------------------------------------------------------------

alias gr='git restore'
alias grs='git restore --staged'

# ------------------------------------------------------------
# Diff
# ------------------------------------------------------------

alias gd='git diff'
alias gds='git diff --staged'

# ------------------------------------------------------------
# Stash
# ------------------------------------------------------------

alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsta='git stash apply'

# ------------------------------------------------------------
# Log
# ------------------------------------------------------------

alias gl='git log --oneline --decorate --graph'
alias gla='git log --oneline --decorate --graph --all'

alias glg='git log --graph --pretty=format:"%C(auto)%h%Creset %C(magenta)%d%Creset %s %C(blue)<%an>%Creset %C(green)(%cr)%Creset" --all'

# ============================================================
# GitHub CLI
# ============================================================

if command -v gh &>/dev/null; then

    alias ghme='gh auth status'

    # Repository
    alias ghr='gh repo view'
    alias ghrw='gh repo view --web'

    # Issues
    alias ghi='gh issue list'
    alias ghiv='gh issue view'

    # Pull Requests
    alias ghp='gh pr list'
    alias ghpv='gh pr view'
    alias ghpc='gh pr create'
    alias ghpm='gh pr merge'
    alias ghpco='gh pr checkout'

fi
