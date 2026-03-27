#!/bin/sh
# =============================================================
# Author: gh0stzk (modified for junest - no bluetoothctl)
# Bluetooth Status Checker for Polybar
# Uses /sys/class/rfkill to avoid bluetoothctl dependency
# ----------------------------------------------------------------------------

# Hardware Validation
BT_CLASS_PATH="/sys/class/bluetooth"
[ -d "$BT_CLASS_PATH" ] || exit 0

# Config Handling
CONFIG_DIR="${HOME}/.config/bspwm"
read -r current_rice < "${CONFIG_DIR}"/.rice
config_file="${CONFIG_DIR}/rices/${current_rice}/config.ini"

# Color Extraction with Fallbacks
read_power_colors() {
    awk 'BEGIN {on=""; off=""}
        /^blue =/ {on=$3; if (off != "") exit}
        /^grey =/ {off=$3; if (on != "") exit}
        END {print on " " off}' "$config_file"
}

if [ -f "$config_file" ]; then
    set -- $(read_power_colors)
    POWER_ON="$1"
    POWER_OFF="$2"
else
    POWER_ON="#ffffff"
    POWER_OFF="#666666"
fi

# Check power state via rfkill sysfs (works without bluetoothctl)
BT_ON=0
for rfkill in /sys/class/rfkill/rfkill*; do
    [ "$(cat "$rfkill/type" 2>/dev/null)" = "bluetooth" ] || continue
    state=$(cat "$rfkill/state" 2>/dev/null)
    soft=$(cat "$rfkill/soft" 2>/dev/null)
    if [ "$state" = "1" ] && [ "$soft" = "0" ]; then
        BT_ON=1
    fi
    break
done

truncate_name() {
    name="$1"
    max=14
    if [ "${#name}" -gt "$max" ]; then
        echo "$(echo "$name" | cut -c1-$max)..."
    else
        echo "$name"
    fi
}

if [ "$BT_ON" = "1" ]; then
    connected=$(bluetoothctl devices Connected 2>/dev/null | grep Device | cut -d' ' -f3-)
    if [ -n "$connected" ]; then
        label=$(truncate_name "$connected")
        echo "%{F${POWER_ON}}%{T3}󰂯%{T1}%{F-} $label"
    else
        echo "%{F${POWER_ON}}%{T3}󰂯%{T1}%{F-} Disconnected"
    fi
else
    echo "%{F${POWER_OFF}}%{T3}󰂲%{T1}%{F-} Off"
fi

exit 0