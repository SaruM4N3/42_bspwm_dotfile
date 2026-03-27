#!/bin/bash
# ============================================================
# install_junest.sh
# Install junest (Arch Linux in a container), bootstrap pacman,
# then run install_prerequisites_pacman.sh inside it.
#
# Uses bubblewrap (-b) mode — required on 42 school machines
# where PRoot (default junest mode) is blocked by seccomp.
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
else
    info "junest already installed at $JUNEST_BIN"
fi

export PATH="$HOME/.local/share/junest/bin:$PATH"

# ── 2. Bootstrap junest environment (downloads Arch base image) ──────────────
if [ ! -f "$HOME/.junest/usr/bin/pacman" ]; then
    info "Setting up junest Arch environment..."
    "$JUNEST_BIN" setup
else
    info "junest environment already set up."
fi

# ── 3. System update + keyring inside junest (bubblewrap mode) ───────────────
info "Updating pacman keyring and system inside junest..."
"$JUNEST_BIN" -b -- bash -c "
    pacman -Sy --noconfirm archlinux-keyring &&
    pacman-key --populate archlinux &&
    pacman -Syu --noconfirm
"

# ── 4. Run prerequisites script inside junest (bubblewrap mode) ──────────────
info "Running install_prerequisites_pacman.sh inside junest..."
"$JUNEST_BIN" -b -- bash "$SCRIPT_DIR/install_prerequisites_pacman.sh"

info "All done. You can now launch bspwm via Utils/bspwm.sh."