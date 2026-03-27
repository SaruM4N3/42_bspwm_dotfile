#!/bin/bash
# ============================================================
# install_prerequisites_pacman.sh
# Install bspwm dotfiles dependencies (Arch Linux / pacman + yay)
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

# ── Check for yay (AUR helper) ────────────────────────────────────────────────
if ! command -v yay &>/dev/null; then
    warn "yay not found — installing it first..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
fi

# ── Core WM ───────────────────────────────────────────────────────────────────
info "Installing core WM packages..."
yay -S --needed --noconfirm \
    bspwm \
    sxhkd \
    picom-git \
    polybar \
    rofi \
    dunst \
    xsettingsd \
    xorg-xrandr \
    xdotool \
    wmctrl

# ── Terminal & launcher ───────────────────────────────────────────────────────
info "Installing terminal and launcher..."
yay -S --needed --noconfirm \
    alacritty \
    jgmenu

# ── Media & audio ─────────────────────────────────────────────────────────────
info "Installing media packages..."
yay -S --needed --noconfirm \
    mpd \
    mpc \
    mpv \
    playerctl \
    ffmpeg

# ── Bluetooth ─────────────────────────────────────────────────────────────────
info "Installing bluetooth..."
yay -S --needed --noconfirm \
    bluez \
    bluez-utils

# ── Brightness, system ────────────────────────────────────────────────────────
info "Installing system utilities..."
yay -S --needed --noconfirm \
    brightnessctl \
    lxsession \
    xclip \
    jq \
    curl \
    bc \
    feh \
    imagemagick

# ── Clipboard ─────────────────────────────────────────────────────────────────
info "Installing clipcat (AUR)..."
yay -S --needed --noconfirm clipcat

# ── Animated wallpaper (xwinwrap) ─────────────────────────────────────────────
info "Installing xwinwrap (AUR)..."
yay -S --needed --noconfirm xwinwrap-git

# ── eww widgets ───────────────────────────────────────────────────────────────
info "Installing eww (AUR)..."
yay -S --needed --noconfirm eww-git

# ── Fonts ─────────────────────────────────────────────────────────────────────
info "Installing fonts..."
yay -S --needed --noconfirm \
    ttf-jetbrains-mono \
    ttf-font-awesome \
    ttf-material-design-icons-desktop-git

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