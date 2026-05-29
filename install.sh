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

RED='\033[0;31m'; YEL='\033[1;33m'; GRN='\033[0;32m'; BLU='\033[0;34m'
BLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${BLD}${GRN}[+]${NC} $*"; }
warn()  { echo -e "${BLD}${YEL}[!]${NC} $*"; }
error() { echo -e "${BLD}${RED}[✗]${NC} $*"; exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP=$(date +"%Y%m%d-%H%M%S")

[ "$(id -u)" = 0 ] && error "Do not run as root."

# ── Welcome ───────────────────────────────────────────────────
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
echo -e "    ${GRN}[2]${NC} Backup existing configs to ~/.config-backup-$STAMP"
echo -e "    ${GRN}[3]${NC} Deploy all dotfiles to their locations"
echo -e "    ${GRN}[4]${NC} Install fonts, desktop entries, and bin scripts"
echo -e "    ${GRN}[5]${NC} Register GNOME Super+B shortcut"
echo -e "    ${GRN}[6]${NC} Install oh-my-zsh + custom plugins"
echo -e "    ${GRN}[7]${NC} Patch ~/.zshrc with junest/bspwm swap"
echo ""
warn "Existing configs will be backed up before anything is overwritten."
echo ""
printf "%b" "${BLD}${BLU}[?]${NC} Continue? [y/N]: "
read -r yn
case "$yn" in [Yy]) ;; *) echo "Cancelled."; exit 0 ;; esac

# ── Step 1: junest setup ──────────────────────────────────────
clear
info "Step 1/7 — Installing junest and packages..."
bash "$REPO/.bspwminstaller/install_junest.sh"

# ── Step 2: Backup ────────────────────────────────────────────
clear
info "Step 2/7 — Backing up existing configs..."
BACKUP="$HOME/.config-backup-$STAMP"
mkdir -p "$BACKUP"
backed=0
for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch logtime Thunar; do
    [ -d "$HOME/.config/$cfg" ] && mv "$HOME/.config/$cfg" "$BACKUP/" && backed=1
done
[ -f "$HOME/.gtkrc-2.0" ] && mv "$HOME/.gtkrc-2.0" "$BACKUP/" && backed=1
[ "$backed" -eq 1 ] && info "Backups saved to: $BACKUP" || info "Nothing to back up."

# ── Step 3: Deploy dotfiles ───────────────────────────────────
clear
info "Step 3/7 — Deploying dotfiles..."

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"

# Installer scripts
mkdir -p "$HOME/.bspwminstaller"
cp -r "$REPO/.bspwminstaller/." "$HOME/.bspwminstaller/"
chmod +x "$HOME/.bspwminstaller/"*.sh
info "Deployed: ~/.bspwminstaller"

# Config directories
for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch logtime Thunar; do
    [ -d "$REPO/.config/$cfg" ] || { warn "$cfg not in repo — skipping"; continue; }
    cp -r "$REPO/.config/$cfg" "$HOME/.config/$cfg"
    info "Deployed: ~/.config/$cfg"
done

# Home dotfiles (.zshrc.bak is the bspwm zshrc — swapped in at login, user's .zshrc untouched)
for f in .zshrc.bak .gtkrc-2.0; do
    [ -f "$REPO/$f" ] && cp "$REPO/$f" "$HOME/$f" && info "Deployed: ~/$f"
done

# Rewrite any hardcoded paths to match the installing user
grep -rl "/home/zsonie" "$HOME/.config/bspwm" "$HOME/.bspwminstaller" 2>/dev/null \
    | xargs -r sed -i "s|/home/zsonie|$HOME|g"
info "Hardcoded paths rewritten to: $HOME"

# GL shim: symlinks to host Ubuntu mesa so all bspwm apps get hardware OpenGL.
# Arch mesa (any version) can't negotiate GLX visuals with Ubuntu's Xorg server.
# Ubuntu mesa 23.2.1 supports DRM 3.42 (kernel 5.15) natively.
GL_SHIM="$HOME/.config/bspwm/gl-host"
mkdir -p "$GL_SHIM"
HLIB="/usr/lib/x86_64-linux-gnu"
for lib in \
    libGL.so libGL.so.1 libGL.so.1.7.0 \
    libGLX.so.0 libGLX.so libGLX_mesa.so.0 \
    libGLdispatch.so.0 libGLdispatch.so \
    libEGL.so.1 libEGL.so libEGL_mesa.so.0 \
    libGLESv2.so.2 libGLESv1_CM.so.1
do
    [ -e "$HLIB/$lib" ] && ln -sf "$HLIB/$lib" "$GL_SHIM/$lib"
done
info "GL host shim created at $GL_SHIM"

# Animated wallpapers (4K archives, if present)
mkdir -p "$HOME/Pictures"
for tar in "$REPO/Pictures"/AnimatedWallpaper-*.tar; do
    [ -f "$tar" ] || continue
    tar -xf "$tar" -C "$HOME/Pictures/"
    info "Extracted: $(basename "$tar")"
done

# ── Step 4: Fonts + desktop entries + bin ────────────────────
clear
info "Step 4/7 — Installing fonts, desktop entries, and bin scripts..."

[ -d "$REPO/.local/share/fonts" ] && {
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$REPO/.local/share/fonts/." "$HOME/.local/share/fonts/"
    fc-cache -fv >/dev/null 2>&1
    info "Fonts installed."
}

[ -d "$REPO/.local/share/applications" ] && {
    mkdir -p "$HOME/.local/share/applications"
    cp -r "$REPO/.local/share/applications/." "$HOME/.local/share/applications/"
    info "Desktop entries installed."
}

[ -d "$REPO/.local/share/asciiart" ] && {
    cp -r "$REPO/.local/share/asciiart" "$HOME/.local/share/"
    info "Asciiart installed."
}

[ -d "$REPO/.local/bin" ] && {
    mkdir -p "$HOME/.local/bin"
    cp -r "$REPO/.local/bin/." "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
    info "Local bin scripts installed."
}

command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update

# ── Step 5: GNOME Super+B shortcut ───────────────────────────
clear
info "Step 5/7 — Registering GNOME keyboard shortcut (Super+B → bspwm)..."
if command -v dconf >/dev/null 2>&1; then
    bash "$HOME/.bspwminstaller/add-gnome-shortcut.sh"
else
    warn "dconf not found — skipping GNOME shortcut."
fi

# ── Step 6: oh-my-zsh ────────────────────────────────────────
clear
info "Step 6/7 — Installing oh-my-zsh..."

if [ -d "$HOME/.oh-my-zsh" ]; then
    info "oh-my-zsh already installed — skipping."
else
    if command -v curl >/dev/null 2>&1; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://install.ohmyz.sh)" || warn "oh-my-zsh install failed — continuing."
    elif command -v wget >/dev/null 2>&1; then
        RUNZSH=no CHSH=no sh -c "$(wget -qO- https://install.ohmyz.sh)" || warn "oh-my-zsh install failed — continuing."
    else
        warn "Neither curl nor wget found — skipping oh-my-zsh."
    fi
fi

[ -d "$REPO/.oh-my-zsh/custom" ] && [ -d "$HOME/.oh-my-zsh" ] && {
    cp -r "$REPO/.oh-my-zsh/custom/." "$HOME/.oh-my-zsh/custom/"
    info "oh-my-zsh custom directory deployed."
}

# ── Step 7: zshrc swap setup ─────────────────────────────────
clear
info "Step 7/7 — Patching ~/.zshrc with junest/bspwm swap..."

if [ -f "$HOME/.zshrc" ] && ! grep -q 'JUNEST_ENV' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" << 'EOF'

# Swap to bspwm zshrc when running inside junest, then reload.
_swap_zshrc() {
    [ -f "$HOME/.zshrc" ] && [ -f "$HOME/.zshrc.bak" ] || return
    mv "$HOME/.zshrc" "$HOME/.zshrc.tmp"
    mv "$HOME/.zshrc.bak" "$HOME/.zshrc"
    mv "$HOME/.zshrc.tmp" "$HOME/.zshrc.bak"
}
if [[ -n "$JUNEST_ENV" ]]; then
    _swap_zshrc
    exec zsh
fi
unset -f _swap_zshrc

# Junest bin — only reached in GNOME (not inside bspwm)
export PATH="$HOME/.local/share/junest/bin:$PATH"
export PATH="$PATH:$HOME/.junest/usr/bin_wrappers"
EOF
    info "Junest swap added to ~/.zshrc"
else
    info "~/.zshrc already patched or not found — skipping."
fi

# ── Done ──────────────────────────────────────────────────────
clear
echo ""
echo -e "${BLD}${GRN}  ✓ Installation complete!${NC}"
echo ""
echo -e "  ${YEL}Next step:${NC} launch bspwm via"
echo -e "     ${BLU}~/.bspwminstaller/bspwm.sh${NC}"
echo ""
warn "Note: ft_lock (/host/usr/share/42/ft_lock) is 42-school specific."
warn "      Update the lock button in eww/profilecard if running elsewhere."
echo ""
