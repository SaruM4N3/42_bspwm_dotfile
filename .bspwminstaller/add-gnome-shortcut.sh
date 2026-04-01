#!/bin/bash
# Adds a Hyprland keybind for launching bspwm.
# Usage: ./add-gnome-shortcut.sh

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
BIND_LINE="bind = SUPER, B, exec, $HOME/.bspwminstaller/bspwm.sh"

if [ ! -f "$HYPR_CONF" ]; then
    echo "Hyprland config not found at $HYPR_CONF — skipping."
    exit 0
fi

if grep -q "bspwm.sh" "$HYPR_CONF"; then
    echo "Keybind already exists in $HYPR_CONF — skipping."
else
    printf '\n# Launch bspwm\n%s\n' "$BIND_LINE" >> "$HYPR_CONF"
    echo "Done. Keybind added to $HYPR_CONF:"
    echo "  $BIND_LINE"
fi
