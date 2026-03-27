#!/bin/sh

picom_conf_file="$HOME/.config/bspwm/config/picom.conf"
picom_animations_file="$HOME/.config/bspwm/config/picom-animations.conf"
picom_backup="$HOME/.local/share/gh0stzk/config/bspwm/config/picom.conf"
picom_animations_backup="$HOME/.local/share/gh0stzk/config/bspwm/config/picom-animations.conf"

# Restore from backup if files are empty
[ ! -s "$picom_conf_file" ] && [ -f "$picom_backup" ] && cp "$picom_backup" "$picom_conf_file"
[ ! -s "$picom_animations_file" ] && [ -f "$picom_animations_backup" ] && cp "$picom_animations_backup" "$picom_animations_file"

sed -i "$picom_conf_file" \
    -e "s/shadow-color = .*/shadow-color = \"${SHADOW_C}\"/" \
    -e "s/^corner-radius = .*/corner-radius = ${P_CORNER_R}/" \
    -e "/#-term-opacity-switch/s/.*#-/\t\topacity = $P_TERM_OPACITY;\t#-/" \
    -e "/#-shadow-switch/s/.*#-/\t\tshadow = ${P_SHADOWS};\t#-/" \
    -e "/#-fade-switch/s/.*#-/\t\tfade = ${P_FADE};\t#-/" \
    -e "/#-blur-switch/s/.*#-/\t\tblur-background = ${P_BLUR};\t#-/" \
    -e "/picom-animations/c\\${P_ANIMATIONS}include \"picom-animations.conf\""

sed -i "$picom_animations_file" \
    -e "/#-dunst-close-preset/s/.*#-/\t\t\tpreset = \"${dunst_close_preset}\";\t#-/" \
    -e "/#-dunst-close-direction/s/.*#-/\t\t\tdirection = \"${dunst_close_direction}\";\t#-/" \
    -e "/#-dunst-open-preset/s/.*#-/\t\t\tpreset = \"${dunst_open_preset}\";\t#-/" \
    -e "/#-dunst-open-direction/s/.*#-/\t\t\tdirection = \"${dunst_open_direction}\";\t#-/"
