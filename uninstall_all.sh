#!/bin/bash
# =============================================================
#  ███████╗███████╗ ██████╗ ███╗   ██╗██╗███████╗
#  ╚══███╔╝██╔════╝██╔═══██╗████╗  ██║██║██╔════╝
#    ███╔╝ ███████╗██║   ██║██╔██╗ ██║██║█████╗
#   ███╔╝  ╚════██║██║   ██║██║╚██╗██║██║██╔══╝
#  ███████╗███████║╚██████╔╝██║ ╚████║██║███████╗
#  ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝╚══════╝
#
#  uninstall_all.sh — full uninstall (packages + configs + junest)
#  Repo: https://github.com/SaruM4N3/42_bspwm_dotfile
# =============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JUNEST_BIN="$HOME/.local/share/junest/bin/junest"
UNINSTALLER="$HOME/.bspwminstaller/uninstall_prerequisites_pacman.sh"

# ── Confirmation ──────────────────────────────────────────────────────────────
printf "\n%b\n" "${RED}[!]${NC} This will remove EVERYTHING installed by this dotfiles setup:"
printf "    packages, config files, junest, GNOME shortcut, and leftover files.\n"
printf "    Your dotfiles repository will NOT be deleted.\n"
printf "\nContinue? [y/N]: "
read -r ans
case "$ans" in
    y|Y) ;;
    *) echo "Aborted."; exit 0 ;;
esac

# ── Step 1: Remove packages + config files (inside junest) ───────────────────
if [ -x "$JUNEST_BIN" ] && [ -f "$UNINSTALLER" ]; then
    info "Running package and config uninstall inside junest..."
    UNINSTALL_SKIP_CONFIRM=1 "$JUNEST_BIN" -- bash "$UNINSTALLER"
elif [ -f "$UNINSTALLER" ]; then
    warn "junest not found — running uninstaller directly (pacman commands may fail)..."
    UNINSTALL_SKIP_CONFIRM=1 bash "$UNINSTALLER"
else
    warn "Uninstaller script not found at $UNINSTALLER — skipping package removal."
fi

# ── Step 2: Stop background daemons ──────────────────────────────────────────
info "Stopping bt-reconnect daemon..."
pkill -f bt-reconnect 2>/dev/null || true

# ── Step 3: Remove junest environment ────────────────────────────────────────
info "Removing junest Arch environment (~/.junest)..."
rm -rf "$HOME/.junest"

info "Removing junest binary (~/.local/share/junest)..."
rm -rf "$HOME/.local/share/junest"

# Remove junest wrapper bin if present
[ -d "$HOME/.junest/usr/bin_wrappers" ] && rm -rf "$HOME/.junest/usr/bin_wrappers"

# ── Step 4: Remove GNOME keyboard shortcut ───────────────────────────────────
if command -v dconf >/dev/null 2>&1; then
    info "Removing GNOME bspwm keyboard shortcut..."
    BASE="/org/gnome/settings-daemon/plugins/media-keys"
    NEW_KEY="custom5"
    NEW_DIR="$BASE/custom-keybindings/$NEW_KEY/"
    current=$(dconf read "$BASE/custom-keybindings" 2>/dev/null)
    if echo "$current" | grep -q "$NEW_KEY"; then
        new_list=$(echo "$current" | sed "s|, '$NEW_DIR'||;s|'$NEW_DIR', ||;s|'$NEW_DIR'||")
        [ "$new_list" = "[]" ] || [ -z "$new_list" ] && new_list="@as []"
        dconf write "$BASE/custom-keybindings" "$new_list"
        dconf reset "${NEW_DIR}name"
        dconf reset "${NEW_DIR}command"
        dconf reset "${NEW_DIR}binding"
        info "GNOME shortcut removed."
    else
        info "GNOME shortcut not found, skipping."
    fi
fi

# ── Step 5: Leftover files ────────────────────────────────────────────────────
info "Removing leftover files..."
rm -f "$HOME/bspwm_launch.log"
rm -f "$HOME/.config/bspwm/config/.first_run_done"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "Full uninstall complete."
warn "Your dotfiles repository at $SCRIPT_DIR has NOT been removed."
warn "You may delete it manually: rm -rf \"$SCRIPT_DIR\""
