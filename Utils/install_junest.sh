#!/bin/bash
# ============================================================
# install_junest.sh
# Install junest, bootstrap the Arch environment, then
# automatically run install_prerequisites_pacman.sh inside it.
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
    info "Cloning junest..."
    git clone https://github.com/fsquillace/junest.git "$HOME/.local/share/junest"
else
    info "junest already installed."
fi

export PATH="$HOME/.local/share/junest/bin:$PATH"

# ── 2. Bootstrap Arch base image ─────────────────────────────────────────────
if [ ! -f "$HOME/.junest/usr/bin/pacman" ]; then
    info "Downloading Arch base image (this may take a while)..."
    "$JUNEST_BIN" setup
else
    info "junest Arch environment already set up."
fi

# ── 3. Run prerequisites inside junest (proot mode — sudo works) ─────────────
info "Running package installation inside junest..."
"$JUNEST_BIN" -- bash "$SCRIPT_DIR/install_prerequisites_pacman.sh"

info "All packages installed."