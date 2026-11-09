#!/bin/bash
# steam-install.sh — Ephemeral Steam install via junest + pacman
# Everything lives in /tmp and is gone on reboot.

set -e

STEAM_ROOT="/tmp/steam-ephemeral"
STEAM_DATA="$STEAM_ROOT/steamapps"
STEAM_HOME="$STEAM_ROOT/steam-home"

echo "==> Setting up ephemeral Steam environment in $STEAM_ROOT"
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

exec steam
INNEREOF
chmod +x "$INNER_SCRIPT"

echo "==> Entering junest and running setup..."
junest -- bash "$INNER_SCRIPT"
