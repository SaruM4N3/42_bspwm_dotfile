# =============================================================
#  ███████╗███████╗ ██████╗ ███╗   ██╗██╗███████╗
#  ╚══███╔╝██╔════╝██╔═══██╗████╗  ██║██║██╔════╝
#    ███╔╝ ███████╗██║   ██║██╔██╗ ██║██║█████╗
#   ███╔╝  ╚════██║██║   ██║██║╚██╗██║██║██╔══╝
#  ███████╗███████║╚██████╔╝██║ ╚████║██║███████╗
#  ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝╚══════╝
#
#  Bar.bash — polybar launcher with resolution auto-scaling
#  Repo: https://github.com/SaruM4N3/42_bspwm_dotfile
# =============================================================

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

RICE_DIR="${HOME}/.config/bspwm/rices/${RICE}"
BAR_CFG="${HOME}/.config/bspwm/rices/SaruM4N3/bar-generated.ini"
THEME_CFG="${RICE_DIR}/theme-config.bash"

# Load bar sizing vars from theme-config, with safe fallbacks
. "$THEME_CFG" 2>/dev/null
BAR_HEIGHT_1080="${BAR_HEIGHT_1080:-24}"
BAR_PIXELSIZE_1080="${BAR_PIXELSIZE_1080:-7}"
BAR_HEIGHT_4K="${BAR_HEIGHT_4K:-40}"
BAR_PIXELSIZE_4K="${BAR_PIXELSIZE_4K:-10}"

if [ "$SCREEN_W" -le 1920 ]; then
    # 1080p: resolve paths + scale down bar height and fonts aggressively
    _px="${BAR_PIXELSIZE_1080}"
    _px1=$(( _px + 1 ))
    _px2=$(( _px + 2 ))
    sed \
        -e "s|include-file = ../../config/|include-file = ${HOME}/.config/bspwm/config/|g" \
        -e "s|include-file = modules.ini|include-file = ${RICE_DIR}/modules.ini|g" \
        -e "s/height = 40/height = ${BAR_HEIGHT_1080}/g" \
        -e "s/pixelsize=12;/pixelsize=${_px1};/g" \
        -e "s/pixelsize=10;/pixelsize=${_px};/g" \
        -e "s/:size=14;/:size=${_px2};/g" \
        -e "s/:size=12;/:size=${_px1};/g" \
        -e "s/:size=10;/:size=${_px};/g" \
        -e 's/;3"/;2"/g' \
        "${RICE_DIR}/config.ini" > "$BAR_CFG"
    # saru1 launcher icon: keep slightly larger than blanket scale
    sed -i "/\[bar\/saru1\]/,/\[bar\/saru2\]/{
        s/Material Design Icons Desktop:size=${_px};/Material Design Icons Desktop:size=${_px2};/g
    }" "$BAR_CFG"
    # Adjust bspwm top padding: offset_y(8) + height + gap(5)
    bspc config top_padding $(( BAR_HEIGHT_1080 + 13 ))
elif [ "$SCREEN_W" -le 2560 ]; then
    # 1440p: resolve paths + scale down bar height and fonts
    sed \
        -e "s|include-file = ../../config/|include-file = ${HOME}/.config/bspwm/config/|g" \
        -e "s|include-file = modules.ini|include-file = ${RICE_DIR}/modules.ini|g" \
        -e 's/height = 40/height = 30/g' \
        -e 's/pixelsize=12;/pixelsize=9;/g' \
        -e 's/pixelsize=10;/pixelsize=8;/g' \
        -e 's/:size=14;/:size=11;/g' \
        -e 's/:size=12;/:size=10;/g' \
        -e 's/:size=10;/:size=8;/g' \
        -e 's/;3"/;2"/g' \
        "${RICE_DIR}/config.ini" > "$BAR_CFG"
    # saru1 workspace icons: restore larger icon size after blanket scale
    sed -i "/\[bar\/saru1\]/,/\[bar\/saru2\]/{
        s/Material Design Icons Desktop:size=10;/Material Design Icons Desktop:size=12;/g
    }" "$BAR_CFG"
    # Adjust bspwm top padding: offset_y(8) + height(30) + gap(5) = 43
    bspc config top_padding 43
else
    # 4K: resolve paths + apply theme-config sizing
    _px="${BAR_PIXELSIZE_4K}"
    _px1=$(( _px + 1 ))
    _px2=$(( _px + 2 ))
    sed \
        -e "s|include-file = ../../config/|include-file = ${HOME}/.config/bspwm/config/|g" \
        -e "s|include-file = modules.ini|include-file = ${RICE_DIR}/modules.ini|g" \
        -e "s/height = 40/height = ${BAR_HEIGHT_4K}/g" \
        -e "s/pixelsize=12;/pixelsize=${_px1};/g" \
        -e "s/pixelsize=10;/pixelsize=${_px};/g" \
        -e "s/:size=14;/:size=${_px2};/g" \
        -e "s/:size=12;/:size=${_px1};/g" \
        -e "s/:size=10;/:size=${_px};/g" \
        "${RICE_DIR}/config.ini" > "$BAR_CFG"
    # Adjust bspwm top padding: offset_y(8) + height + gap(5)
    bspc config top_padding $(( BAR_HEIGHT_4K + 13 ))
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
