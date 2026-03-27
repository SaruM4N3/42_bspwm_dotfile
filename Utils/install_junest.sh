#!/bin/bash
# ============================================================
# install_junest.sh
# Install junest and bootstrap the Arch environment.
# Does NOT install packages — run install_prerequisites_pacman.sh
# manually inside junest for that (see install.sh step 1).
#
# Usage: bash Utils/install_junest.sh
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

JUNEST_BIN="$HOME/.local/share/junest/bin/junest"

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

info "junest is ready. Enter it with: junest -b"