#!/bin/bash
# Adds a GNOME custom keyboard shortcut for launching bspwm.
# Usage: ./add-gnome-shortcut.sh

BASE="/org/gnome/settings-daemon/plugins/media-keys"
NEW_KEY="custom5"
NEW_DIR="$BASE/custom-keybindings/$NEW_KEY/"

NAME="launchbspwm"
COMMAND="$HOME/.bspwminstaller/bspwm.sh"
BINDING="<Super>b"

# Read current list
current=$(dconf read "$BASE/custom-keybindings")

if echo "$current" | grep -q "$NEW_KEY"; then
    echo "Shortcut $NEW_KEY already exists, updating..."
else
    if [ -z "$current" ] || [ "$current" = "@as []" ]; then
        new_list="['$NEW_DIR']"
    else
        new_list=$(echo "$current" | sed "s|]|, '$NEW_DIR']|")
    fi
    dconf write "$BASE/custom-keybindings" "$new_list"
    echo "Registered $NEW_KEY in custom-keybindings list."
fi

dconf write "${NEW_DIR}name"    "'$NAME'"
dconf write "${NEW_DIR}command" "'$COMMAND'"
dconf write "${NEW_DIR}binding" "'$BINDING'"

echo "Done. Shortcut created:"
echo "  Name:    $NAME"
echo "  Command: $COMMAND"
echo "  Binding: $BINDING"