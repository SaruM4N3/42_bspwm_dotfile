#!/bin/sh
SESSION_DIR="$HOME/.config/bspwm/config/.session"
mkdir -p "$SESSION_DIR"

# bspwm/config files
for f in picom.conf picom-animations.conf xsettingsd jgmenurc dunstrc sxhkdrc system.ini NetManagerDM.ini; do
    [ -s "$HOME/.config/bspwm/config/$f" ] && cp "$HOME/.config/bspwm/config/$f" "$SESSION_DIR/$f"
done

# micro editor config
MICRO_SESSION="$SESSION_DIR/micro"
mkdir -p "$MICRO_SESSION/colorschemes"
[ -s "$HOME/.config/micro/settings.json" ] && cp "$HOME/.config/micro/settings.json" "$MICRO_SESSION/settings.json"
[ -s "$HOME/.config/micro/bindings.json" ] && cp "$HOME/.config/micro/bindings.json" "$MICRO_SESSION/bindings.json"
for cs in "$HOME/.config/micro/colorschemes/"*.micro; do
    [ -f "$cs" ] && cp "$cs" "$MICRO_SESSION/colorschemes/"
done
