#!/usr/bin/env bash

# Una sola declaración para instalar y comprobar los enlaces.
# shellcheck disable=SC2034

DOTFILES_LINK_NAMES=(zshrc nvim kitty dotfiles ruff)

DOTFILES_LINK_SOURCES=(
    "$DOTFILES_ROOT/config/zsh/.zshrc"
    "$DOTFILES_ROOT/config/nvim"
    "$DOTFILES_ROOT/config/kitty"
    "$DOTFILES_ROOT/bin/dotfiles"
    "$DOTFILES_ROOT/config/ruff/ruff.toml"
)

DOTFILES_LINK_DESTINATIONS=(
    "$HOME/.zshrc"
    "${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
    "${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
    "$HOME/.local/bin/dotfiles"
    "${XDG_CONFIG_HOME:-$HOME/.config}/ruff/ruff.toml"
)
