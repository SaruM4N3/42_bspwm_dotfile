#!/bin/bash

kill $(ps aux | grep ft_ld | grep -v grep | awk '{print $2}')
gcc -shared -fPIC -o /tmp/time.so /home/zsonie/locker/time.c -ldl
LD_PRELOAD=/tmp/time.so /usr/local/bin/ft_lock -d 2>/dev/null || true  # daemon may already be running; that's fine

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

# Remove outer junest wrapper paths from PATH — inside junest they shadow real sudo/pacman.
# Guard with || echo "$PATH": if the wrapper path isn't in PATH (fresh install), grep exits 1
# and the subshell would return empty string, wiping PATH entirely.
_CLEAN_PATH=$(echo "$PATH" | tr ':' '\n' | grep -vF "$HOME/.junest/usr/bin_wrappers" | tr '\n' ':' | sed 's/:$//') \
    && PATH="$_CLEAN_PATH" || true
unset _CLEAN_PATH
export PATH

# ft_lock cannot be exec'd from overlay lower-layer inside bwrap user namespace.
# Watcher on the host runs ft_lock when the Lock script writes to the request FIFO.
_LOCK_REQ="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bspwm_lock_req"
_LOCK_ACK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bspwm_lock_ack"
rm -f "$_LOCK_REQ" "$_LOCK_ACK"
mkfifo "$_LOCK_REQ" "$_LOCK_ACK"
while IFS= read -r _ < "$_LOCK_REQ"; do
    LD_PRELOAD=/tmp/time.so /usr/local/bin/ft_lock
    echo done > "$_LOCK_ACK"
done &
_LOCK_WATCHER_PID=$!

# VS Code cannot launch fresh Electron from inside the overlay (Ubuntu ELF vs Arch libs).
# Watcher on the host launches code with the full Ubuntu environment.
_CODE_REQ="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bspwm_code_req"
rm -f "$_CODE_REQ"
mkfifo "$_CODE_REQ"
while IFS= read -r _cwd < "$_CODE_REQ"; do
    code "${_cwd:-$HOME}" &>/dev/null &
done &
_CODE_WATCHER_PID=$!

# Snapshot GNOME theme settings before killing gnome-shell.
# When gnome-shell restarts after bspwm exits it resets these to its defaults
# (prefer-light / Yaru), so we restore them on the way out.
GNOME_COLOR_SCHEME=$(dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null)
GNOME_GTK_THEME=$(dconf read /org/gnome/desktop/interface/gtk-theme 2>/dev/null)
GNOME_ICON_THEME=$(dconf read /org/gnome/desktop/interface/icon-theme 2>/dev/null)
GNOME_CURSOR_THEME=$(dconf read /org/gnome/desktop/interface/cursor-theme 2>/dev/null)

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
    sleep 0.1
done
# sleep 0.3
unset _deadline


# Swap ~/.zshrc <-> ~/.zshrc.bak before entering bspwm
swap_zshrc() {
    if [ -f "$HOME/.zshrc" ] && [ -f "$HOME/.zshrc.bak" ]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.tmp"
        mv "$HOME/.zshrc.bak" "$HOME/.zshrc"
        mv "$HOME/.zshrc.tmp" "$HOME/.zshrc.bak"
    fi
}
swap_zshrc

# Overlay Ubuntu's /usr as lower layer under Arch's — Arch takes priority, Ubuntu fills
# the gaps. No wrappers needed: Ubuntu tools are at their native paths inside bwrap.
rm -rf "$HOME/.junest/.overlay-work"
mkdir -p "$HOME/.junest/.overlay-work"

# Recreate Steam library dir — /tmp is wiped on reboot but Steam expects this path
mkdir -p /tmp/SteamLibrary/steamapps

# launch bspwm via junest (proot with fakeroot for sudo/pacman support)
echo "launching bspwm at $(date '+%T.%3N'), gnome-shell: $(pgrep -x gnome-shell || echo none)" >> "$LOG"
"$HOME/.local/share/junest/bin/junest" -b \
"--bind /sgoinfre /sgoinfre \
--bind /goinfre /goinfre \
--bind /dev/shm /dev/shm \
--bind /run /run \
--overlay-src /usr \
--overlay $HOME/.junest/usr $HOME/.junest/.overlay-work /usr" -- bspwm 2>>"$LOG"
echo "bspwm exited: $? at $(date '+%T.%3N')" >> "$LOG"

kill "$_LOCK_WATCHER_PID" 2>/dev/null
kill "$_CODE_WATCHER_PID" 2>/dev/null
rm -f "$_CODE_REQ"

rm -f "$_LOCK_REQ" "$_LOCK_ACK"

# Swap ~/.zshrc <-> ~/.zshrc.bak back on bspwm exit
swap_zshrc

# Kill bspwm-owned X daemons — must die before GNOME resumes so gsd-xsettings wins
# (quit.sh handles clean exits; this covers crashes and unclean exits)
pkill -x xsettingsd 2>/dev/null || true
pkill -x picom      2>/dev/null || true
pkill -x sxhkd      2>/dev/null || true
pkill -x xwinwrap   2>/dev/null || true
pkill -x mpv        2>/dev/null || true

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
sleep 0.1
if ! pgrep -x gnome-shell > /dev/null; then
    DBUS=$(grep -z DBUS_SESSION_BUS_ADDRESS /proc/${BINARY_PIDS_NOW%% *}/environ 2>/dev/null | tr '\0' '\n' | head -1)
    [ -n "$DBUS" ] && export $DBUS
    gnome-shell --replace &
fi
