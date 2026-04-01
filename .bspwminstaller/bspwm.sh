#!/bin/bash

# Init LOGDIR
BSPLOGDIR=$HOME/.BspwmLogs
mkdir -p "$BSPLOGDIR"

LOG=$BSPLOGDIR/bspwm_launch.log
echo "--- $(date) ---" > $LOG

# Close all Hyprland windows except the current one
CURRENT_ADDR=$(hyprctl activewindow -j 2>/dev/null | grep -oP '"address":\s*"\K[^"]+')
echo "CURRENT_WIN: $CURRENT_ADDR" >> $LOG
echo "Windows found:" >> $LOG
hyprctl -j clients 2>/dev/null | grep -oP '"address":\s*"\K[^"]+' | while read addr; do
    echo "Closing: $addr" >> $LOG
    [ "$addr" = "$CURRENT_ADDR" ] && continue
    hyprctl dispatch closewindow "address:$addr" 2>/dev/null
done
sleep 1

# Ensure Wayland/Hyprland session vars are exported
for _var in WAYLAND_DISPLAY DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE; do
    [ -n "${!_var}" ] && export "$_var"
done
unset _var

# Strip Hyprland-specific vars that pollute junest (sudo, pacman, etc.)
unset HYPRLAND_INSTANCE_SIGNATURE HYPRLAND_CMD \
      XDG_SESSION_DESKTOP XDG_MENU_PREFIX DESKTOP_SESSION \
      XDG_SESSION_TYPE \
      XDG_DATA_DIRS XDG_CONFIG_DIRS


# Remove outer junest wrapper paths from PATH — inside junest they shadow real sudo/pacman
PATH=$(echo "$PATH" | tr ':' '\n' | grep -vF "$HOME/.junest/usr/bin_wrappers" | tr '\n' ':' | sed 's/:$//')
export PATH

# Kill Hyprland
hyprctl dispatch exit 2>/dev/null || killall -9 Hyprland 2>/dev/null

ft_lock -d

# Swap ~/.zshrc <-> ~/.zshrc.bak before entering bspwm
swap_zshrc() {
    if [ -f "$HOME/.zshrc" ] && [ -f "$HOME/.zshrc.bak" ]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.tmp"
        mv "$HOME/.zshrc.bak" "$HOME/.zshrc"
        mv "$HOME/.zshrc.tmp" "$HOME/.zshrc.bak"
    fi
}
swap_zshrc

# Generate GNOME bin wrappers — check /usr/bin/ (the host path, which becomes /host/usr/
# inside the inner bspwm junest via --bind /usr /host/usr).
# Use the host's own ld-linux + lib path to avoid Arch/Ubuntu ABI mismatch.
# /usr/lib64/ld-linux-x86-64.so.2 is a broken symlink inside bwrap (resolves through
# /lib/ → Arch); use /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 directly.
GNOME_WRAPPERS="$HOME/.cache/bspwm/gnome-wrappers"
mkdir -p "$GNOME_WRAPPERS"
_LDLINUX_INNER="/host/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
_LIBPATH=$(find /usr/lib/x86_64-linux-gnu /usr/lib -maxdepth 2 -type d 2>/dev/null \
    | sed 's|^/usr/|/host/usr/|' | tr '\n' ':' | sed 's/:$//')

for _bin in /usr/bin/gnome-* /usr/bin/nautilus /usr/bin/gedit \
            /usr/bin/eog /usr/bin/evince /usr/bin/baobab \
            /usr/bin/cheese /usr/bin/totem /usr/bin/seahorse \
            /usr/bin/file-roller /usr/bin/rhythmbox; do
    [ -x "$_bin" ] || continue
    _name=$(basename "$_bin")
    printf '#!/bin/sh\nGSETTINGS_SCHEMA_DIR=/host/usr/share/glib-2.0/schemas \\\n  XDG_DATA_DIRS=/host/usr/share:/host/usr/local/share \\\n  exec %s --library-path "%s" /host/usr/bin/%s "$@"\n' \
        "$_LDLINUX_INNER" "$_LIBPATH" "$_name" > "$GNOME_WRAPPERS/$_name"
    chmod +x "$GNOME_WRAPPERS/$_name"
done
echo "GNOME wrappers generated: $(ls "$GNOME_WRAPPERS" | wc -l) scripts" >> "$LOG"
unset _bin _name _LDLINUX_INNER _LIBPATH

# launch bspwm via junest (proot with fakeroot for sudo/pacman support)
"$HOME/.local/share/junest/bin/junest" -b "--bind /sgoinfre /sgoinfre --bind /goinfre /goinfre --bind /dev/shm /dev/shm --bind /run /run --bind /usr /host/usr" -- DRI_PRIME=1 bspwm

# Swap ~/.zshrc <-> ~/.zshrc.bak back on bspwm exit
swap_zshrc

# Restart Hyprland after bspwm exits
sleep 1
if ! pgrep -x Hyprland > /dev/null; then
    Hyprland &
fi
