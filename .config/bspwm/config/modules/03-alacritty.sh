#!/bin/sh

cat >"$HOME"/.config/alacritty/fonts.toml <<-EOF
[font]
size = ${term_font_size}

[font.normal]
family = "${term_font_name}"
style = "Regular"

[font.bold]
family = "${term_font_name}"
style = "Bold"

[font.italic]
family = "${term_font_name}"
style = "Italic"
EOF

cat >"$HOME"/.config/alacritty/rice-colors.toml <<-EOF
# Default colors
[colors.primary]
background = "${bg}"
foreground = "${fg}"

# Cursor colors
[colors.cursor]
cursor = "${fg}"
text = "${bg}"

# Normal colors
[colors.normal]
black = "${black}"
red = "${red}"
green = "${green}"
yellow = "${yellow}"
blue = "${blue}"
magenta = "${magenta}"
cyan = "${cyan}"
white = "${white}"

# Bright colors
[colors.bright]
black = "${blackb}"
red = "${redb}"
green = "${greenb}"
yellow = "${yellowb}"
blue = "${blueb}"
magenta = "${magentab}"
cyan = "${cyanb}"
white = "${whiteb}"
EOF
