# ============================================================
# Git Configuration
# ============================================================

# ------------------------------------------------------------
# Git Prompt
# ------------------------------------------------------------

ZSH_THEME_GIT_PROMPT_PREFIX=" on %{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"

# ------------------------------------------------------------
# Repository state
# ------------------------------------------------------------

ZSH_THEME_GIT_PROMPT_DIRTY=""
ZSH_THEME_GIT_PROMPT_CLEAN=""

# ------------------------------------------------------------
# File status
# ------------------------------------------------------------

ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[green]%} %{%G✚%}"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[blue]%} %{%G✹%}"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%} %{%G✖%}"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[magenta]%} %{%G➜%}"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[yellow]%} %{%G═%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%} %{%G✭%}"

# ------------------------------------------------------------
# Git behavior
# ------------------------------------------------------------

# Automatically setup remote tracking on first push.
git config --global push.autoSetupRemote true

# Prune deleted remote branches when fetching.
git config --global fetch.prune true

# Rebase instead of creating unnecessary merge commits on pull.
git config --global pull.rebase true

# Reuse recorded conflict resolutions.
git config --global rerere.enabled true

# Use colors.
git config --global color.ui auto

# More readable default branch listing.
git config --global column.ui auto

# Sort branches by most recently committed.
git config --global branch.sort -committerdate

# Sort tags semantically.
git config --global tag.sort version:refname
