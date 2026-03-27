#!/bin/bash
# =============================================================
#  ███████╗███████╗ ██████╗ ███╗   ██╗██╗███████╗
#  ╚══███╔╝██╔════╝██╔═══██╗████╗  ██║██║██╔════╝
#    ███╔╝ ███████╗██║   ██║██╔██╗ ██║██║█████╗
#   ███╔╝  ╚════██║██║   ██║██║╚██╗██║██║██╔══╝
#  ███████╗███████║╚██████╔╝██║ ╚████║██║███████╗
#  ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝╚══════╝
#
#  bspwm dotfiles installer — 42 school / junest edition
#  Repo: https://github.com/SaruM4N3/42_bspwm_dotfile
# =============================================================

set -e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'; BLU='\033[0;34m'
BLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLD}${GRN}[+]${NC} $*"; }
warn()    { echo -e "${BLD}${YEL}[!]${NC} $*"; }
error()   { echo -e "${BLD}${RED}[✗]${NC} $*"; exit 1; }
ask()     { echo -e "${BLD}${BLU}[?]${NC} $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# ── Checks ────────────────────────────────────────────────────────────────────
[ "$(id -u)" = 0 ] && error "Do not run as root."

# ── Welcome ───────────────────────────────────────────────────────────────────
clear
echo -e "${BLD}${GRN}"
cat << 'EOF'
  ██████╗ ███████╗██████╗ ██╗    ██╗███╗   ███╗
  ██╔══██╗██╔════╝██╔══██╗██║    ██║████╗ ████║
  ██████╔╝███████╗██████╔╝██║ █╗ ██║██╔████╔██║
  ██╔══██╗╚════██║██╔═══╝ ██║███╗██║██║╚██╔╝██║
  ██████╔╝███████║██║     ╚███╔███╔╝██║ ╚═╝ ██║
  ╚═════╝ ╚══════╝╚═╝      ╚══╝╚══╝ ╚═╝     ╚═╝
EOF
echo -e "${NC}"
echo -e "${BLD}  bspwm dotfiles — 42 school / junest edition${NC}"
echo ""
echo -e "  This script will:"
echo -e "    ${GRN}[1]${NC} Install junest + Arch dependencies inside it"
echo -e "    ${GRN}[2]${NC} Backup your existing configs"
echo -e "    ${GRN}[3]${NC} Deploy all dotfiles to their locations"
echo -e "    ${GRN}[4]${NC} Install fonts and desktop entries"
echo -e "    ${GRN}[5]${NC} Configure OpenWeatherMap API key and city"
echo -e "    ${GRN}[6]${NC} Configure 42 API credentials"
echo -e "    ${GRN}[7]${NC} Register GNOME Super+B shortcut"
echo -e "    ${GRN}[8]${NC} Set zsh as your default shell"
echo ""
warn "Your existing configs will be backed up, not deleted."
echo ""
ask "Continue? [y/N]: "
read -r yn
case "$yn" in [Yy]) ;; *) echo "Cancelled."; exit 0 ;; esac

# ── Step 1: junest setup + package install ───────────────────────────────────
clear
info "Step 1/8 — Installing junest and packages..."
echo ""
bash "$REPO_DIR/Utils/install_junest.sh"

# ── Step 2: Backup existing configs ──────────────────────────────────────────
clear
info "Step 2/8 — Backing up existing configs..."
BACKUP_DIR="$HOME/.config-backup-$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch logtime; do
    if [ -d "$HOME/.config/$cfg" ]; then
        mv "$HOME/.config/$cfg" "$BACKUP_DIR/"
        info "Backed up: ~/.config/$cfg"
    fi
done

for f in .zshrc .gtkrc-2.0; do
    if [ -f "$HOME/$f" ]; then
        cp "$HOME/$f" "$HOME/${f}.bak"
        mv "$HOME/$f" "$BACKUP_DIR/"
        info "Backed up: ~/$f → ~/${f}.bak + $BACKUP_DIR/"
    fi
done

[ -d "$BACKUP_DIR" ] && info "Backups saved to: $BACKUP_DIR"

# ── Step 3: Deploy dotfiles ───────────────────────────────────────────────────
clear
info "Step 3/8 — Deploying dotfiles..."
echo ""

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"

# ~/.config/* entries
for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch logtime; do
    if [ -d "$REPO_DIR/.config/$cfg" ]; then
        cp -r "$REPO_DIR/.config/$cfg" "$HOME/.config/"
        info "Deployed: ~/.config/$cfg"
    fi
done

# Home files
for f in .zshrc .gtkrc-2.0; do
    if [ -f "$REPO_DIR/$f" ]; then
        cp "$REPO_DIR/$f" "$HOME/"
        info "Deployed: ~/$f"
    fi
done

# Utils scripts
if [ -d "$REPO_DIR/Utils" ]; then
    cp -r "$REPO_DIR/Utils/." "$HOME/Utils/"
    info "Deployed: ~/Utils"
fi

# Fix hardcoded paths (replace repo author's username with the installing user)
info "Rewriting hardcoded user paths to: $HOME"
grep -rl "/home/zsonie" "$HOME/.config/bspwm" "$HOME/Utils" 2>/dev/null | while read -r f; do
    sed -i "s|/home/zsonie|$HOME|g" "$f"
done

# Animated wallpapers (split 1080p + 4K archives)
mkdir -p "$HOME/Pictures"
for tar in "$REPO_DIR/Pictures"/AnimatedWallpaper-*.tar; do
    [ -f "$tar" ] || continue
    tar -xf "$tar" -C "$HOME/Pictures/"
    info "Extracted: $(basename $tar)"
done

# ── Step 4: Fonts + desktop entries + bin ────────────────────────────────────
clear
info "Step 4/8 — Installing fonts, desktop entries, and bin scripts..."
echo ""

# Fonts
if [ -d "$REPO_DIR/.local/share/fonts" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$REPO_DIR/.local/share/fonts/." "$HOME/.local/share/fonts/"
    fc-cache -fv >/dev/null 2>&1
    info "Fonts installed and cache updated."
fi

# Desktop entries
if [ -d "$REPO_DIR/.local/share/applications" ]; then
    mkdir -p "$HOME/.local/share/applications"
    cp -r "$REPO_DIR/.local/share/applications/." "$HOME/.local/share/applications/"
    info "Desktop entries installed."
fi

# Asciiart
if [ -d "$REPO_DIR/.local/share/asciiart" ]; then
    mkdir -p "$HOME/.local/share/asciiart"
    cp -r "$REPO_DIR/.local/share/asciiart/." "$HOME/.local/share/asciiart/"
    info "Asciiart installed."
fi

# Local bin (colorscript, sysfetch)
if [ -d "$REPO_DIR/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -r "$REPO_DIR/.local/bin/." "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
    info "Local bin scripts installed."
fi

# Generate XDG user dirs
command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update

# ── Step 5: Weather API key ───────────────────────────────────────────────────
clear
info "Step 5/8 — OpenWeatherMap setup..."
echo ""
WEATHER_BIN="$HOME/.config/bspwm/bin/Weather"
if [ -f "$WEATHER_BIN" ]; then
    ask "Enter your OpenWeatherMap API key (leave blank to skip): "
    read -r OWM_KEY
    if [ -n "$OWM_KEY" ]; then
        sed -i "s|^KEY=.*|KEY=\"$OWM_KEY\"|" "$WEATHER_BIN"
        info "API key set."
    else
        warn "Skipped. Edit ~/.config/bspwm/bin/Weather manually to add your key."
    fi

    ask "Enter your city name for weather (leave blank to keep default): "
    read -r OWM_CITY
    if [ -n "$OWM_CITY" ]; then
        sed -i "s|^CITY=.*|CITY=\"$OWM_CITY\"|" "$WEATHER_BIN"
        info "City set to: $OWM_CITY"
    fi
else
    warn "Weather script not found, skipping."
fi

# ── Step 6: 42 API credentials ───────────────────────────────────────────────
clear
info "Step 6/8 — 42 API credentials setup..."
echo ""
LOGTIME_CREDS="$HOME/.config/logtime/credentials.json"
mkdir -p "$(dirname "$LOGTIME_CREDS")"
if [ ! -f "$LOGTIME_CREDS" ]; then
    ask "Enter your 42 API client ID (leave blank to skip): "
    read -r FT_ID
    ask "Enter your 42 API client secret (leave blank to skip): "
    read -r FT_SECRET
    if [ -n "$FT_ID" ] && [ -n "$FT_SECRET" ]; then
        printf '{"clientId": "%s", "clientSecret": "%s"}\n' "$FT_ID" "$FT_SECRET" > "$LOGTIME_CREDS"
        info "Credentials saved to $LOGTIME_CREDS"
    else
        warn "Skipped. Fill in ~/.config/logtime/credentials.json manually."
    fi
else
    info "Credentials file already exists, skipping."
fi

# ── Step 7: GNOME Super+B shortcut ───────────────────────────────────────────
clear
info "Step 7/8 — Registering GNOME keyboard shortcut (Super+B → bspwm)..."
echo ""
if command -v dconf >/dev/null 2>&1; then
    bash "$HOME/Utils/add-gnome-shortcut.sh"
else
    warn "dconf not found — skipping GNOME shortcut registration."
fi

# ── Step 8: Set zsh as default shell ─────────────────────────────────────────
clear
info "Step 8/8 — Setting default shell to zsh..."
echo ""

ZSH_PATH=$(command -v zsh 2>/dev/null)
if [ -z "$ZSH_PATH" ]; then
    warn "zsh not found, skipping shell change."
elif [ "$SHELL" = "$ZSH_PATH" ]; then
    info "zsh is already your default shell."
else
    if chsh -s "$ZSH_PATH"; then
        info "Shell changed to zsh."
    else
        warn "Could not change shell automatically. Run: chsh -s $ZSH_PATH"
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
clear
echo ""
echo -e "${BLD}${GRN}  ✓ Installation complete!${NC}"
echo ""
echo -e "  ${YEL}Next steps:${NC}"
echo -e "  1. Launch bspwm via:"
echo -e "     ${BLU}~/Utils/bspwm.sh${NC}"
echo ""
warn "Note: ft_lock (/host/usr/share/42/ft_lock) is 42-school specific."
warn "      Change the lock button in eww/profilecard if running elsewhere."
echo ""