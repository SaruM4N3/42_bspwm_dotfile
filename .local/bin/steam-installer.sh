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
STEAM_ROOT="$STEAM_ROOT"
STEAM_HOME="$STEAM_HOME"
$GPU_ENV
INNEREOF
# Rest runs as is inside junest (quoted heredoc: nothing expanded here)
cat >> "$INNER_SCRIPT" << 'INNEREOF'
ARCHIVE="https://archive.archlinux.org/packages"
MESA_VER=$(pacman -Q mesa 2>/dev/null | awk '{print $2}')

# Steam needs multilib (32-bit client); old installs never enabled it
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    echo "==> Enabling the multilib repository..."
    if grep -q '^#\[multilib\]' /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
    else
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    fi
    sudo pacman -Sy --noconfirm
fi

# The mesa pin (IgnorePkg mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon)
# hides these from pacman -S: steam's dependencies would then fall back on
# other providers (lib32-mesa-amber, which conflicts with mesa; nvidia-utils
# for vulkan-driver). Install them first, on mesa's version from the archive.
if [ -n "$MESA_VER" ]; then
    urls=()
    for p in vulkan-radeon lib32-mesa lib32-vulkan-radeon; do
        [ "$(pacman -Q "$p" 2>/dev/null | awk '{print $2}')" = "$MESA_VER" ] && continue
        urls+=("$ARCHIVE/${p:0:1}/$p/$p-$MESA_VER-x86_64.pkg.tar.zst")
    done
    if [ ${#urls[@]} -gt 0 ]; then
        echo "==> Installing the pinned mesa $MESA_VER drivers (32-bit + Vulkan)..."
        sudo pacman -U --noconfirm "${urls[@]}" ||
            echo "==> WARNING: could not install mesa $MESA_VER drivers, steam may pull conflicting ones" >&2
    fi
fi

if ! pacman -Qi steam &>/dev/null; then
    echo "==> Installing Steam via pacman..."
    sudo pacman -S --needed --noconfirm steam || sudo pacman -Sy --noconfirm steam
else
    echo "==> Steam already installed, skipping."
fi

# --- 32-bit Mesa (Mac / Dell): the Steam client is 32-bit and uses junest's
# lib32-mesa. mesa is pinned (IgnorePkg, kernel 5.15) but installing steam can
# pull a newer lib32-mesa: put it back on mesa's version from the Arch archive.
if [ -n "$MESA_VER" ]; then
    for p in lib32-mesa lib32-vulkan-radeon; do
        v=$(pacman -Q "$p" 2>/dev/null | awk '{print $2}')
        if [ -n "$v" ] && [ "$v" != "$MESA_VER" ]; then
            echo "==> $p $v -> $MESA_VER (same as mesa)"
            sudo pacman -U --noconfirm "$ARCHIVE/l/$p/$p-$MESA_VER-x86_64.pkg.tar.zst" ||
                echo "==> WARNING: could not install $p $MESA_VER" >&2
        fi
    done
fi

# The pinned lib32-mesa (24.3.4) links older libraries than current Arch
# ships: libLLVM.so.19.1, which in turn needs libxml2.so.2 and ICU 76. Without
# them the Steam client dies on "glXChooseVisual failed" and 32-bit Proton
# games crash in dxgi.dll (no 32-bit Vulkan driver). Put the old sonames in
# /usr/lib32 itself: LD_LIBRARY_PATH would reach the client but not the
# pressure-vessel container games run in. Only missing sonames are added,
# pacman-owned files are never overwritten.
lib32_pkg_for() {   # soname -> "package version-regex" in the Arch archive
    case "$1" in
        libLLVM.so.*) echo "lib32-llvm-libs ([0-9]+:)?${1#libLLVM.so.}\.[0-9]+-[0-9]+" ;;
        libxml2.so.2) echo "lib32-libxml2 ([0-9]+:)?2\.13\.[0-9]+-[0-9]+" ;;
        libicu*.so.*) echo "lib32-icu ([0-9]+:)?${1##*.so.}\.[0-9.]+-[0-9]+" ;;
    esac
}
LIB32_TMP=$(mktemp -d)
for round in 1 2 3 4 5; do
    missing=$(for f in /usr/lib32/libgallium-*.so /usr/lib32/libvulkan_radeon.so /usr/lib32/libGLX_mesa.so.0; do
                  [ -e "$f" ] && ldd "$f" 2>/dev/null | awk '/not found/ {print $1}'
                  true
              done | sort -u)
    [ -z "$missing" ] && break
    progress=0
    for so in $missing; do
        read -r pkg ver <<< "$(lib32_pkg_for "$so")"
        if [ -z "$pkg" ]; then
            echo "==> WARNING: 32-bit mesa needs $so, no known package for it" >&2
            continue
        fi
        PKG=$(curl -fsSL "$ARCHIVE/l/$pkg/" |
              grep -oE "$pkg-$ver-x86_64\.pkg\.tar\.zst" | sort -uV | tail -1)
        if [ -z "$PKG" ]; then
            echo "==> WARNING: 32-bit mesa needs $so, not found in the Arch archive" >&2
            continue
        fi
        if [ ! -d "$LIB32_TMP/$PKG" ]; then
            echo "==> 32-bit mesa needs $so, fetching $PKG..."
            mkdir -p "$LIB32_TMP/$PKG"
            curl -fSL "$ARCHIVE/l/$pkg/$PKG" |
                tar --zstd -xf - -C "$LIB32_TMP/$PKG" usr/lib32 || continue
        fi
        # versioned libs only (never libLLVM.so / libxml2.so dev links), no overwrite
        for f in "$LIB32_TMP/$PKG"/usr/lib32/*.so.*; do
            [ -e "/usr/lib32/$(basename "$f")" ] || { sudo cp -a "$f" /usr/lib32/ && progress=1; }
        done
    done
    [ "$progress" = 1 ] || { echo "==> WARNING: 32-bit mesa still misses: $missing (Steam/32-bit games may fail)" >&2; break; }
done
rm -rf "$LIB32_TMP"
# Old installs kept libLLVM in $STEAM_ROOT/lib32-llvm (LD_LIBRARY_PATH): now unused
[ -d "$STEAM_ROOT/lib32-llvm" ] && ! ldd /usr/lib32/libvulkan_radeon.so 2>/dev/null | grep -q 'not found' &&
    rm -rf "$STEAM_ROOT/lib32-llvm"

export HOME="$STEAM_HOME"
export STEAM_DIR="$STEAM_HOME/.local/share/Steam"
export STEAMCONFIG="$STEAM_HOME/.steam"
export XDG_DATA_HOME="$STEAM_HOME/.local/share"
export XDG_CONFIG_HOME="$STEAM_HOME/.config"
export XDG_CACHE_HOME="$STEAM_HOME/.cache"

mkdir -p "$STEAM_DIR" "$STEAMCONFIG"

# GL stack. bspwmrc forces the host Ubuntu libGL (GL_SHIM, mesa 23.2) for 64-bit
# apps, but pressure-vessel (Proton games) can't rebuild that mixed Ubuntu/Arch
# stack in its container: the 64-bit dri dir comes out empty ("failed to open
# iris ... wrong ELF class"). When junest's own 64-bit mesa loads (its libLLVM is
# installed, e.g. llvm19-libs), Steam uses the pure Arch stack for 32 and 64 bit.
GALLIUM64=$(ls /usr/lib/libgallium-*.so 2>/dev/null | head -1)
if [ -z "${__GLX_VENDOR_LIBRARY_NAME:-}" ] && [ -n "$GALLIUM64" ] &&
   ! ldd "$GALLIUM64" 2>/dev/null | grep -q "not found"; then
    clean=""
    IFS=: read -ra parts <<< "${LD_LIBRARY_PATH:-}"
    for d in "${parts[@]}"; do
        case "$d" in ""|*/gl-host|/usr/lib/x86_64-linux-gnu) continue ;; esac
        clean="${clean:+$clean:}$d"
    done
    export LD_LIBRARY_PATH="$clean"
    unset GL_SHIM
    export LIBGL_DRIVERS_PATH=/usr/lib/dri:/usr/lib32/dri
    echo "==> GL: junest mesa ($(basename "$GALLIUM64")) for 32 and 64 bit"
else
    # 64-bit apps use the host Ubuntu drivers, the 32-bit client junest's lib32-mesa
    export LIBGL_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri:/usr/lib32/dri
    [ -z "${__GLX_VENDOR_LIBRARY_NAME:-}" ] &&
        echo "==> WARNING: junest 64-bit mesa can't load (libLLVM missing?), using host GL; Proton games may fail" >&2
fi
# /usr/bin/steam, not "steam": that name is this installer (~/.local/bin/steam)
exec /usr/bin/steam "$@"
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
