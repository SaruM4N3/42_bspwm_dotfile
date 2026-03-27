#!/bin/bash

MONITOR_PID=$(pgrep -f "gnome-session-ctl --monitor")
BINARY_PIDS=$(pgrep -f "gnome-session-binary")

kill -STOP $MONITOR_PID
for pid in $BINARY_PIDS; do kill -STOP $pid; done

killall -9 gnome-shell 2>/dev/null

/home/zsonie/.local/share/junest/bin/junest -b "--bind /sgoinfre /sgoinfre --bind /goinfre /goinfre --bind /dev/shm /dev/shm --bind /run /run --bind /usr /host/usr" -- bspwm

for pid in $BINARY_PIDS; do kill -CONT $pid; done
kill -CONT $MONITOR_PID
