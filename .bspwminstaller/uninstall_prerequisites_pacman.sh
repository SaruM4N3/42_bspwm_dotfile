#!/bin/bash
# ============================================================
# uninstall_prerequisites_pacman.sh
# Remove everything installed by install_prerequisites_pacman.sh
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

confirm() {
    [ "${UNINSTALL_SKIP_CONFIRM:-0}" = "1" ] && return
    printf "\n%b\n" "${YELLOW}[!]${NC} This will remove all packages and files installed by install_prerequisites_pacman.sh."
    printf "    It will NOT remove your dotfiles directory.\n"
    printf "Continue? [y/N]: "
    read -r ans
    case "$ans" in
        y|Y) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
}

remove_packages() {
    local pkgs="$*"
    local present=()
    for p in $pkgs; do
        pacman -Q "$p" >/dev/null 2>&1 && present+=("$p")
    done
    if [ ${#present[@]} -gt 0 ]; then
        sudo pacman -Rns --noconfirm "${present[@]}" 2>/dev/null || \
            warn "Some packages could not be removed (may be required by others): ${present[*]}"
    fi
}

# ── Confirmation ──────────────────────────────────────────────────────────────
confirm

# ── Browser (detect which one was installed) ──────────────────────────────────
info "Removing browser..."
for pkg in brave-bin firefox chromium google-chrome; do
    pacman -Q "$pkg" >/dev/null 2>&1 && sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null && break
done

# ── AUR packages ──────────────────────────────────────────────────────────────
info "Removing AUR packages..."
remove_packages xwinwrap-0.9-bin fzf-tab-git ttf-material-design-icons-desktop-git

# ── eww-git ───────────────────────────────────────────────────────────────────
info "Removing eww-git..."
remove_packages eww-git

# ── picom ─────────────────────────────────────────────────────────────────────
info "Removing picom..."
remove_packages picom

# ── Clipboard ─────────────────────────────────────────────────────────────────
info "Removing clipcat..."
remove_packages clipcat

# ── Fonts (pacman) ────────────────────────────────────────────────────────────
info "Removing fonts..."
remove_packages \
    ttf-inconsolata \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    ttf-terminus-nerd \
    ttf-ubuntu-mono-nerd \
    ttf-font-awesome

# ── Shell ─────────────────────────────────────────────────────────────────────
info "Removing zsh plugins..."
remove_packages \
    zsh-autosuggestions \
    zsh-history-substring-search \
    zsh-syntax-highlighting
warn "Keeping zsh itself (may be your login shell)."

# ── gh0stzk GTK themes, cursors and icon packs ───────────────────────────────
info "Removing gh0stzk themes, cursors and icons..."
remove_packages \
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

# ── Icons & themes ────────────────────────────────────────────────────────────
info "Removing papirus-icon-theme..."
remove_packages papirus-icon-theme

# ── CLI tools ─────────────────────────────────────────────────────────────────
info "Removing CLI tools..."
remove_packages bat eza btop micro

# ── System utilities ──────────────────────────────────────────────────────────
info "Removing system utilities..."
remove_packages \
    brightnessctl \
    lxsession \
    xclip \
    xdg-user-dirs \
    jq \
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
warn "Keeping curl and bc (common system tools)."

# ── Bluetooth ─────────────────────────────────────────────────────────────────
info "Removing bluetooth packages..."
remove_packages bluez bluez-utils

# ── Media & audio ─────────────────────────────────────────────────────────────
info "Removing media packages..."
remove_packages mpd mpc ncmpcpp mpv playerctl pamixer ffmpeg

# ── Editors ───────────────────────────────────────────────────────────────────
info "Removing editors..."
remove_packages geany neovim

# ── File manager ──────────────────────────────────────────────────────────────
info "Removing file manager..."
remove_packages thunar tumbler gvfs-mtp yazi

# ── Terminals and launcher ────────────────────────────────────────────────────
info "Removing terminals and launcher..."
remove_packages alacritty kitty jgmenu

# ── Core WM ───────────────────────────────────────────────────────────────────
info "Removing core WM packages..."
remove_packages \
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

# ── Remove gh0stzk-dotfiles repo from pacman.conf ────────────────────────────
if grep -q '\[gh0stzk-dotfiles\]' /etc/pacman.conf 2>/dev/null; then
    info "Removing gh0stzk-dotfiles repo from pacman.conf..."
    sudo sed -i '/\[gh0stzk-dotfiles\]/,/^$/d' /etc/pacman.conf
    sudo pacman -Sy --noconfirm 2>/dev/null || true
fi

# ── Remove chaotic-aur repo from pacman.conf ─────────────────────────────────
if [ "${UNINSTALL_SKIP_CONFIRM:-0}" = "1" ]; then rm_chaotic="y"; else
    printf "\nRemove chaotic-aur from pacman.conf? [y/N]: "
    read -r rm_chaotic
fi
if [ "$rm_chaotic" = "y" ] || [ "$rm_chaotic" = "Y" ]; then
    info "Removing chaotic-aur from pacman.conf..."
    sudo sed -i '/\[chaotic-aur\]/,/^$/d' /etc/pacman.conf
    remove_packages chaotic-keyring chaotic-mirrorlist
    sudo pacman -Sy --noconfirm 2>/dev/null || true
fi

# ── Bundled fonts ─────────────────────────────────────────────────────────────
info "Removing bundled fonts from ~/.local/share/fonts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTS_SRC="$SCRIPT_DIR/../.local/share/fonts"
if [ -d "$FONTS_SRC" ]; then
    while IFS= read -r -d '' entry; do
        name=$(basename "$entry")
        target="$HOME/.local/share/fonts/$name"
        [ -e "$target" ] && rm -rf "$target" && info "  removed font: $name"
    done < <(find "$FONTS_SRC" -maxdepth 1 -mindepth 1 -print0)
    fc-cache -fv 2>/dev/null || true
fi

# ── Config backup dir ─────────────────────────────────────────────────────────
info "Removing ~/.local/share/gh0stzk/..."
rm -rf "$HOME/.local/share/gh0stzk"

# ── Default cursor theme ──────────────────────────────────────────────────────
info "Removing ~/.icons/default/index.theme..."
rm -f "$HOME/.icons/default/index.theme"
rmdir "$HOME/.icons/default" 2>/dev/null || true
rmdir "$HOME/.icons" 2>/dev/null || true

# ── Deployed config directories ───────────────────────────────────────────────
info "Removing deployed ~/.config entries..."
for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch logtime; do
    [ -d "$HOME/.config/$cfg" ] && rm -rf "$HOME/.config/$cfg" && info "  removed: ~/.config/$cfg"
done

# ── Home dotfiles ──────────────────────────────────────────────────────────────
info "Removing deployed home dotfiles..."
for f in .zshrc .gtkrc-2.0; do
    [ -f "$HOME/$f" ] && rm -f "$HOME/$f" && info "  removed: ~/$f"
done
# Restore backup if it exists
[ -f "$HOME/.zshrc.bak" ] && mv "$HOME/.zshrc.bak" "$HOME/.zshrc" && info "  restored: ~/.zshrc from ~/.zshrc.bak"

# ── Installer scripts ──────────────────────────────────────────────────────────
info "Removing ~/.bspwminstaller/..."
rm -rf "$HOME/.bspwminstaller"

# ── Desktop entries ────────────────────────────────────────────────────────────
info "Removing deployed desktop entries..."
for f in riceditor.desktop zfetch.desktop zombie.svg; do
    [ -f "$HOME/.local/share/applications/$f" ] && rm -f "$HOME/.local/share/applications/$f" && info "  removed: $f"
done

# ── Asciiart ──────────────────────────────────────────────────────────────────
info "Removing ~/.local/share/asciiart/..."
rm -rf "$HOME/.local/share/asciiart"

# ── Local bin ─────────────────────────────────────────────────────────────────
info "Removing deployed local bin scripts..."
for f in colorscript sysfetch; do
    [ -f "$HOME/.local/bin/$f" ] && rm -f "$HOME/.local/bin/$f" && info "  removed: ~/.local/bin/$f"
done

# ── Animated wallpapers ────────────────────────────────────────────────────────
if [ "${UNINSTALL_SKIP_CONFIRM:-0}" = "1" ]; then rm_walls="y"; else
    printf "\nRemove ~/Pictures/AnimatedWallpaper? [y/N]: "
    read -r rm_walls
fi
if [ "$rm_walls" = "y" ] || [ "$rm_walls" = "Y" ]; then
    rm -rf "$HOME/Pictures/AnimatedWallpaper"
    info "Removed: ~/Pictures/AnimatedWallpaper"
fi

# ── ZSH config dir ────────────────────────────────────────────────────────────
info "Removing ~/.config/zsh/ (history, compdump)..."
rm -rf "$HOME/.config/zsh"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "Uninstall complete."
warn "Your dotfiles repository has NOT been removed."
warn "Run 'sudo pacman -Qdtq | sudo pacman -Rns -' to clean up any remaining orphans."
