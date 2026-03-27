#!/bin/bash
# ============================================================
# install_prerequisites_pacman.sh
# Install bspwm dotfiles dependencies inside junest (Arch / pacman)
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

patch_makepkg() {
    # makepkg refuses to run as root — patch the check out (junest proot workaround)
    if grep -q 'EUID == 0' /usr/bin/makepkg 2>/dev/null; then
        sudo sed -i 's/|| (( EUID == 0 ))//' /usr/bin/makepkg
        info "makepkg root check patched."
    fi
}

aur_install() {
    local pkg="$1"
    info "Building AUR package: $pkg"
    rm -rf "/tmp/$pkg"
    git clone "https://aur.archlinux.org/${pkg}.git" "/tmp/$pkg"
    (cd "/tmp/$pkg" && makepkg -si --noconfirm)
    rm -rf "/tmp/$pkg"
}

# ── Update keyring + full system sync ────────────────────────────────────────
info "Syncing package databases..."
echo "n" | sudo pacman -Syu || true

info "Installing fresh archlinux-keyring..."
sudo pacman -S --noconfirm archlinux-keyring
sudo pacman-key --populate archlinux

info "Running full system upgrade..."
sudo pacman -Syu --noconfirm

# ── Base build tools ─────────────────────────────────────────────────────────
info "Installing base-devel and git..."
sudo pacman -S --needed --noconfirm base-devel git

# ── Core WM (official repos) ─────────────────────────────────────────────────
info "Installing core WM packages..."
sudo pacman -S --needed --noconfirm \
    bspwm \
    sxhkd \
    polybar \
    rofi \
    dunst \
    xsettingsd \
    xorg-xrandr \
    xdotool \
    wmctrl

# ── Terminal & launcher (official repos) ─────────────────────────────────────
info "Installing terminal and launcher..."
sudo pacman -S --needed --noconfirm \
    alacritty \
    jgmenu

# ── Media & audio (official repos) ───────────────────────────────────────────
info "Installing media packages..."
sudo pacman -S --needed --noconfirm \
    mpd \
    mpc \
    mpv \
    playerctl \
    ffmpeg

# ── Bluetooth (official repos) ───────────────────────────────────────────────
info "Installing bluetooth packages..."
sudo pacman -S --needed --noconfirm \
    bluez \
    bluez-utils

# ── System utilities (official repos) ────────────────────────────────────────
info "Installing system utilities..."
sudo pacman -S --needed --noconfirm \
    brightnessctl \
    lxsession \
    xclip \
    jq \
    curl \
    bc \
    feh \
    imagemagick

# ── Fonts (official repos) ───────────────────────────────────────────────────
info "Installing fonts..."
sudo pacman -S --needed --noconfirm \
    ttf-jetbrains-mono \
    ttf-font-awesome

# ── AUR packages (built from source with makepkg) ────────────────────────────
patch_makepkg
info "Installing picom-git (AUR)..."
aur_install picom-git

info "Installing clipcat (GitHub release binary)..."
CLIPCAT_VER=$(curl -s https://api.github.com/repos/xrelkd/clipcat/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
curl -L "https://github.com/xrelkd/clipcat/releases/download/v${CLIPCAT_VER}/clipcat-v${CLIPCAT_VER}-x86_64-unknown-linux-musl.tar.gz" \
    -o /tmp/clipcat.tar.gz
tar -xzf /tmp/clipcat.tar.gz -C /tmp/
sudo install -m755 /tmp/clipcat*/clipcatd  /usr/local/bin/clipcatd
sudo install -m755 /tmp/clipcat*/clipcatctl /usr/local/bin/clipcatctl
rm -rf /tmp/clipcat*

info "Installing xwinwrap (AUR)..."
aur_install xwinwrap-git

info "Installing eww (AUR)..."
aur_install eww-git

info "Installing ttf-material-design-icons (AUR)..."
aur_install ttf-material-design-icons-desktop-git

# ── Bundled fonts ─────────────────────────────────────────────────────────────
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

# ── Bluetooth service ─────────────────────────────────────────────────────────
warn "Bluetooth: enable the service on your host system with:"
warn "  sudo systemctl enable --now bluetooth.service"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "All prerequisites installed."
warn "Note: This config was built for a 42 school junest environment."
warn "      ft_lock (/host/usr/share/42/ft_lock) is 42-specific and won't exist elsewhere."
warn "      The lock button in the eww profilecard will need to be changed for non-42 use."