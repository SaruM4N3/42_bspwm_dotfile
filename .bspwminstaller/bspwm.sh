#!/bin/bash

# Init LOGDIR
BSPLOGDIR=$HOME/.BspwmLogs
mkdir -p "$BSPLOGDIR"
LOG=$BSPLOGDIR/bspwm_launch.log
echo "--- $(date) ---" > "$LOG"

# Export only the vars needed from the GNOME session (whitelist to avoid polluting junest)
_GNOME_PID=$(pgrep gnome-software | head -1)
if [ -n "$_GNOME_PID" ]; then
    _GNOME_ENV=$(cat /proc/$_GNOME_PID/environ 2>/dev/null | tr '\0' '\n')
    for _var in DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR; do
        _val=$(echo "$_GNOME_ENV" | grep "^${_var}=")
        [ -n "$_val" ] && export "$_val"
    done
    unset _GNOME_ENV _val _var
fi
unset _GNOME_PID

# Strip GNOME-specific vars that pollute junest (sudo, pacman, etc.)
unset GNOME_DESKTOP_SESSION_ID GNOME_SHELL_SESSION_MODE \
      GTK_MODULES GIO_LAUNCHED_DESKTOP_FILE GIO_LAUNCHED_DESKTOP_FILE_PID \
      XDG_SESSION_DESKTOP XDG_MENU_PREFIX DESKTOP_SESSION \
      GDMSESSION SESSION_MANAGER \
      XDG_DATA_DIRS XDG_CONFIG_DIRS

# Remove outer junest wrapper paths from PATH — inside junest they shadow real sudo/pacman
PATH=$(echo "$PATH" | tr ':' '\n' | grep -vF "$HOME/.junest/usr/bin_wrappers" | tr '\n' ':' | sed 's/:$//')
export PATH

# Kill gnome
MONITOR_PID=$(pgrep -f "gnome-session-ctl --monitor")
BINARY_PIDS=$(pgrep -f "gnome-session-binary")

kill -STOP $MONITOR_PID
for pid in $BINARY_PIDS; do kill -STOP $pid; done

killall -9 gnome-shell 2>/dev/null

# Wait for gnome-shell to fully release the X WM selection before bspwm grabs it.
# Without this, bspwm races with Mutter and prints "Another window manager is already running."
_deadline=$(( $(date +%s) + 10 ))
while pgrep -x gnome-shell > /dev/null 2>&1; do
    [ "$(date +%s)" -ge "$_deadline" ] && break
    sleep 0.2
done
sleep 0.3
unset _deadline

ft_lock -d 2>/dev/null || true  # daemon may already be running; that's fine

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
# Wrappers use the host's own ld-linux + lib path to avoid Arch/Ubuntu ABI mismatch.
GNOME_WRAPPERS="$HOME/.cache/bspwm/gnome-wrappers"
mkdir -p "$GNOME_WRAPPERS"

# Host ld-linux is at /usr/lib/x86_64-linux-gnu/ (not /usr/lib64/ — that's a broken symlink
# inside bwrap because it resolves via /lib/ which maps to Arch's lib).
# Inside the inner bspwm junest the host /usr is mounted at /host/usr.
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
echo "launching bspwm at $(date '+%T.%3N'), gnome-shell: $(pgrep -x gnome-shell || echo none)" >> "$LOG"
"$HOME/.local/share/junest/bin/junest" -b "--bind /sgoinfre /sgoinfre --bind /goinfre /goinfre --bind /dev/shm /dev/shm --bind /run /run --bind /usr /host/usr" -- DRI_PRIME=1 bspwm 2>>"$LOG"
echo "bspwm exited: $? at $(date '+%T.%3N')" >> "$LOG"

# Swap ~/.zshrc <-> ~/.zshrc.bak back on bspwm exit
swap_zshrc

# Re-query PIDs in case processes were respawned during the session
MONITOR_PID_NOW=$(pgrep -f "gnome-session-ctl --monitor")
BINARY_PIDS_NOW=$(pgrep -f "gnome-session-binary")
for pid in $BINARY_PIDS_NOW; do kill -CONT $pid 2>/dev/null; done
[ -n "$MONITOR_PID_NOW" ] && kill -CONT $MONITOR_PID_NOW 2>/dev/null

# Also resume original PIDs in case they're still valid
for pid in $BINARY_PIDS; do kill -CONT $pid 2>/dev/null; done
[ -n "$MONITOR_PID" ] && kill -CONT $MONITOR_PID 2>/dev/null

# gnome-shell was hard-killed at launch — wait for gnome-session to restart it,
# then force-start it if it doesn't come back within 3 seconds
sleep 3
if ! pgrep -x gnome-shell > /dev/null; then
    DBUS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/${BINARY_PIDS_NOW%% *}/environ 2>/dev/null | tr '\0' '\n' | head -1)
    [ -n "$DBUS" ] && export $DBUS
    gnome-shell --replace &
fi
