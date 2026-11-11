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
# This repo's uninstaller (latest fixes), the deployed copy as a fallback
UNINSTALLER="$SCRIPT_DIR/.bspwminstaller/uninstall_prerequisites_pacman.sh"
[ -f "$UNINSTALLER" ] || UNINSTALLER="$HOME/.bspwminstaller/uninstall_prerequisites_pacman.sh"
# junest only sees $HOME: bind the repo in when it lives elsewhere (/goinfre)
case "$UNINSTALLER" in "$HOME"/*) JUNEST_ARGS=() ;; *) JUNEST_ARGS=(-b "--bind $SCRIPT_DIR $SCRIPT_DIR") ;; esac

# Same checks as install.sh: from GNOME only, never while bspwm runs
if [ -n "$JUNEST_ENV" ]; then
    echo -e "${RED}[✗]${NC} Run this from a GNOME terminal, not from inside bspwm/junest."; exit 1
fi
if pgrep -x bspwm >/dev/null; then
    echo -e "${RED}[✗]${NC} bspwm is running: quit it first (back to GNOME), then run this again."; exit 1
fi
# bspwm killed before bspwm.sh swapped back: ~/.zshrc is the bspwm one and
# ~/.zshrc.bak the user's. Swap back first, or the user's zshrc gets deleted
# with ~/.zshrc.bak below (and oh-my-zsh looks unused).
if [ -f "$HOME/.zshrc.bak" ] && grep -q '^# Self-check: if loaded outside junest' "$HOME/.zshrc" 2>/dev/null; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.tmp" && mv "$HOME/.zshrc.bak" "$HOME/.zshrc" && mv "$HOME/.zshrc.tmp" "$HOME/.zshrc.bak"
    warn "~/.zshrc and ~/.zshrc.bak were left swapped by an unclean bspwm exit: swapped back."
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
printf "\n%b\n" "${RED}[!]${NC} This will remove EVERYTHING installed by this dotfiles setup:"
printf "    packages, config files, junest, GNOME shortcut, and leftover files.\n"
printf "    Your dotfiles repository will NOT be deleted.\n"
# UNINSTALL_SKIP_CONFIRM: already confirmed (graphical installer)
if [ -z "$UNINSTALL_SKIP_CONFIRM" ]; then
    printf "\nContinue? [y/N]: "
    read -r ans
    case "$ans" in
        y|Y) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

# ── Step 1: Remove packages + config files (inside junest) ───────────────────
if [ -x "$JUNEST_BIN" ] && [ -f "$UNINSTALLER" ]; then
    info "Running package and config uninstall inside junest..."
    UNINSTALL_SKIP_CONFIRM=1 "$JUNEST_BIN" "${JUNEST_ARGS[@]}" -- bash "$UNINSTALLER"
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

# ── Step 4: Remove GNOME keyboard shortcut ───────────────────────────────────
if command -v dconf >/dev/null 2>&1; then
    info "Removing GNOME bspwm keyboard shortcut..."
    BASE="/org/gnome/settings-daemon/plugins/media-keys"
    # add-gnome-shortcut.sh takes the first free customN: find ours by its command
    current=$(dconf read "$BASE/custom-keybindings" 2>/dev/null)
    NEW_DIR=""
    for dir in $(echo "$current" | grep -oE "$BASE/custom-keybindings/[^']+/"); do
        [ "$(dconf read "${dir}command")" = "'$HOME/.bspwminstaller/bspwm.sh'" ] && { NEW_DIR="$dir"; break; }
    done
    if [ -n "$NEW_DIR" ]; then
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
