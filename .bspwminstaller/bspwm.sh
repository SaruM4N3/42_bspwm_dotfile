#!/bin/bash

# Fermer chaque fenêtre sauf le terminal actuel
CURRENT_WIN=$(xdotool getactivewindow)
LOG=~/bspwm_launch.log
echo "--- $(date) ---" > $LOG
echo "CURRENT_WIN: $CURRENT_WIN ($(printf "0x%08x" $CURRENT_WIN))" >> $LOG
echo "Windows found:" >> $LOG
wmctrl -l -p >> $LOG
for win in $(wmctrl -l | awk '{print $1}' | grep -v $(printf "0x%08x" $CURRENT_WIN)); do
    echo "Closing: $win" >> $LOG
    wmctrl -ic $win
done
sleep 1

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

# launch bspwm via junest (proot with fakeroot for sudo/pacman support)
/home/zsonie/.local/share/junest/bin/junest -b "--bind /sgoinfre /sgoinfre --bind /goinfre /goinfre --bind /dev/shm /dev/shm --bind /run /run --bind /usr /host/usr" -- DRI_PRIME=1 bspwm

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
