#!/bin/sh

# Restore from backup if empty
_xsettingsd="$HOME/.config/bspwm/config/xsettingsd"
[ ! -s "$_xsettingsd" ] && cp "$HOME/.local/share/gh0stzk/config/bspwm/config/xsettingsd" "$_xsettingsd"

# Set the gtk theme corresponding to rice
sed -i "$HOME"/.config/bspwm/config/xsettingsd \
    -e "s|Net/ThemeName .*|Net/ThemeName \"$gtk_theme\"|" \
    -e "s|Net/IconThemeName .*|Net/IconThemeName \"$gtk_icons\"|" \
    -e "s|Gtk/CursorThemeName .*|Gtk/CursorThemeName \"$gtk_cursor\"|"

sed -i -e "s/Inherits=.*/Inherits=$gtk_cursor/" "$HOME"/.icons/default/index.theme

# Reload daemon and apply gtk theme
if pidof -q xsettingsd; then
    pkill -1 xsettingsd
fi
xsetroot -cursor_name left_ptr
