#############################
#		SaruM4N3 Theme		#
#############################

# (Lovelace) colorscheme from Elenapan
bg="#1A1B26"
fg="#C0CAF5"

black="#15161E"
red="#F7768E"
green="#9ECE6A"
yellow="#E0AF68"
blue="#7AA2F7"
magenta="#BB9AF7"
cyan="#7DCFFF"
white="#A9B1D6"
blackb="#414868"
redb="#F7768E"
greenb="#9ECE6A"
yellowb="#E0AF68"
blueb="#7AA2F7"
magentab="#BB9AF7"
cyanb="#7DCFFF"
whiteb="#C0CAF5"

accent_color="#24283B"
arch_icon="#0f94d2"

# Bspwm options
BORDER_WIDTH="2"		# Bspwm border
WINDOW_GAP="6"			# Gap between windows
TOP_PADDING="53"
BOTTOM_PADDING="1"
LEFT_PADDING="1"
RIGHT_PADDING="1"
NORMAL_BC="#1C71D8"
FOCUSED_BC="#24FF00"

# Terminal font & size
term_font_size="8"
term_font_name="Adwaita Mono"

# Picom options
# Bar sizing (per resolution — edited via RiceSettings)
BAR_HEIGHT_4K="35"
BAR_HEIGHT_1080="24"
BAR_PIXELSIZE_4K="12"
BAR_PIXELSIZE_1080="7"

P_FADE="false"
P_SHADOWS="false"
SHADOW_C="#000000"
P_CORNER_R="18"			# Corner radius (0 = disabled)
P_BLUR="false"			# Blur true|false
P_ANIMATIONS="@"		# (@ = enable) (# = disable)
P_TERM_OPACITY="0.70"	# Terminal transparency. Range: 0.1 - 1.0 (1.0 = disabled)

# Dunst
dunst_offset='(28, 65)'
dunst_origin='top-right'
dunst_transparency='9'
dunst_corner_radius='6'
dunst_font='JetBrainsMono Nerd Font Mono 9'
dunst_border='0'
dunst_frame_color="$blue"
dunst_icon_theme="Gruvbox-Plus-Dark"
# Dunst animations
dunst_close_preset="fly-out"
dunst_close_direction="up"
dunst_open_preset="fly-in"
dunst_open_direction="right"

# Jgmenu colors
jg_bg="$bg"
jg_fg="$fg"
jg_sel_bg="$blueb"
jg_sel_fg="$fg"
jg_sep="$blueb"

# Rofi menu font and colors
rofi_font="JetBrainsMono Nerd Font Mono Bold 10"
rofi_background="${bg}a8"
rofi_bg_alt="${accent_color}a8"
rofi_background_alt="${bg}a5"
rofi_fg="$fg"
rofi_selected="$blueb"
rofi_active="$greenb"
rofi_urgent="$redb"

# Gtk theme
gtk_theme="LoveLace-zk"
gtk_icons="Luv-Folders"
gtk_cursor="Qogirr-Dark"

# Wallpaper engine
# Available engines:
# - Random  (Set a random wallpaper from Walls rice directory)
# - CustomDir   (Set a random wallpaper from the directory you specified)
# - Default (Sets a specific image as wallpaper) *Default
# - Animated (Set an animated wallpaper. "mp4, mkv, gif")
# - Slideshow (Change randomly every 15 minutes your wallpaper from Walls rice directory)
ENGINE="Animated"

CUSTOM_DIR="/path/to/your/wallpapers/directory"
DEFAULT_WALL="/home/zsonie/.config/bspwm/rices/SaruM4N3/walls/wall-01.webp"
ANIMATED_WALL="/home/zsonie/Pictures/AnimatedWallpaper/frog-sleeping-near-the-waterfall-moewalls-com.mp4"
