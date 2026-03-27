#!/bin/bash
# ============================================================
# install_prerequisites_pacman.sh
# Install bspwm dotfiles dependencies inside junest (Arch / pacman)
# Package list mirrors the original RiceInstaller by gh0stzk.
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

add_chaotic_repo() {
    if grep -q '\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null; then
        info "chaotic-aur already configured."
        return
    fi
    info "Adding chaotic-aur repository..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy --noconfirm
    info "chaotic-aur added."
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

# ── Chaotic-AUR (binary AUR repo — provides eww-git, picom-git, etc.) ────────
add_chaotic_repo

# ── Core WM ──────────────────────────────────────────────────────────────────
info "Installing core WM packages..."
sudo pacman -S --needed --noconfirm \
    bspwm \
    sxhkd \
    polybar \
    rofi \
    dunst \
    xsettingsd \
    xorg-xrandr \
    xorg-xdpyinfo \
    xorg-xkill \
    xorg-xprop \
    xorg-xrdb \
    xorg-xsetroot \
    xorg-xwininfo \
    xdotool \
    xdo \
    wmctrl

# ── Terminals ────────────────────────────────────────────────────────────────
info "Installing terminals and launcher..."
sudo pacman -S --needed --noconfirm \
    alacritty \
    kitty \
    jgmenu

# ── File manager ─────────────────────────────────────────────────────────────
info "Installing file manager..."
sudo pacman -S --needed --noconfirm \
    thunar \
    tumbler \
    gvfs-mtp \
    yazi

# ── Editors ──────────────────────────────────────────────────────────────────
info "Installing editors..."
sudo pacman -S --needed --noconfirm \
    geany \
    neovim

# ── Media & audio ────────────────────────────────────────────────────────────
info "Installing media packages..."
sudo pacman -S --needed --noconfirm \
    mpd \
    mpc \
    ncmpcpp \
    mpv \
    playerctl \
    pamixer \
    ffmpeg

# ── Bluetooth ────────────────────────────────────────────────────────────────
info "Installing bluetooth packages..."
sudo pacman -S --needed --noconfirm \
    bluez \
    bluez-utils

# ── System utilities ─────────────────────────────────────────────────────────
info "Installing system utilities..."
sudo pacman -S --needed --noconfirm \
    brightnessctl \
    lxsession \
    xclip \
    xdg-user-dirs \
    jq \
    curl \
    bc \
    feh \
    maim \
    imagemagick \
    redshift \
    xcolor \
    libwebp \
    webp-pixbuf-loader \
    python-gobject \
    pacman-contrib \
    npm

# ── CLI tools ────────────────────────────────────────────────────────────────
info "Installing CLI tools..."
sudo pacman -S --needed --noconfirm \
    bat \
    eza \
    fzf

# ── Icons & themes ───────────────────────────────────────────────────────────
info "Installing icons and themes..."
sudo pacman -S --needed --noconfirm \
    papirus-icon-theme

# ── Shell ────────────────────────────────────────────────────────────────────
info "Installing zsh and plugins..."
sudo pacman -S --needed --noconfirm \
    zsh \
    zsh-autosuggestions \
    zsh-history-substring-search \
    zsh-syntax-highlighting

# ── Fonts ────────────────────────────────────────────────────────────────────
info "Installing fonts..."
sudo pacman -S --needed --noconfirm \
    fontconfig \
    ttf-inconsolata \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    ttf-terminus-nerd \
    ttf-ubuntu-mono-nerd \
    ttf-font-awesome

# ── Clipboard ────────────────────────────────────────────────────────────────
info "Installing clipcat..."
sudo pacman -S --needed --noconfirm clipcat

# ── Chaotic-AUR packages (prebuilt binaries — much faster than AUR build) ────
info "Installing picom-git, xwinwrap, eww-git from chaotic-aur..."
sudo pacman -S --needed --noconfirm \
    picom-git \
    xwinwrap-git \
    eww-git

# ── AUR packages (not available in chaotic-aur) ───────────────────────────────
patch_makepkg

info "Installing ttf-material-design-icons (AUR)..."
aur_install ttf-material-design-icons-desktop-git

# ── Bundled fonts ─────────────────────────────────────────────────────────────
info "Copying bundled fonts to ~/.local/share/fonts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTS_SRC="$SCRIPT_DIR/../.local/share/fonts"
if [ -d "$FONTS_SRC" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$FONTS_SRC"/. "$HOME/.local/share/fonts/"
    fc-cache -fv || warn "fc-cache failed — fonts may need a manual cache refresh."
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