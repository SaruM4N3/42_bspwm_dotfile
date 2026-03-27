#!/bin/bash
# ============================================================
# install_junest.sh
# Install junest (Arch Linux in a container), bootstrap pacman,
# then run install_prerequisites_pacman.sh inside it.
#
# Usage: bash Utils/install_junest.sh
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

JUNEST_BIN="$HOME/.local/share/junest/bin/junest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Install junest if not already present ─────────────────────────────────
if [ ! -x "$JUNEST_BIN" ]; then
    info "Installing junest..."
    git clone https://github.com/fsquillace/junest.git "$HOME/.local/share/junest"
    export PATH="$HOME/.local/share/junest/bin:$PATH"
else
    info "junest already installed at $JUNEST_BIN"
    export PATH="$HOME/.local/share/junest/bin:$PATH"
fi

# ── 2. Bootstrap junest environment (downloads Arch base image) ───────────────
if [ ! -f "$HOME/.junest/usr/bin/pacman" ]; then
    info "Setting up junest Arch environment..."
    junest setup
else
    info "junest environment already set up."
fi

# ── 3. Install archlinux-keyring + full system update inside junest ───────────
info "Installing archlinux-keyring and running full system update inside junest..."
junest -- bash -c "
    pacman -Sy --noconfirm archlinux-keyring &&
    pacman-key --populate archlinux &&
    pacman -Syu --noconfirm
"

# ── 4. Run the prerequisites install script inside junest ─────────────────────
info "Running install_prerequisites_pacman.sh inside junest..."
junest -- bash "$SCRIPT_DIR/install_prerequisites_pacman.sh"

info "All done. You can now launch bspwm via Utils/bspwm.sh."