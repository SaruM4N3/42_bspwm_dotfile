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

ask_browser() {
    printf "\nWhich browser do you want to install? (default: brave)\n"
    printf "  1) brave\n  2) firefox\n  3) chromium\n  4) google-chrome\n"
    printf "Enter number [1]: "
    read -r browser_choice
    case "$browser_choice" in
        1|"") BROWSER_PKG="brave-bin";      BROWSER_BIN="brave" ;;
        2)    BROWSER_PKG="firefox";        BROWSER_BIN="firefox" ;;
        3)    BROWSER_PKG="chromium";       BROWSER_BIN="chromium" ;;
        4)    BROWSER_PKG="google-chrome";  BROWSER_BIN="google-chrome-stable" ;;
        *)    BROWSER_PKG="brave-bin";      BROWSER_BIN="brave" ;;
    esac
    info "Browser selected: $BROWSER_BIN (package: $BROWSER_PKG)"
}

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

add_gh0stzk_repo() {
    if grep -q '\[gh0stzk-dotfiles\]' /etc/pacman.conf 2>/dev/null; then
        info "gh0stzk-dotfiles repo already configured."
        return
    fi
    info "Adding gh0stzk-dotfiles repository..."
    printf '\n[gh0stzk-dotfiles]\nSigLevel = Optional TrustAll\nServer = http://gh0stzk.github.io/pkgs/x86_64\n' \
        | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy --noconfirm
    info "gh0stzk-dotfiles repo added."
}

# ── Interactive setup (ask before any installs) ───────────────────────────────
ask_browser

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

# ── Chaotic-AUR + gh0stzk custom repo ────────────────────────────────────────
add_chaotic_repo
add_gh0stzk_repo

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
    btop \
    micro

# ── Icons & themes ───────────────────────────────────────────────────────────
info "Installing icons and themes..."
sudo pacman -S --needed --noconfirm \
    papirus-icon-theme

# ── gh0stzk GTK themes, cursors and icon packs ───────────────────────────────
info "Installing gh0stzk GTK themes, cursors and icon sets..."
sudo pacman -S --needed --noconfirm \
    gh0stzk-gtk-themes \
    gh0stzk-cursor-qogirr \
    gh0stzk-icons-beautyline \
    gh0stzk-icons-candy \
    gh0stzk-icons-catppuccin-mocha \
    gh0stzk-icons-dracula \
    gh0stzk-icons-glassy \
    gh0stzk-icons-gruvbox-plus-dark \
    gh0stzk-icons-hack \
    gh0stzk-icons-luv \
    gh0stzk-icons-sweet-rainbow \
    gh0stzk-icons-tokyo-night \
    gh0stzk-icons-vimix-white \
    gh0stzk-icons-zafiro \
    gh0stzk-icons-zafiro-purple

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

# ── picom (official repo) ─────────────────────────────────────────────────────
info "Installing picom..."
sudo pacman -S --needed --noconfirm picom

# ── eww-git (chaotic-aur prebuilt) ───────────────────────────────────────────
info "Installing eww-git from chaotic-aur..."
sudo pacman -S --needed --noconfirm eww-git

# ── AUR packages ──────────────────────────────────────────────────────────────
patch_makepkg

info "Installing xwinwrap-0.9-bin (AUR)..."
aur_install xwinwrap-0.9-bin

info "Installing fzf-tab-git (AUR)..."
aur_install fzf-tab-git

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

# ── Browser ──────────────────────────────────────────────────────────────────
info "Installing browser: $BROWSER_PKG..."
sudo pacman -S --needed --noconfirm "$BROWSER_PKG"

# Patch sxhkdrc (super+w) and OpenApps (--browser) with chosen browser
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for sxhkd in \
    "$DOTFILES_DIR/.config/bspwm/config/sxhkdrc" \
    "$DOTFILES_DIR/.config/bspwm/config/.session/sxhkdrc"; do
    [ -f "$sxhkd" ] && sed -i "s|^\tbrave$|\t$BROWSER_BIN|" "$sxhkd"
done
OPENAPPS="$DOTFILES_DIR/.config/bspwm/bin/OpenApps"
[ -f "$OPENAPPS" ] && sed -i "/--browser)/,/;;/{s|^\t\t[a-z].*$|\t\t$BROWSER_BIN|}" "$OPENAPPS"
info "sxhkdrc (super+w) and OpenApps --browser patched to use $BROWSER_BIN."

# ── Default cursor theme (required by 05-gtk.sh on first boot) ───────────────
info "Creating ~/.icons/default/index.theme..."
mkdir -p "$HOME/.icons/default"
if [ ! -f "$HOME/.icons/default/index.theme" ]; then
    printf '[Icon Theme]\nName=Default\nComment=Default Cursor Theme\nInherits=Qogirr-Dark\n' \
        > "$HOME/.icons/default/index.theme"
fi

# ── Config backup dir (required by bspwmrc on every startup) ─────────────────
info "Setting up ~/.local/share/gh0stzk/config/bspwm/config backup dir..."
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_CFG="$HOME/.local/share/gh0stzk/config/bspwm/config"
mkdir -p "$BACKUP_CFG"
for f in dunstrc picom.conf picom-animations.conf xsettingsd jgmenurc; do
    src="$DOTFILES_DIR/.config/bspwm/config/$f"
    [ -f "$src" ] && cp "$src" "$BACKUP_CFG/$f"
done
info "Backup config files copied."

# ── Bluetooth service ─────────────────────────────────────────────────────────
warn "Bluetooth: enable the service on your host system with:"
warn "  sudo systemctl enable --now bluetooth.service"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "All prerequisites installed."
warn "Note: This config was built for a 42 school junest environment."
warn "      ft_lock (/host/usr/share/42/ft_lock) is 42-specific and won't exist elsewhere."
warn "      The lock button in the eww profilecard will need to be changed for non-42 use."