#!/bin/sh
# =============================================================
#  ████████╗██╗  ██╗███████╗███╗   ███╗███████╗
#  ╚══██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝
#     ██║   ███████║█████╗  ██╔████╔██║█████╗
#     ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝
#     ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗
#     ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝
# Author: gh0stzk
# Repo:   https://github.com/gh0stzk/dotfiles
# Date:   10.11.2025
# Info:   This file will configure and launch the rice.
#
# Copyright (C) 2021-2025 gh0stzk <z0mbi3.zk@protonmail.com>
# Licensed under GPL-3.0 license
# =============================================================

# Current Rice
read -r RICE < "$HOME"/.config/bspwm/.rice

# Guard: refuse to source an empty theme-config.bash — it means RiceEditor
# crashed mid-write. Restore from git if possible, otherwise abort.
THEME_CFG="$HOME/.config/bspwm/rices/$RICE/theme-config.bash"
if [ ! -s "$THEME_CFG" ]; then
    # Try to restore from git index
    GIT_RESTORE=$(cd "$HOME/bspwm-dotfiles" 2>/dev/null && \
        git show HEAD:".config/bspwm/rices/$RICE/theme-config.bash" 2>/dev/null)
    if [ -n "$GIT_RESTORE" ]; then
        echo "$GIT_RESTORE" > "$THEME_CFG"
        dunstify -u critical -t 6000 "Theme.sh" \
            "theme-config.bash was empty — restored from git. Rice: $RICE"
    else
        dunstify -u critical -t 6000 "Theme.sh" \
            "theme-config.bash is empty and could not be restored. Aborting."
        exit 1
    fi
fi

# Load theme configuration
. "$THEME_CFG"
# Path to modules dir
MODULE_DIR="$HOME/.config/bspwm/config/modules"


# Load all the files in dir
for module in "$MODULE_DIR"/*.sh; do
    . "$module"
done
