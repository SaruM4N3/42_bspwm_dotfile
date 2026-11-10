#!/bin/bash
# steam-install.sh — Steam install via junest + pacman, outside the home quota.
# Asks where Steam's data (client, config, games) lives:
#   tmp     /tmp/steam-ephemeral       gone on reboot
#   goinfre /goinfre/$USER/steam       kept across reboots, local to this PC
# Skip the question with: steam-installer.sh --tmp | --goinfre
#   (or STEAM_LOCATION=tmp|goinfre). Without a terminal (steam.desktop,
#   app launcher) it asks in a small window: rofi in bspwm, zenity in
#   GNOME; Escape cancels. No window tool at all -> the default is used.
# Other arguments go to steam (steam://..., %U), so this script is also
# the `steam` command (~/.local/bin/steam) and the Steam menu entry.

set -e

TMP_ROOT="/tmp/steam-ephemeral"
GOINFRE_ROOT="/goinfre/$USER/steam"

LOCATION="${STEAM_LOCATION:-}"
case "$1" in
    --tmp)     LOCATION=tmp; shift ;;
    --goinfre) LOCATION=goinfre; shift ;;
    -h|--help) echo "Usage: $(basename "$0") [--tmp | --goinfre] [steam args...]"; exit 0 ;;
esac

# Steam already running: reuse its install (menu actions like Store/Library)
if [ -z "$LOCATION" ]; then
    if pgrep -u "$USER" -f "$GOINFRE_ROOT/steam-home/" >/dev/null; then LOCATION=goinfre
    elif pgrep -u "$USER" -f "$TMP_ROOT/steam-home/" >/dev/null; then LOCATION=tmp
    fi
fi

if [ -z "$LOCATION" ]; then
    if [ ! -d "/goinfre/$USER" ]; then
        LOCATION=tmp          # no goinfre on this machine (outside 42)
    else
        # Default to wherever Steam already is, else /tmp
        default=1
        [ -d "$GOINFRE_ROOT/steam-home" ] && [ ! -d "$TMP_ROOT/steam-home" ] && default=2
        mark() { if [ -d "$1/steam-home" ]; then echo " [existing install]"; fi; }
        OPT1="/tmp - erased on reboot$(mark "$TMP_ROOT")"
        OPT2="goinfre - kept, this PC only$(mark "$GOINFRE_ROOT")"
        if [ -t 0 ]; then
            echo "Where should Steam be installed?"
            echo "  1) /tmp      ($TMP_ROOT) - erased on reboot$(mark "$TMP_ROOT")"
            echo "  2) goinfre   ($GOINFRE_ROOT) - kept, this PC only$(mark "$GOINFRE_ROOT")"
            read -rp "Choice [$default]: " choice
        else
            # Launched from a menu: ask in a window, default entry first
            if [ "$default" = 2 ]; then opts="$OPT2"$'\n'"$OPT1"; else opts="$OPT1"$'\n'"$OPT2"; fi
            THEME="$HOME/.config/bspwm/config/rofi-themes/Keyboard.rasi"
            if [ "$JUNEST_ENV" = "1" ] && command -v rofi >/dev/null; then
                [ -f "$THEME" ] && theme=(-theme "$THEME" -theme-str 'listview { columns: 1; lines: 2; }') || theme=()
                picked=$(printf '%s\n' "$opts" | rofi -dmenu -i -p "Steam" \
                    -mesg "Where should Steam be installed?" "${theme[@]}") || exit 0
            elif command -v zenity >/dev/null; then
                picked=$(printf '%s\n' "$opts" | zenity --list --title="Steam" \
                    --text="Where should Steam be installed?" --column="Location" \
                    --width=420 --height=220 2>/dev/null) || exit 0
            else
                picked=$default
            fi
            case "$picked" in
                /tmp*)    choice=1 ;;
                goinfre*) choice=2 ;;
                1|2)      choice=$picked ;;
                *)        exit 0 ;;   # empty = cancelled
            esac
        fi
        case "${choice:-$default}" in
            1|tmp)     LOCATION=tmp ;;
            2|goinfre) LOCATION=goinfre ;;
            *) echo "Invalid choice: $choice" >&2; exit 1 ;;
        esac
    fi
fi

case "$LOCATION" in
    tmp)     STEAM_ROOT="$TMP_ROOT" ;;
    goinfre) STEAM_ROOT="$GOINFRE_ROOT" ;;
    *) echo "Unknown location: $LOCATION (tmp or goinfre)" >&2; exit 1 ;;
esac
STEAM_DATA="$STEAM_ROOT/steamapps"
STEAM_HOME="$STEAM_ROOT/steam-home"

echo "==> Setting up Steam environment in $STEAM_ROOT"
mkdir -p "$STEAM_DATA" "$STEAM_HOME"

# --- NVIDIA: junest's nvidia-utils never matches the host kernel module, and
# GLX fails on a version mismatch (glXChooseVisual failed). Fetch the exact
# userspace libs (64 + 32 bit) for the host driver from NVIDIA's .run file.
GPU_ENV=""
if [ -r /proc/driver/nvidia/version ]; then
    NV_VER=$(grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' /proc/driver/nvidia/version | head -1)
    NV_DIR="$STEAM_ROOT/nvidia-$NV_VER"
    echo "==> Host NVIDIA driver $NV_VER detected"
    if [ ! -d "$STEAM_ROOT/nvlib64-$NV_VER" ]; then
        echo "==> Downloading matching NVIDIA userspace libs..."
        RUN="$STEAM_ROOT/nv.run"
        curl -fSLo "$RUN" "https://download.nvidia.com/XFree86/Linux-x86_64/$NV_VER/NVIDIA-Linux-x86_64-$NV_VER.run"
        rm -rf "$NV_DIR"
        sh "$RUN" --extract-only --target "$NV_DIR" >/dev/null
        rm -f "$RUN"
        for a in 64 32; do
            src="$NV_DIR"; [ "$a" = 32 ] && src="$NV_DIR/32"
            dst="$STEAM_ROOT/nvlib$a-$NV_VER"
            mkdir -p "$dst"
            cp -a "$src"/libGLX_nvidia.so.* "$src"/libEGL_nvidia.so.* "$src"/libGLESv*_nvidia.so.* \
                  "$src"/libnvidia-*.so.* "$src"/libcuda.so.* "$dst"/ 2>/dev/null || true
            /sbin/ldconfig -n "$dst"
            arch=x86_64; [ "$a" = 32 ] && arch=i686
            sed "s#\"libGLX_nvidia.so.0\"#\"$dst/libGLX_nvidia.so.0\"#" "$NV_DIR/nvidia_icd.json" \
                > "$STEAM_ROOT/nvidia_icd.$arch.json"
        done
        rm -rf "$NV_DIR"
    fi
    GPU_ENV="export LD_LIBRARY_PATH=\"$STEAM_ROOT/nvlib64-$NV_VER:$STEAM_ROOT/nvlib32-$NV_VER\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}\"
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export VK_ICD_FILENAMES=\"$STEAM_ROOT/nvidia_icd.x86_64.json:$STEAM_ROOT/nvidia_icd.i686.json\""
fi

INNER_SCRIPT="$STEAM_ROOT/run-steam.sh"
cat > "$INNER_SCRIPT" << INNEREOF
#!/bin/bash
set -e
if ! pacman -Qi steam &>/dev/null; then
    echo "==> Installing Steam via pacman..."
    sudo pacman -Sy --noconfirm steam
else
    echo "==> Steam already installed, skipping."
fi

export HOME="$STEAM_HOME"
export STEAM_DIR="$STEAM_HOME/.local/share/Steam"
export STEAMCONFIG="$STEAM_HOME/.steam"
export XDG_DATA_HOME="$STEAM_HOME/.local/share"
export XDG_CONFIG_HOME="$STEAM_HOME/.config"
export XDG_CACHE_HOME="$STEAM_HOME/.cache"
$GPU_ENV

mkdir -p "\$STEAM_DIR" "\$STEAMCONFIG"

# /usr/bin/steam, not "steam": that name is this installer (~/.local/bin/steam)
export LIBGL_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
exec /usr/bin/steam "\$@"
INNEREOF
chmod +x "$INNER_SCRIPT"

# Inside the bspwm session we already are in junest (JUNEST_ENV=1), and junest
# refuses to nest ("Nested JuNest environments are not allowed"): run directly.
if [ "$JUNEST_ENV" = "1" ]; then
    echo "==> Already inside junest, running setup..."
    exec bash "$INNER_SCRIPT" "$@"
else
    echo "==> Entering junest and running setup..."
    exec junest -- bash "$INNER_SCRIPT" "$@"
fi
