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
# Inside junest (bspwm session) ~/.zshrc.bak holds the GNOME config and would be overwritten
[ -n "$JUNEST_ENV" ] && error "Run this from a GNOME terminal, not from inside bspwm/junest."
# While bspwm runs, ~/.zshrc and ~/.zshrc.bak are swapped and ~/.config/bspwm is in use
pgrep -x bspwm >/dev/null && error "bspwm is running: quit it first (back to GNOME), then run this again."

# ── Args ──────────────────────────────────────────────────────
FRESH=0
WIPE_JUNEST=0
UPDATE=0
PULLED=0
for arg in "$@"; do
    case "$arg" in
        --fresh|-f)  FRESH=1 ;;
        --update|-u) UPDATE=1 ;;
        --pulled)    PULLED=1 ;;     # internal: set when re-run after git pull
        -h|--help)
            echo "Usage: $0 [--update|-u | --fresh|-f]"
            echo "  --update, -u  Update an existing install: new dotfiles and scripts,"
            echo "                your settings kept, only missing packages installed"
            echo "                (no junest setup, no package questions)."
            echo "  --fresh, -f   Force a clean reinstall: wipe oh-my-zsh and"
            echo "                ~/.bspwminstaller before redeploying (and"
            echo "                optionally the junest Arch environment too),"
            echo "                instead of upgrading in place."
            exit 0
            ;;
        *) error "Unknown option: $arg (see --help)" ;;
    esac
done
[ "$FRESH" -eq 1 ] && [ "$UPDATE" -eq 1 ] && error "--update and --fresh cannot be used together."

JUNEST_BIN="$HOME/.local/share/junest/bin/junest"
INSTALLED=0
[ -d "$HOME/.config/bspwm" ] && [ -f "$HOME/.junest/usr/bin/pacman" ] && [ -x "$JUNEST_BIN" ] && INSTALLED=1
[ "$UPDATE" -eq 1 ] && [ "$INSTALLED" -eq 0 ] && error "No existing install found (junest + ~/.config/bspwm): run $0 without --update."

# Choices of the last full install (terminal, rice, browser, editor), reused by updates
SAVED_CHOICES="$HOME/.local/state/bspwm/install-choices"

# ── Welcome ───────────────────────────────────────────────────
if [ "$INSTALLED" -eq 1 ] && [ "$FRESH" -eq 0 ] && [ "$UPDATE" -eq 0 ]; then
    echo ""
    echo -e "${BLD}${BLU}[?]${NC} bspwm is already installed. What do you want to do?"
    echo -e "    ${GRN}1)${NC} Update: new version of the dotfiles, your settings kept ${BLD}[default]${NC}"
    echo -e "    ${GRN}2)${NC} Full install (packages, junest, all the questions)"
    printf "%b" "    Choice [1]: "
    read -r mode
    case "$mode" in 2) UPDATE=0 ;; *) UPDATE=1 ;; esac
fi

# Update: get the latest version of the repo first, then run the new install.sh
if [ "$UPDATE" -eq 1 ] && [ "$PULLED" -eq 0 ] && git -C "$REPO" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    echo ""
    printf "%b" "${BLD}${BLU}[?]${NC} Download the latest version from GitHub first (git pull)? [Y/n]: "
    read -r gp
    case "$gp" in
        [Nn]) ;;
        *)
            if git -C "$REPO" pull --ff-only; then
                exec bash "$REPO/install.sh" --update --pulled
            fi
            warn "git pull failed (local changes or no network?): updating from the local copy."
            ;;
    esac
fi

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
if [ "$FRESH" -eq 1 ]; then
    echo -e "${BLD}  bspwm dotfiles — 42 school / junest edition  ${RED}[FRESH REINSTALL]${NC}"
elif [ "$UPDATE" -eq 1 ]; then
    echo -e "${BLD}  bspwm dotfiles — 42 school / junest edition  ${BLU}[UPDATE]${NC}"
else
    echo -e "${BLD}  bspwm dotfiles — 42 school / junest edition${NC}"
fi
echo ""
if [ "$UPDATE" -eq 1 ]; then
echo -e "  This update will:"
echo -e "    ${GRN}[1]${NC} Install only the packages a newer version needs (no upgrade)"
echo -e "    ${GRN}[2]${NC} Backup existing configs to ~/.config-backup-$STAMP"
echo -e "    ${GRN}[3]${NC} Deploy the new dotfiles and scripts, ${BLD}keeping your settings${NC}"
echo -e "    ${GRN}[4-7]${NC} Refresh fonts, desktop entries, bin scripts, shortcut, zshrc block"
echo ""
warn "Your Rice Settings, keybinds, picom, wallpaper and choices stay as they are."
else
echo -e "  This script will:"
echo -e "    ${GRN}[1]${NC} Install junest + Arch dependencies inside it"
echo -e "    ${GRN}[2]${NC} Backup existing configs to ~/.config-backup-$STAMP"
echo -e "    ${GRN}[3]${NC} Deploy all dotfiles to their locations"
echo -e "    ${GRN}[4]${NC} Install fonts, desktop entries, and bin scripts"
echo -e "    ${GRN}[5]${NC} Register GNOME Super+Shift+B shortcut"
echo -e "    ${GRN}[6]${NC} Install oh-my-zsh + custom plugins"
echo -e "    ${GRN}[7]${NC} Patch ~/.zshrc with junest/bspwm swap"
echo ""
warn "Existing configs will be backed up before anything is overwritten."
fi

if [ "$FRESH" -eq 1 ]; then
    echo ""
    warn "Fresh reinstall: ~/.oh-my-zsh and ~/.bspwminstaller will be wiped"
    warn "and rebuilt from scratch instead of upgraded in place."
    echo ""
    printf "%b" "${BLD}${BLU}[?]${NC} Also wipe the junest Arch environment (~/.junest)? "
    printf "%b" "This removes ANY manually pacman-installed packages too. [y/N]: "
    read -r wj
    case "$wj" in [Yy]) WIPE_JUNEST=1 ;; *) WIPE_JUNEST=0 ;; esac
fi

# ── zsh config ────────────────────────────────────────────────
# mine: inside bspwm the shell uses this repo's zshrc (swapped in by bspwm.sh),
#       GNOME keeps the user's ~/.zshrc. keep: the user's ~/.zshrc everywhere.
if [ "$UPDATE" -eq 1 ]; then
    # Same mode as the install being updated: "keep" removed ~/.zshrc.bak
    if [ -f "$HOME/.zshrc.bak" ]; then ZSHRC_MODE=mine; else ZSHRC_MODE=keep; fi
else
echo ""
echo -e "${BLD}${BLU}[?]${NC} zsh config inside bspwm:"
echo -e "    ${GRN}1)${NC} Use mine in bspwm (prompt, fzf-tab, aliases), yours stays in GNOME ${BLD}[default]${NC}"
echo -e "    ${GRN}2)${NC} Keep your own ~/.zshrc everywhere"
printf "%b" "    Choice [1]: "
read -r zc
case "$zc" in 2) ZSHRC_MODE=keep ;; *) ZSHRC_MODE=mine ;; esac
fi

# ── Reinstall: keep the user's settings? ──────────────────────
KEEP_SETTINGS=0
if [ "$UPDATE" -eq 1 ]; then
    KEEP_SETTINGS=1
elif [ -d "$HOME/.config/bspwm" ]; then
    echo ""
    echo -e "${BLD}${BLU}[?]${NC} An existing bspwm config was found."
    echo -e "    Keep your settings (Rice Settings, keybinds, picom, wallpaper, mouse...)?"
    echo -e "    ${YEL}No${NC} = back to the repo defaults (your old config stays in the backup)."
    printf "%b" "    Keep them? [Y/n]: "
    read -r ks
    case "$ks" in [Nn]) KEEP_SETTINGS=0 ;; *) KEEP_SETTINGS=1 ;; esac
fi

echo ""
printf "%b" "${BLD}${BLU}[?]${NC} Continue? [y/N]: "
read -r yn
case "$yn" in [Yy]) ;; *) echo "Cancelled."; exit 0 ;; esac

# ── Free space check ──────────────────────────────────────────
# junest + packages ≈ 6.5 GB on a first install, the rest (configs, fonts,
# wallpapers) ≈ 0.5 GB. A full home quota would stop pacman half-way.
if [ "$UPDATE" -eq 1 ]; then
    NEED_GB=1
elif [ -d "$HOME/.junest/usr" ] && [ "$WIPE_JUNEST" -eq 0 ]; then
    NEED_GB=1
else
    NEED_GB=7
fi
FREE_GB=$(df --output=avail -BG "$HOME" 2>/dev/null | tail -1 | tr -dc '0-9')
if [ -n "$FREE_GB" ] && [ "$FREE_GB" -lt "$NEED_GB" ]; then
    warn "Only ${FREE_GB} GB free in $HOME — about ${NEED_GB} GB are needed."
    printf "%b" "${BLD}${BLU}[?]${NC} Continue anyway? [y/N]: "
    read -r ans
    case "$ans" in [Yy]) ;; *) echo "Cancelled — free some space first (du -sh ~/* ~/.[!.]* | sort -h)."; exit 0 ;; esac
else
    info "Free space: ${FREE_GB:-?} GB (needs ~${NEED_GB} GB)."
fi

if [ "$FRESH" -eq 1 ]; then
    info "Fresh reinstall — wiping previous installer state..."
    rm -rf "$HOME/.oh-my-zsh"
    if [ "$WIPE_JUNEST" -eq 1 ]; then
        info "Wiping junest Arch environment..."
        rm -rf "$HOME/.junest" "$HOME/.local/share/junest"
    fi
fi

# ── Step 1: junest setup ──────────────────────────────────────
clear
if [ "$UPDATE" -eq 1 ]; then
    info "Step 1/7 — Checking for packages added by the new version..."
    # Package names of the full install (literal ones only: the browser, editor
    # and icon packs come from the install questions and are already there).
    PKGS=$(awk '
        /sudo pacman -S --needed --noconfirm/ { grab = 1; sub(/.*--noconfirm/, "") }
        grab {
            cont = ($0 ~ /\\[ \t]*$/); line = $0; gsub(/\\/, " ", line)
            n = split(line, w, /[ \t]+/)
            for (i = 1; i <= n; i++) {
                if (w[i] == "") continue
                if (w[i] !~ /^[a-z0-9][a-z0-9+._-]*$/) break
                print w[i]
            }
            if (!cont) grab = 0
        }' "$REPO/.bspwminstaller/install_prerequisites_pacman.sh" | sort -u)
    # pacman -T prints the ones that are not installed
    # shellcheck disable=SC2086
    # (only names from the list: junest may print its own messages)
    MISSING=$("$JUNEST_BIN" -- pacman -T $PKGS 2>/dev/null | grep -Fx -f <(printf '%s\n' $PKGS) | tr '\n' ' ' || true)
    MISSING="${MISSING% }"
    if [ -z "$MISSING" ]; then
        info "All packages already installed."
    else
        info "Installing: $MISSING"
        # No -Syu here (slow, and it can break the pinned mesa): if the package
        # database is too old for these, a full install is needed.
        # shellcheck disable=SC2086
        "$JUNEST_BIN" -- sudo pacman -S --needed --noconfirm $MISSING ||
            warn "Could not install: $MISSING. Run $0 (full install) to update the package database."
    fi
else
    info "Step 1/7 — Installing junest and packages..."
    bash "$REPO/.bspwminstaller/install_junest.sh"
fi

# ── Step 2: Backup ────────────────────────────────────────────
clear
info "Step 2/7 — Backing up existing configs..."
BACKUP="$HOME/.config-backup-$STAMP"
mkdir -p "$BACKUP"
backed=0
for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch Thunar; do
    [ -d "$HOME/.config/$cfg" ] && mv "$HOME/.config/$cfg" "$BACKUP/" && backed=1
done
[ -f "$HOME/.gtkrc-2.0" ] && mv "$HOME/.gtkrc-2.0" "$BACKUP/" && backed=1
[ -f "$HOME/.Xresources" ] && mv "$HOME/.Xresources" "$BACKUP/" && backed=1
# zshrc: copies only, step 7 edits ~/.zshrc in place
for f in .zshrc .zshrc.bak; do
    [ -f "$HOME/$f" ] && cp -p "$HOME/$f" "$BACKUP/" && backed=1
done
if [ "$backed" -eq 1 ]; then
    info "Backups saved to: $BACKUP"
else
    rmdir "$BACKUP" 2>/dev/null
    info "Nothing to back up."
fi

# Keep only the 3 most recent backups (~25 MB each, the home quota is small)
ls -1d "$HOME"/.config-backup-* 2>/dev/null | sort -r | tail -n +4 | while read -r old; do
    rm -rf "$old"
    info "Removed old backup: $old"
done

# ── Step 3: Deploy dotfiles ───────────────────────────────────
clear
info "Step 3/7 — Deploying dotfiles..."

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"

# Installer scripts — remove first so renamed/deleted files from older
# versions never linger alongside the current ones.
rm -rf "$HOME/.bspwminstaller"
mkdir -p "$HOME/.bspwminstaller"
cp -r "$REPO/.bspwminstaller/." "$HOME/.bspwminstaller/"
chmod +x "$HOME/.bspwminstaller/"*.sh
info "Deployed: ~/.bspwminstaller"

# Config directories
for cfg in bspwm micro alacritty kitty clipcat gtk-3.0 mpd ncmpcpp paru yazi btop fastfetch Thunar; do
    [ -d "$REPO/.config/$cfg" ] || { warn "$cfg not in repo — skipping"; continue; }
    cp -r "$REPO/.config/$cfg" "$HOME/.config/$cfg"
    info "Deployed: ~/.config/$cfg"
done

# Per-user state kept in ~/.config/bspwm (moved to the backup above): the lock
# screen wallpaper chosen in Rice Settings and the "default hidden apps already
# applied" marker, so a reinstall doesn't undo them.
for f in lock-wallpaper.jpg lock-wallpaper.src .hidden-apps-applied; do
    [ -e "$BACKUP/bspwm/$f" ] && cp -p "$BACKUP/bspwm/$f" "$HOME/.config/bspwm/$f" && info "Kept: ~/.config/bspwm/$f"
done

# Settings written by Rice Settings / the bspwm scripts, restored when asked:
# whole files for configs and state, key by key for theme-config.bash so the
# keys added by a newer repo version are kept with their default value.
if [ "$KEEP_SETTINGS" -eq 1 ] && [ -d "$BACKUP/bspwm" ]; then
    OLD="$BACKUP/bspwm"; NEW="$HOME/.config/bspwm"
    for f in .rice \
             config/picom.conf config/picom-animations.conf config/xsettingsd config/jgmenurc \
             config/dunstrc config/sxhkdrc config/system.ini config/NetManagerDM.ini \
             config/hidden-apps config/.term config/.launcher config/.sys config/.first_run_done \
             config/.animwall_last config/.animwall_index config/.brightness_xrandr config/.bt_favorites; do
        [ -e "$OLD/$f" ] || continue
        # New keybinds from the repo would be lost: leave its version next to it
        if [ "$f" = config/sxhkdrc ] && ! cmp -s "$OLD/$f" "$NEW/$f"; then
            cp "$NEW/$f" "$NEW/$f.new"
            warn "Kept your sxhkdrc — the repo version is in ~/.config/bspwm/config/sxhkdrc.new"
        fi
        cp -p "$OLD/$f" "$NEW/$f"
    done
    [ -d "$OLD/config/.session" ] && rm -rf "$NEW/config/.session" && cp -rp "$OLD/config/.session" "$NEW/config/.session"
    for old_cfg in "$OLD"/rices/*/theme-config.bash; do
        new_cfg="$NEW/rices/$(basename "$(dirname "$old_cfg")")/theme-config.bash"
        [ -f "$new_cfg" ] || continue
        awk 'NR==FNR { if (match($0, /^[A-Za-z_][A-Za-z0-9_]*=/)) old[substr($0, 1, RLENGTH)] = $0; next }
             { if (match($0, /^[A-Za-z_][A-Za-z0-9_]*=/) && (substr($0, 1, RLENGTH) in old)) { print old[substr($0, 1, RLENGTH)]; next } }
             { print }' "$old_cfg" "$new_cfg" > "$new_cfg.tmp" && mv "$new_cfg.tmp" "$new_cfg"
    done
    # Terminal configs (Rice Settings edits font/opacity there)
    for f in alacritty/alacritty.toml kitty/kitty.conf; do
        [ -f "$BACKUP/$f" ] && [ -f "$HOME/.config/$f" ] && cp -p "$BACKUP/$f" "$HOME/.config/$f"
    done
    info "Your bspwm settings were kept."
fi

# Home dotfiles (.zshrc.bak is the bspwm zshrc — swapped in at login, user's .zshrc untouched)
for f in .gtkrc-2.0 .Xresources; do
    [ -f "$REPO/$f" ] && cp "$REPO/$f" "$HOME/$f" && info "Deployed: ~/$f"
done
if [ "$ZSHRC_MODE" = mine ]; then
    cp "$REPO/.zshrc.bak" "$HOME/.zshrc.bak" && info "Deployed: ~/.zshrc.bak (bspwm zshrc)"
else
    # No ~/.zshrc.bak = bspwm.sh has nothing to swap in (a copy is in the backup)
    rm -f "$HOME/.zshrc.bak"
    info "Keeping your own ~/.zshrc in bspwm too."
fi
[ -f "$REPO/.config/brave-flags.conf" ] && cp "$REPO/.config/brave-flags.conf" "$HOME/.config/" && info "Deployed: ~/.config/brave-flags.conf"

# Rewrite any hardcoded paths to match the installing user
grep -rl "/home/zsonie" "$HOME/.config/bspwm" "$HOME/.bspwminstaller" "$HOME/.Xresources" "$HOME/.zshrc.bak" 2>/dev/null \
    | xargs -r sed -i "s|/home/zsonie|$HOME|g"
info "Hardcoded paths rewritten to: $HOME"

# Installer choices (saved by install_prerequisites_pacman.sh in step 1):
# applied to the deployed copies only, the repo stays untouched.
CHOICES="$HOME/.cache/bspwm-install-choices"
if [ "$UPDATE" -eq 1 ] && [ ! -f "$SAVED_CHOICES" ] && [ -f "$BACKUP/bspwm/bin/OpenApps" ]; then
    # Installed before the choices were saved: read them back from the old files
    case_line() { sed -n "/$1)/,/;;/{/$1)/d;/;;/d;s/^[[:space:]]*//;p}" "$2" | head -1; }
    _b=$(case_line --browser "$BACKUP/bspwm/bin/OpenApps")
    _e=$(case_line --editor  "$BACKUP/bspwm/bin/OpenApps")
    mkdir -p "$(dirname "$SAVED_CHOICES")"
    {
        printf 'BROWSER_BIN=%q\n' "$_b"
        case "$_e" in
            "Term --"*) printf 'EDITOR_BIN=%q\nEDITOR_GUI=0\n' "${_e#Term --}" ;;
            ?*)         printf 'EDITOR_BIN=%q\nEDITOR_GUI=1\n' "$_e" ;;
        esac
    } > "$SAVED_CHOICES"
    unset _b _e
    info "Choices read from your previous install: $(tr '\n' ' ' < "$SAVED_CHOICES")"
fi
if [ "$UPDATE" -eq 1 ] && [ -f "$SAVED_CHOICES" ]; then
    mkdir -p "$(dirname "$CHOICES")" && cp "$SAVED_CHOICES" "$CHOICES"
fi
if [ -f "$CHOICES" ]; then
    # shellcheck disable=SC1090
    . "$CHOICES"
    BSPWM_CFG="$HOME/.config/bspwm"
    # Update: terminal and rice come from the kept settings (Rice Settings may have changed them)
    if [ "$UPDATE" -eq 0 ]; then
        [ -n "$TERM_BIN" ]    && echo "$TERM_BIN"    > "$BSPWM_CFG/config/.term"
        [ -n "$ACTIVE_RICE" ] && echo "$ACTIVE_RICE" > "$BSPWM_CFG/.rice"
    fi
    OPENAPPS="$BSPWM_CFG/bin/OpenApps"
    for sxhkd in "$BSPWM_CFG/config/sxhkdrc" "$BSPWM_CFG/config/.session/sxhkdrc"; do
        [ -f "$sxhkd" ] || continue
        # super+w is "brave --password-store=basic": replace the whole line (flag is brave-only)
        [ -n "$BROWSER_BIN" ] && [ "$BROWSER_BIN" != brave ] && sed -i "s|^\tbrave\( .*\)\?$|\t$BROWSER_BIN|" "$sxhkd"
        if [ "$EDITOR_GUI" = "1" ]; then
            sed -i "s|^\tcode \.$|\t$EDITOR_BIN .|" "$sxhkd"
        elif [ -n "$EDITOR_BIN" ]; then
            sed -i "s|^\tcode \.$|\tTerm --$EDITOR_BIN|" "$sxhkd"
        fi
    done
    if [ -f "$OPENAPPS" ]; then
        [ -n "$BROWSER_BIN" ] && sed -i "/--browser)/,/;;/{s|^\t\t[a-z].*$|\t\t$BROWSER_BIN|}" "$OPENAPPS"
        if [ "$EDITOR_GUI" = "1" ]; then
            sed -i "/--editor)/,/;;/{s|^\t\t[a-zA-Z].*$|\t\t$EDITOR_BIN|}" "$OPENAPPS"
        elif [ -n "$EDITOR_BIN" ]; then
            sed -i "/--editor)/,/;;/{s|^\t\t[a-zA-Z].*$|\t\tTerm --$EDITOR_BIN|}" "$OPENAPPS"
        fi
    fi
    if [ "$UPDATE" -eq 1 ] && [ -f "$HOME/.zshrc.bak" ] && [ -f "$BACKUP/.zshrc.bak" ]; then
        # Keep the EDITOR / BROWSER of the bspwm zshrc being replaced
        for v in EDITOR BROWSER; do
            old=$(grep -m1 "^export $v=" "$BACKUP/.zshrc.bak" || true)
            [ -n "$old" ] && sed -i "s|^export $v=.*|$(printf '%s' "$old" | sed 's/[|&\\]/\\&/g')|" "$HOME/.zshrc.bak"
        done
    elif [ -f "$HOME/.zshrc.bak" ]; then
        [ -n "$EDITOR_BIN" ]  && sed -i "s|^export EDITOR=.*|export EDITOR='$EDITOR_BIN'|" "$HOME/.zshrc.bak"
        [ -n "$BROWSER_BIN" ] && sed -i "s|^export BROWSER=.*|export BROWSER='$BROWSER_BIN'|" "$HOME/.zshrc.bak"
    fi
    YAZI_CFG="$HOME/.config/yazi/yazi.toml"
    [ -f "$YAZI_CFG" ] && [ -n "$EDITOR_BIN" ] && sed -i "s|\${EDITOR:-[a-z]*}|\${EDITOR:-$EDITOR_BIN}|" "$YAZI_CFG"
    if [ "$UPDATE" -eq 1 ]; then
        info "Choices applied: browser=$BROWSER_BIN editor=$EDITOR_BIN"
    else
        info "Choices applied: terminal=$TERM_BIN rice=$ACTIVE_RICE browser=$BROWSER_BIN editor=$EDITOR_BIN"
    fi
    mkdir -p "$(dirname "$SAVED_CHOICES")"
    mv -f "$CHOICES" "$SAVED_CHOICES"      # kept for the next --update
else
    warn "No installer choices found — keeping the repo defaults (terminal, rice, browser, editor)."
fi

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
    # Exec= needs an absolute path: @HOME@ placeholders (steam.desktop)
    grep -l '@HOME@' "$HOME/.local/share/applications/"*.desktop 2>/dev/null |
        while read -r f; do sed -i "s#@HOME@#$HOME#g" "$f"; done
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

# ── Step 5: GNOME Super+Shift+B shortcut────────────────────────
clear
info "Step 5/7 — Registering GNOME keyboard shortcut (Super+Shift+B → bspwm)..."
if [ -n "$BSPWM_SKIP_GNOME_SHORTCUT" ]; then
    warn "BSPWM_SKIP_GNOME_SHORTCUT set — skipping the GNOME shortcut."
elif command -v dconf >/dev/null 2>&1; then
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

ZSHRC="$HOME/.zshrc"
[ -f "$ZSHRC" ] || { echo "# ~/.zshrc" > "$ZSHRC"; info "No ~/.zshrc — created an empty one."; }

# Drop the previous block: the marked one, or the unmarked one older installers
# appended (only when both its first and last lines are there).
sed -i '/^# >>> bspwm-dotfiles >>>$/,/^# <<< bspwm-dotfiles <<<$/d' "$ZSHRC"
if grep -q '^# Swap to bspwm zshrc when running inside junest' "$ZSHRC" &&
   grep -q '^alias unityhub-tmp-install=' "$ZSHRC"; then
    sed -i '/^# Swap to bspwm zshrc when running inside junest/,/^alias unityhub-tmp-install=/d' "$ZSHRC"
fi

# The block goes first: in "mine" mode the swap happens before the rest of
# the GNOME config (oh-my-zsh...) gets loaded inside junest.
{
    echo '# >>> bspwm-dotfiles >>>'
    echo '# Written by bspwm-dotfiles install.sh, rewritten on every install.'
    if [ "$ZSHRC_MODE" = mine ]; then
        cat << 'EOF'
# Inside junest (bspwm) use the bspwm zshrc: swap ~/.zshrc <-> ~/.zshrc.bak, reload.
if [[ -n "$JUNEST_ENV" && -f "$HOME/.zshrc.bak" ]]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.tmp"
    mv "$HOME/.zshrc.bak" "$HOME/.zshrc"
    mv "$HOME/.zshrc.tmp" "$HOME/.zshrc.bak"
    exec zsh
fi
EOF
    fi
    cat << 'EOF'
# ~/.local/bin: steam, the installers, claude, uv... (nothing else adds it here)
export PATH="$HOME/.local/bin:$PATH"
# junest launcher + wrappers, GNOME only (inside bspwm they would shadow sudo/pacman)
if [[ -z "$JUNEST_ENV" ]]; then
    export PATH="$HOME/.local/share/junest/bin:$PATH"
    export PATH="$PATH:$HOME/.junest/usr/bin_wrappers"
fi
# /tmp installers (Steam, Unity Hub)
alias steam-tmp-install="$HOME/.local/bin/steam-installer.sh"
alias unityhub-tmp-install="$HOME/.local/bin/install_unityhub.sh"
# <<< bspwm-dotfiles <<<

EOF
} > "$ZSHRC.new"
cat "$ZSHRC" >> "$ZSHRC.new" && mv "$ZSHRC.new" "$ZSHRC"
info "~/.zshrc patched (mode: $ZSHRC_MODE)."

# ── Done ──────────────────────────────────────────────────────
clear
echo ""
if [ "$UPDATE" -eq 1 ]; then
    echo -e "${BLD}${GRN}  ✓ Update complete!${NC}"
    [ -f "$HOME/.config/bspwm/config/sxhkdrc.new" ] &&
        echo -e "  ${YEL}New keybinds:${NC} compare with ~/.config/bspwm/config/sxhkdrc.new"
else
    echo -e "${BLD}${GRN}  ✓ Installation complete!${NC}"
fi
echo ""
echo -e "  ${YEL}Next step:${NC} launch bspwm via"
echo -e "     ${BLU}~/.bspwminstaller/bspwm.sh${NC}"
echo ""
warn "Note: ft_lock (/usr/share/42/ft_lock) is 42-school specific."
warn "      Update the lock button in eww/profilecard if running elsewhere."
echo ""
