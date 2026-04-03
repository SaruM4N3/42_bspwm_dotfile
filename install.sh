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

# ── Copy helpers (behaviour controlled by INSTALL_MODE) ───────────────────────
#   overwrite  — backup existing, overwrite everything, ask on diff
#   merge      — only copy files/dirs that don't exist yet at destination
#   skip       — never reached (installer exits before deploy steps)

# Diff-aware copy used in overwrite mode.
# For files: shows a diff if the destination exists and differs, then asks.
# For dirs:  lists changed/added/removed files, then asks.
# If destination doesn't exist, copies silently.
cp_smart() {
    local src="$1" dst="$2" is_dir="$3"

    if [ ! -e "$dst" ]; then
        [ "$is_dir" = "dir" ] && cp -r "$src" "$dst" || cp "$src" "$dst"
        return 0
    fi

    if [ "$is_dir" = "dir" ]; then
        local changes
        changes=$(diff -rq "$src" "$dst" 2>/dev/null)
        if [ -z "$changes" ]; then
            info "Unchanged: $dst"
            return 0
        fi
        echo -e "\n${BLD}${YEL}  Changes detected in $dst:${NC}"
        echo "$changes" | head -30
    else
        if diff -q "$src" "$dst" >/dev/null 2>&1; then
            info "Unchanged: $dst"
            return 0
        fi
        echo -e "\n${BLD}${YEL}  Diff for $dst:${NC}"
        diff --color=always "$dst" "$src" 2>/dev/null | head -50 || true
    fi

    echo ""
    printf "%b" "${BLD}${BLU}[?]${NC} Overwrite '$(basename "$dst")'? [y/N]: "
    read -r ow
    case "$ow" in
        y|Y)
            [ "$is_dir" = "dir" ] && cp -r "$src" "$dst" || cp "$src" "$dst"
            ;;
        *) warn "Skipped: $dst" ;;
    esac
}

# Merge-mode copy: only act if destination is absent.
# For dirs: recurse into src and copy each file individually if missing.
cp_missing() {
    local src="$1" dst="$2" is_dir="$3"
    if [ "$is_dir" = "dir" ]; then
        find "$src" -type f | while IFS= read -r srcfile; do
            local rel="${srcfile#$src/}"
            local dstfile="$dst/$rel"
            if [ ! -e "$dstfile" ]; then
                mkdir -p "$(dirname "$dstfile")"
                cp "$srcfile" "$dstfile"
                info "Added: $dstfile"
            fi
        done
    else
        if [ ! -e "$dst" ]; then
            cp "$src" "$dst"
            info "Added: $dst"
        fi
    fi
}

# Unified dispatcher — routes to the right helper based on INSTALL_MODE
cp_deploy() {
    case "${INSTALL_MODE:-overwrite}" in
        merge)     cp_missing "$@" ;;
        overwrite) cp_smart   "$@" ;;
    esac
}

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
echo -e "    ${GRN}[5]${NC} Register GNOME Super+B shortcut"
echo -e "    ${GRN}[6]${NC} Set up zshrc swap for bspwm/GNOME"
echo ""
warn "Your existing configs will be backed up, not deleted."
echo ""
ask "Continue? [y/N]: "
read -r yn
case "$yn" in [Yy]) ;; *) echo "Cancelled."; exit 0 ;; esac

# ── Existing install detection ────────────────────────────────────────────────
INSTALL_MODE="overwrite"
if [ -d "$HOME/.config/bspwm" ] || [ -d "$HOME/.bspwminstaller" ]; then
    echo ""
    warn "Existing bspwm install detected!"
    echo ""
    echo -e "  ${BLD}How do you want to proceed?${NC}"
    echo -e "  ${GRN}[1]${NC} Overwrite  — backup existing configs, redeploy everything (asks on each diff)"
    echo -e "  ${YEL}[2]${NC} Merge      — only add files that are missing, never touch existing ones"
    echo -e "  ${RED}[3]${NC} Skip       — abort, don't change anything"
    echo ""
    printf "%b" "${BLD}${BLU}[?]${NC} Choice [1/2/3]: "
    read -r choice
    case "$choice" in
        1) INSTALL_MODE="overwrite"; info "Mode: overwrite" ;;
        2) INSTALL_MODE="merge";     info "Mode: merge (add missing only)" ;;
        3) echo "Aborted."; exit 0 ;;
        *) warn "Invalid choice — defaulting to merge (safe)."; INSTALL_MODE="merge" ;;
    esac
    echo ""
fi

# ── Step 1: junest setup + package install ───────────────────────────────────
clear
info "Step 1/6 — Installing junest and packages..."
echo ""
bash "$REPO_DIR/.bspwminstaller/install_junest.sh"

# ── Step 2: Backup existing configs ──────────────────────────────────────────
clear
if [ "$INSTALL_MODE" = "overwrite" ]; then
    info "Step 2/6 — Backing up existing configs..."
    BACKUP_DIR="$HOME/.config-backup-$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"

    for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch logtime; do
        if [ -d "$HOME/.config/$cfg" ]; then
            mv "$HOME/.config/$cfg" "$BACKUP_DIR/"
            info "Backed up: ~/.config/$cfg"
        fi
    done

    for f in .gtkrc-2.0; do
        if [ -f "$HOME/$f" ]; then
            cp "$HOME/$f" "$HOME/${f}.bak"
            mv "$HOME/$f" "$BACKUP_DIR/"
            info "Backed up: ~/$f → ~/${f}.bak + $BACKUP_DIR/"
        fi
    done

    [ -d "$BACKUP_DIR" ] && info "Backups saved to: $BACKUP_DIR"
else
    info "Step 2/6 — Skipping backup (merge mode — existing files untouched)."
fi

# ── Step 3: Deploy dotfiles ───────────────────────────────────────────────────
clear
info "Step 3/6 — Deploying dotfiles..."
echo ""

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"

# Deploy installer scripts FIRST (before any filtering)
info "Deploying .bspwminstaller scripts..."
if [ -d "$REPO_DIR/.bspwminstaller" ]; then
    cp_deploy "$REPO_DIR/.bspwminstaller" "$HOME/.bspwminstaller" dir
    info "Deployed: ~/.bspwminstaller"
else
    error ".bspwminstaller directory not found in repo!"
fi

info "Deploying .config directories..."
    if [ -d "$REPO_DIR/.config/$cfg" ]; then
        cp_deploy "$REPO_DIR/.config/$cfg" "$HOME/.config/$cfg" dir
        info "Deployed: ~/.config/$cfg"
    fi
done

info "Config directories deployed, starting rice filtering..."

# ── Filter rices if selected_rices.txt exists (only deploy selected rices) ────
if [ -f "$HOME/.bspwminstaller/selected_rices.txt" ]; then
    info "Filtering rices based on selection..."
    SELECTED_RICES_ARRAY=()
    while IFS= read -r rice; do
        [ -n "$rice" ] && SELECTED_RICES_ARRAY+=("$rice")
    done < "$HOME/.bspwminstaller/selected_rices.txt"
    info "Selected rices to keep: ${SELECTED_RICES_ARRAY[*]}"
    
    # Remove unselected rices from ~/.config/bspwm/rices
    if [ -d "$HOME/.config/bspwm/rices" ]; then
        for rice_dir in "$HOME/.config/bspwm/rices"/*; do
            [ ! -d "$rice_dir" ] && continue
            rice_name=$(basename "$rice_dir")
            # Check if this rice is in the selected list
            found=0
            for selected_rice in "${SELECTED_RICES_ARRAY[@]}"; do
                if [ "$rice_name" = "$selected_rice" ]; then
                    found=1
                    break
                fi
            done
            if [ $found -eq 0 ]; then
                rm -rf "$rice_dir"
                warn "Removed unselected rice: $rice_name"
            fi
        done
    else
        warn "Rice directory not found at $HOME/.config/bspwm/rices — skipping filtering"
    fi
else
    warn "selected_rices.txt not found — keeping all rices"
fi

info "Rice filtering complete, deploying remaining files..."

# Home files (.zshrc.bak = bspwm zshrc, swapped in by bspwm.sh; user's .zshrc untouched)
for f in .zshrc.bak .gtkrc-2.0; do
    if [ -f "$REPO_DIR/$f" ]; then
        cp_deploy "$REPO_DIR/$f" "$HOME/$f" file
        info "Deployed: ~/$f"
    fi
done

# Fix hardcoded paths (replace repo author's username with the installing user)
info "Rewriting hardcoded user paths to: $HOME"
grep -rl "/home/zsonie" "$HOME/.config/bspwm" "$HOME/.bspwminstaller" 2>/dev/null | while read -r f; do
    sed -i "s|/home/zsonie|$HOME|g" "$f"
done

# Animated wallpapers (4K archive)
mkdir -p "$HOME/Pictures"
for tar in "$REPO_DIR/Pictures"/AnimatedWallpaper-*.tar; do
    [ -f "$tar" ] || continue
    tar -xf "$tar" -C "$HOME/Pictures/"
    info "Extracted: $(basename $tar)"
done

# ── Step 4: Fonts + desktop entries + bin ────────────────────────────────────
clear
info "Step 4/6 — Installing fonts, desktop entries, and bin scripts..."
echo ""

# Fonts (always overwrite — bundled fonts are versioned in the repo)
if [ -d "$REPO_DIR/.local/share/fonts" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$REPO_DIR/.local/share/fonts/." "$HOME/.local/share/fonts/"
    fc-cache -fv >/dev/null 2>&1
    info "Fonts installed and cache updated."
fi

# Desktop entries
if [ -d "$REPO_DIR/.local/share/applications" ]; then
    mkdir -p "$HOME/.local/share/applications"
    for f in "$REPO_DIR/.local/share/applications/"*; do
        cp_deploy "$f" "$HOME/.local/share/applications/$(basename "$f")" file
    done
    info "Desktop entries installed."
fi

# Asciiart
if [ -d "$REPO_DIR/.local/share/asciiart" ]; then
    cp_deploy "$REPO_DIR/.local/share/asciiart" "$HOME/.local/share/asciiart" dir
    info "Asciiart installed."
fi

# Local bin (colorscript, sysfetch)
if [ -d "$REPO_DIR/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    for f in "$REPO_DIR/.local/bin/"*; do
        cp_deploy "$f" "$HOME/.local/bin/$(basename "$f")" file
    done
    chmod +x "$HOME/.local/bin/"*
    info "Local bin scripts installed."
fi

# Generate XDG user dirs
command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update

# ── Step 5: GNOME Super+B shortcut ───────────────────────────────────────────
clear
info "Step 5/6 — Registering GNOME keyboard shortcut (Super+B → bspwm)..."
echo ""
if command -v dconf >/dev/null 2>&1; then
    bash "$HOME/.bspwminstaller/add-gnome-shortcut.sh"
else
    warn "dconf not found — skipping GNOME shortcut registration."
fi

# ── Step 6: zshrc setup ───────────────────────────────────────────────────────
clear
info "Step 6/6 — Setting up zshrc swap..."
echo ""

# Patch ~/.zshrc (GNOME/user config) with JUNEST_ENV self-check + junest PATH.
# IMPORTANT: PATH exports must come AFTER the JUNEST_ENV check.
# If PATH came first, the exports would run even when inside bspwm/junest
# (before exec zsh fires), re-adding wrapper paths that bspwm.sh already stripped.
if [ -f "$HOME/.zshrc" ] && ! grep -q 'JUNEST_ENV' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" << 'EOF'

# If loaded inside junest (bspwm session), swap to bspwm zshrc and reload.
# Must come before PATH exports so exec zsh fires before they are evaluated.
_swap_zshrc() {
    if [ -f "$HOME/.zshrc" ] && [ -f "$HOME/.zshrc.bak" ]; then
        mv "$HOME/.zshrc" "$HOME/.zshrc.tmp"
        mv "$HOME/.zshrc.bak" "$HOME/.zshrc"
        mv "$HOME/.zshrc.tmp" "$HOME/.zshrc.bak"
    fi
}
if [[ -n "$JUNEST_ENV" ]]; then
    _swap_zshrc
    exec zsh
fi
unset -f _swap_zshrc

# Junest bin + wrapper scripts — only reached in GNOME (not inside bspwm)
export PATH="$HOME/.local/share/junest/bin:$PATH"
export PATH="$PATH:$HOME/.junest/usr/bin_wrappers"
EOF
    info "JUNEST_ENV self-check and junest PATH added to ~/.zshrc"
else
    info "~/.zshrc already patched or not found — skipping."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
clear
echo ""
echo -e "${BLD}${GRN}  ✓ Installation complete!${NC}"
echo ""
echo -e "  ${YEL}Next steps:${NC}"
echo -e "  1. Launch bspwm via:"
echo -e "     ${BLU}~/.bspwminstaller/bspwm.sh${NC}"
echo ""
warn "Note: ft_lock (/host/usr/share/42/ft_lock) is 42-school specific."
warn "      Change the lock button in eww/profilecard if running elsewhere."
echo ""
