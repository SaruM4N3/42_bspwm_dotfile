# Detect primary screen width; fall back to first connected monitor if no primary
SCREEN_W=$(xrandr --current 2>/dev/null | awk '
    /primary/ && match($0,/[0-9]+x[0-9]+/) {
        split(substr($0,RSTART,RLENGTH),a,"x"); w=a[1]; exit
    }
    / connected / && !w && match($0,/[0-9]+x[0-9]+/) {
        split(substr($0,RSTART,RLENGTH),a,"x"); w=a[1]
    }
    END { if (w) print w }
')
: "${SCREEN_W:=3840}"

BAR_CFG="${HOME}/.config/bspwm/rices/${RICE}/config.ini"

if [ "$SCREEN_W" -le 2560 ]; then
    # 1080p/1440p: smaller bar height and fonts
    BAR_CFG="/tmp/SaruM4N3-bar-scaled-${HOME##*/}.ini"
    RICE_DIR="${HOME}/.config/bspwm/rices/${RICE}"
    sed \
        -e "s|include-file = ../../config/|include-file = ${HOME}/.config/bspwm/config/|g" \
        -e "s|include-file = modules.ini|include-file = ${RICE_DIR}/modules.ini|g" \
        -e 's/height = 40/height = 30/g' \
        -e 's/pixelsize=12;/pixelsize=9;/g' \
        -e 's/pixelsize=10;/pixelsize=9;/g' \
        -e 's/pixelsize=8;/pixelsize=9;/g' \
        -e 's/:size=10;/:size=9;/g' \
        -e 's/:size=12;/:size=9;/g' \
        -e 's/:size=14;/:size=11;/g' \
        "${RICE_DIR}/config.ini" > "$BAR_CFG"
    # saru2 workspace icons: bump icon font larger than the rest
    sed -i "/\[bar\/saru2\]/,/\[bar\/saru3\]/{
        s/Material Design Icons Desktop:size=9;/Material Design Icons Desktop:size=12;/g
    }" "$BAR_CFG"
    # Adjust bspwm top padding: offset_y(8) + height(30) + gap(5) = 43
    bspc config top_padding 43
fi

# This file launch the bar/s
for mon in $(polybar --list-monitors | cut -d":" -f1); do
	(
    MONITOR=$mon polybar -q saru1 -c "$BAR_CFG" &
	MONITOR=$mon polybar -q saru2 -c "$BAR_CFG" &
	MONITOR=$mon polybar -q saru3 -c "$BAR_CFG" &
	MONITOR=$mon polybar -q saru4 -c "$BAR_CFG" &
	MONITOR=$mon polybar -q saru5 -c "$BAR_CFG" &
	MONITOR=$mon polybar -q saru6 -c "$BAR_CFG" &
	MONITOR=$mon polybar -q saru7 -c "$BAR_CFG" &
    )
done
