#!/bin/bash
# ============================================================
# install_prerequisites_apt.sh
# Install bspwm dotfiles dependencies (Debian / Ubuntu / apt)
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

# ── Core WM ───────────────────────────────────────────────────────────────────
info "Installing core WM packages..."
sudo apt install -y \
    bspwm \
    sxhkd \
    picom \
    polybar \
    rofi \
    dunst \
    xsettingsd \
    x11-xserver-utils \
    xdotool \
    wmctrl

# ── Terminal & launcher ───────────────────────────────────────────────────────
info "Installing terminal and launcher..."
sudo apt install -y \
    alacritty \
    jgmenu

# ── Media & audio ─────────────────────────────────────────────────────────────
info "Installing media packages..."
sudo apt install -y \
    mpd \
    mpc \
    mpv \
    playerctl \
    ffmpeg

# ── Bluetooth ─────────────────────────────────────────────────────────────────
info "Installing bluetooth..."
sudo apt install -y \
    bluez \
    bluetooth

# ── Brightness, system ────────────────────────────────────────────────────────
info "Installing system utilities..."
sudo apt install -y \
    brightnessctl \
    lxpolkit \
    xclip \
    jq \
    curl \
    bc \
    feh \
    imagemagick

# ── Clipboard (clipcat — not in apt, build from source) ───────────────────────
info "Installing clipcat from source (requires Rust)..."
if ! command -v cargo &>/dev/null; then
    warn "Rust not found — installing via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi
cargo install clipcat

# ── Animated wallpaper (xwinwrap — not in apt, build from source) ─────────────
info "Installing xwinwrap from source..."
sudo apt install -y libx11-dev libxext-dev libxrender-dev libxcomposite-dev
git clone https://github.com/mmhobi7/xwinwrap.git /tmp/xwinwrap
(cd /tmp/xwinwrap && make && sudo make install)
rm -rf /tmp/xwinwrap

# ── eww widgets (not in apt, build from source) ───────────────────────────────
info "Installing eww from source (requires Rust)..."
if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi
sudo apt install -y libgtk-3-dev libglib2.0-dev
git clone https://github.com/elkowar/eww.git /tmp/eww
(cd /tmp/eww && cargo build --release --no-default-features --features x11)
sudo install -m755 /tmp/eww/target/release/eww /usr/local/bin/eww
rm -rf /tmp/eww

# ── Fonts ─────────────────────────────────────────────────────────────────────
info "Installing fonts..."
sudo apt install -y fonts-jetbrains-mono

info "Copying bundled fonts to ~/.local/share/fonts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTS_SRC="$SCRIPT_DIR/../.local/share/fonts"
if [ -d "$FONTS_SRC" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$FONTS_SRC"/. "$HOME/.local/share/fonts/"
    fc-cache -fv
    info "Fonts installed."
else
    warn "Bundled fonts directory not found at $FONTS_SRC — skipping."
fi

# ── Enable bluetooth service ──────────────────────────────────────────────────
info "Enabling bluetooth service..."
sudo systemctl enable --now bluetooth.service

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "All prerequisites installed."
warn "Note: This config was built for a 42 school junest environment."
warn "      ft_lock (/host/usr/share/42/ft_lock) is 42-specific and won't exist elsewhere."
warn "      The lock button in the eww profilecard will need to be changed for non-42 use."