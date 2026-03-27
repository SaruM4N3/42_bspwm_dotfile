#!/bin/sh

save-config.sh

# Close only bspwm-managed windows (not GNOME's own processes)
# GNOME will restore its windows when gnome-session resumes
bspc query -N -n '.window' | xargs -I id bspc node id -c 2>/dev/null
sleep 0.5

pkill -x polybar
pkill -x sxhkd
pkill -x picom
pkill -x xsettingsd
pkill -x clipcatd
pkill -f "eww.*bar"
pkill -x eww
pkill -x xwinwrap
bspc quit