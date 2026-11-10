#!/bin/bash
# Adds a GNOME custom keyboard shortcut for launching bspwm (Super+Shift+B;
# the same keys quit bspwm back to GNOME, see sxhkdrc).
# Reuses the entry that already runs bspwm.sh, otherwise takes the first free
# customN slot, so the user's own shortcuts are never overwritten.
# Usage: ./add-gnome-shortcut.sh

BASE="/org/gnome/settings-daemon/plugins/media-keys"
NAME="launchbspwm"
COMMAND="$HOME/.bspwminstaller/bspwm.sh"
BINDING="<Shift><Super>b"

current=$(dconf read "$BASE/custom-keybindings")
[ "$current" = "@as []" ] && current=""

NEW_DIR=""
for dir in $(echo "$current" | grep -oE "$BASE/custom-keybindings/[^']+/"); do
    if [ "$(dconf read "${dir}command")" = "'$COMMAND'" ]; then
        NEW_DIR="$dir"
        echo "Shortcut already registered at $dir, updating..."
        break
    fi
done

if [ -z "$NEW_DIR" ]; then
    n=0
    while echo "$current" | grep -q "/custom$n/'" || [ -n "$(dconf read "$BASE/custom-keybindings/custom$n/command")" ]; do
        n=$((n + 1))
    done
    NEW_DIR="$BASE/custom-keybindings/custom$n/"
    if [ -z "$current" ]; then
        new_list="['$NEW_DIR']"
    else
        new_list=$(echo "$current" | sed "s|]$|, '$NEW_DIR']|")
    fi
    dconf write "$BASE/custom-keybindings" "$new_list"
    echo "Registered custom$n in custom-keybindings list."
fi

dconf write "${NEW_DIR}name"    "'$NAME'"
dconf write "${NEW_DIR}command" "'$COMMAND'"
dconf write "${NEW_DIR}binding" "'$BINDING'"

echo "Done. Shortcut created:"
echo "  Name:    $NAME"
echo "  Command: $COMMAND"
echo "  Binding: $BINDING"
