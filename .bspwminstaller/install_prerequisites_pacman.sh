#!/bin/bash
# ============================================================
# install_prerequisites_pacman.sh
# Install bspwm dotfiles dependencies inside junest (Arch / pacman)
# Package list mirrors the original RiceInstaller by gh0stzk.
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ask_editor() {
    printf "\nWhich editor do you want to install?\n"
    printf "  1) micro   (terminal, already included — default)\n"
    printf "  2) neovim  (terminal, via kitty)\n"
    printf "  3) vscode  (visual-studio-code-bin)\n"
    printf "  4) zed     (GUI, zed-preview-bin)\n"
    printf "Enter number [1]: "
    read -r editor_choice </dev/tty || true
    case "$editor_choice" in
        1|""|micro)  EDITOR_PKG="";                          EDITOR_BIN="micro"; EDITOR_GUI=0 ;;
        2|neovim)    EDITOR_PKG="neovim";                    EDITOR_BIN="nvim";  EDITOR_GUI=0 ;;
        3|vscode)    EDITOR_PKG="visual-studio-code-bin";    EDITOR_BIN="code";  EDITOR_GUI=1 ;;
        4|zed)       EDITOR_PKG="zed-preview-bin";           EDITOR_BIN="zed";   EDITOR_GUI=1 ;;
        *)           EDITOR_PKG="";                          EDITOR_BIN="micro"; EDITOR_GUI=0 ;;
    esac
    info "Editor selected: $EDITOR_BIN${EDITOR_PKG:+ (package: $EDITOR_PKG)}"
}

# Map an icon theme name (as written in theme-config.bash) to its gh0stzk package.
# Prints nothing for themes that need no extra package (e.g. Papirus, installed separately).
icon_theme_pkg() {
    case "${1,,}" in
        beautyline*)          echo gh0stzk-icons-beautyline ;;
        candy*)               echo gh0stzk-icons-candy ;;
        catppuccin*)          echo gh0stzk-icons-catppuccin-mocha ;;
        dracula*)             echo gh0stzk-icons-dracula ;;
        glassy*)              echo gh0stzk-icons-glassy ;;
        gruvbox*)             echo gh0stzk-icons-gruvbox-plus-dark ;;
        hack*)                echo gh0stzk-icons-hack ;;
        luv*)                 echo gh0stzk-icons-luv ;;
        sweet*)               echo gh0stzk-icons-sweet-rainbow ;;
        tokyo*)               echo gh0stzk-icons-tokyo-night ;;
        vimix*)               echo gh0stzk-icons-vimix-white ;;
        zafiro-purple*)       echo gh0stzk-icons-zafiro-purple ;;
        zafiro*)              echo gh0stzk-icons-zafiro ;;
        papirus*|adwaita*|"") ;;
        *) warn "Unknown icon theme '$1' — no package mapped, install it manually." >&2 ;;
    esac
}

ask_rice() {
    local rices_dir="$DOTFILES_DIR/.config/bspwm/rices"
    local rices=()
    local d
    for d in "$rices_dir"/*/; do
        [ -f "$d/theme-config.bash" ] && rices+=("$(basename "$d")")
    done
    [ ${#rices[@]} -gt 0 ] || error "No rices found in $rices_dir"

    if [ ${#rices[@]} -eq 1 ]; then
        SELECTED_RICES=("${rices[0]}")
        info "Only one rice available: ${rices[0]} (selected automatically)"
    else
        printf "\nWhich rice theme(s) do you want to install?\n"
        printf "Enter numbers separated by spaces, or 'all' for everything.\n"
        printf "The first one selected becomes the active rice.\n\n"
        local i
        for i in "${!rices[@]}"; do
            printf "  %2d) %s\n" "$((i + 1))" "${rices[$i]}"
        done
        printf "\nEnter selection [all]: "
        local rice_choice=""
        read -r rice_choice </dev/tty || true

        SELECTED_RICES=()
        if [[ -z "$rice_choice" || "$rice_choice" == "all" ]]; then
            SELECTED_RICES=("${rices[@]}")
        else
            local n
            for n in $rice_choice; do
                if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#rices[@]} )); then
                    SELECTED_RICES+=("${rices[$((n - 1))]}")
                else
                    warn "Ignoring invalid choice: $n"
                fi
            done
            if [ ${#SELECTED_RICES[@]} -eq 0 ]; then
                warn "No valid selection — installing all rices."
                SELECTED_RICES=("${rices[@]}")
            fi
        fi
        info "Selected rices: ${SELECTED_RICES[*]}"
    fi

    # Icon packages: read the icon themes each rice actually uses
    local -A seen=()
    local rice name pkg
    ICON_PKGS=()
    for rice in "${SELECTED_RICES[@]}"; do
        while read -r name; do
            pkg=$(icon_theme_pkg "$name")
            if [ -n "$pkg" ] && [ -z "${seen[$pkg]}" ]; then
                seen[$pkg]=1
                ICON_PKGS+=("$pkg")
            fi
        done < <(sed -nE 's/^(gtk_icons|dunst_icon_theme)="([^"]*)".*/\2/p' "$rices_dir/$rice/theme-config.bash")
    done
    info "Icon packages needed: ${ICON_PKGS[*]:-none}"
}

ask_browser() {
    printf "\nWhich browser do you want to install? (default: brave)\n"
    printf "  1) brave\n  2) firefox\n  3) chromium\n  4) google-chrome\n"
    printf "Enter number [1]: "
    read -r browser_choice </dev/tty || true
    case "$browser_choice" in
        1|""|brave)      BROWSER_PKG="brave-bin";      BROWSER_BIN="brave" ;;
        2|firefox)       BROWSER_PKG="firefox";        BROWSER_BIN="firefox" ;;
        3|chromium)      BROWSER_PKG="chromium";       BROWSER_BIN="chromium" ;;
        4|google-chrome) BROWSER_PKG="google-chrome";  BROWSER_BIN="google-chrome-stable" ;;
        *)               BROWSER_PKG="brave-bin";      BROWSER_BIN="brave" ;;
    esac
    info "Browser selected: $BROWSER_BIN (package: $BROWSER_PKG)"
}

ask_terminal() {
    printf "\nWhich terminal do you want as default? (default: alacritty)\n"
    printf "  1) alacritty  (default)\n  2) kitty\n  3) st\n"
    printf "Enter number [1]: "
    read -r term_choice </dev/tty || true
    case "$term_choice" in
        1|""|alacritty) TERM_BIN="alacritty" ;;
        2|kitty)        TERM_BIN="kitty" ;;
        3|st)           TERM_BIN="st" ;;
        *)              TERM_BIN="alacritty" ;;
    esac
    info "Terminal selected: $TERM_BIN"
}

patch_makepkg() {
    # makepkg refuses to run as root — patch the check out (junest proot workaround)
    if grep -q 'EUID == 0' /usr/bin/makepkg 2>/dev/null; then
        sudo sed -i 's/|| (( EUID == 0 ))//' /usr/bin/makepkg
        info "makepkg root check patched."
    fi
}

aur_install() {
    local pkg="$1"
    info "Building AUR package: $pkg"
    rm -rf "/tmp/$pkg"
    git clone "https://aur.archlinux.org/${pkg}.git" "/tmp/$pkg"
    (cd "/tmp/$pkg" && makepkg -si --noconfirm)
    rm -rf "/tmp/$pkg"
}

add_chaotic_repo() {
    if grep -q '\[chaotic-aur\]' /etc/pacman.conf 2>/dev/null; then
        info "chaotic-aur already configured."
        return
    fi
    info "Adding chaotic-aur repository..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy --noconfirm
    info "chaotic-aur added."
}

add_gh0stzk_repo() {
    if grep -q '\[gh0stzk-dotfiles\]' /etc/pacman.conf 2>/dev/null; then
        info "gh0stzk-dotfiles repo already configured."
        return
    fi
    info "Adding gh0stzk-dotfiles repository..."
    printf '\n[gh0stzk-dotfiles]\nSigLevel = Optional TrustAll\nServer = http://gh0stzk.github.io/pkgs/x86_64\n' \
        | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy --noconfirm
    info "gh0stzk-dotfiles repo added."
}

# ── Interactive setup (ask before any installs) ───────────────────────────────
ask_editor
ask_browser
ask_terminal
ask_rice

# ── Update keyring + full system sync ────────────────────────────────────────
info "Syncing package databases..."
echo "n" | sudo pacman -Syu || true

info "Installing fresh archlinux-keyring..."
sudo pacman -S --noconfirm archlinux-keyring
sudo pacman-key --populate archlinux

info "Running full system upgrade..."
sudo pacman -Syu --noconfirm

# ── Base build tools ─────────────────────────────────────────────────────────
info "Installing base-devel and git..."
sudo pacman -S --needed --noconfirm base-devel git

# ── Chaotic-AUR + gh0stzk custom repo ────────────────────────────────────────
add_chaotic_repo
add_gh0stzk_repo

# ── Core WM ──────────────────────────────────────────────────────────────────
info "Installing core WM packages..."
sudo pacman -S --needed --noconfirm \
    bspwm \
    sxhkd \
    polybar \
    rofi \
    dunst \
    xsettingsd \
    xorg-xrandr \
    xorg-xdpyinfo \
    xorg-xkill \
    xorg-xprop \
    xorg-xrdb \
    xorg-xsetroot \
    xorg-xwininfo \
    xdotool \
    xdo \
    wmctrl

# ── Terminals ────────────────────────────────────────────────────────────────
info "Installing terminals and launcher..."
sudo pacman -S --needed --noconfirm \
    alacritty \
    kitty \
    jgmenu

# Write chosen terminal to .term config
echo "$TERM_BIN" > "$DOTFILES_DIR/.config/bspwm/config/.term"
info "Default terminal set to $TERM_BIN in .term"

# Write active rice (first selected) to .rice
echo "${SELECTED_RICES[0]}" > "$DOTFILES_DIR/.config/bspwm/.rice"
info "Active rice set to ${SELECTED_RICES[0]} in .rice"

# ── File manager ─────────────────────────────────────────────────────────────
info "Installing file manager..."
sudo pacman -S --needed --noconfirm \
    thunar \
    tumbler \
    gvfs-mtp \
    yazi

# ── Editor ───────────────────────────────────────────────────────────────────
if [ -n "$EDITOR_PKG" ]; then
    info "Installing editor: $EDITOR_PKG..."
    sudo pacman -S --needed --noconfirm "$EDITOR_PKG"
else
    info "Editor: micro (already included in base packages — skipping extra install)"
fi

# ── Media & audio ────────────────────────────────────────────────────────────
info "Installing media packages..."
sudo pacman -S --needed --noconfirm \
    mpd \
    mpc \
    ncmpcpp \
    mpv \
    playerctl \
    pamixer \
    ffmpeg

# ── Bluetooth ────────────────────────────────────────────────────────────────
info "Installing bluetooth packages..."
sudo pacman -S --needed --noconfirm \
    bluez \
    bluez-utils

# ── System utilities ─────────────────────────────────────────────────────────
info "Installing system utilities..."
sudo pacman -S --needed --noconfirm \
    brightnessctl \
    lxsession \
    xclip \
    xdg-user-dirs \
    jq \
    curl \
    bc \
    feh \
    maim \
    imagemagick \
    redshift \
    xcolor \
    libwebp \
    webp-pixbuf-loader \
    python-gobject \
    pacman-contrib

# ── CLI tools ────────────────────────────────────────────────────────────────
info "Installing CLI tools..."
sudo pacman -S --needed --noconfirm \
    bat \
    eza \
    btop \
    micro \
    ncdu

# ── Icons & themes ───────────────────────────────────────────────────────────
info "Installing icons and themes..."
# papirus-icon-theme is used by rofi and jgmenu configs
sudo pacman -S --needed --noconfirm papirus-icon-theme

# ── gh0stzk GTK themes, cursors and icon packs ───────────────────────────────
info "Installing gh0stzk GTK themes, cursors and icon sets: ${ICON_PKGS[*]:-none}"
sudo pacman -S --needed --noconfirm \
    gh0stzk-gtk-themes \
    gh0stzk-cursor-qogirr \
    "${ICON_PKGS[@]}"

# ── Shell ────────────────────────────────────────────────────────────────────
info "Installing zsh and plugins..."
sudo pacman -S --needed --noconfirm \
    zsh \
    zsh-autosuggestions \
    zsh-history-substring-search \
    zsh-syntax-highlighting

# ── Fonts ────────────────────────────────────────────────────────────────────
info "Installing fonts..."
# Other fonts (MapleMono, Phosphor, scientifica, Meslo, ...) are bundled in
# .local/share/fonts and deployed by install.sh step 4.
sudo pacman -S --needed --noconfirm \
    fontconfig \
    ttf-jetbrains-mono \
    ttf-jetbrains-mono-nerd \
    ttf-font-awesome

# ── Clipboard ────────────────────────────────────────────────────────────────
info "Installing clipcat..."
sudo pacman -S --needed --noconfirm clipcat

# ── picom (official repo) ─────────────────────────────────────────────────────
info "Installing picom..."
sudo pacman -S --needed --noconfirm picom

# ── eww-git (chaotic-aur prebuilt) ───────────────────────────────────────────
info "Installing eww-git from chaotic-aur..."
sudo pacman -S --needed --noconfirm eww-git

# ── AUR packages ──────────────────────────────────────────────────────────────
patch_makepkg

info "Installing xwinwrap-0.9-bin (AUR)..."
aur_install xwinwrap-0.9-bin

info "Installing fzf-tab-git (AUR)..."
aur_install fzf-tab-git

info "Installing ttf-material-design-icons (AUR)..."
aur_install ttf-material-design-icons-desktop-git

# ── Bundled fonts ─────────────────────────────────────────────────────────────
info "Copying bundled fonts to ~/.local/share/fonts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONTS_SRC="$SCRIPT_DIR/../.local/share/fonts"
if [ -d "$FONTS_SRC" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$FONTS_SRC"/. "$HOME/.local/share/fonts/"
    fc-cache -fv || warn "fc-cache failed — fonts may need a manual cache refresh."
    info "Fonts installed."
else
    warn "Bundled fonts directory not found at $FONTS_SRC — skipping."
fi

# ── Browser ──────────────────────────────────────────────────────────────────
info "Installing browser: $BROWSER_PKG..."
sudo pacman -S --needed --noconfirm "$BROWSER_PKG"

# Patch sxhkdrc (super+w) and OpenApps (--browser) with chosen browser
for sxhkd in \
    "$DOTFILES_DIR/.config/bspwm/config/sxhkdrc" \
    "$DOTFILES_DIR/.config/bspwm/config/.session/sxhkdrc"; do
    # super+w is "brave --password-store=basic": replace the whole line (flag is brave-only)
    [ -f "$sxhkd" ] && [ "$BROWSER_BIN" != brave ] && sed -i "s|^\tbrave\( .*\)\?$|\t$BROWSER_BIN|" "$sxhkd"
done
OPENAPPS="$DOTFILES_DIR/.config/bspwm/bin/OpenApps"
[ -f "$OPENAPPS" ] && sed -i "/--browser)/,/;;/{s|^\t\t[a-z].*$|\t\t$BROWSER_BIN|}" "$OPENAPPS"
info "sxhkdrc (super+w) and OpenApps --browser patched to use $BROWSER_BIN."

# Patch editor references in sxhkdrc, OpenApps and .zshrc.bak
OPENAPPS="$DOTFILES_DIR/.config/bspwm/bin/OpenApps"
for sxhkd in \
    "$DOTFILES_DIR/.config/bspwm/config/sxhkdrc" \
    "$DOTFILES_DIR/.config/bspwm/config/.session/sxhkdrc"; do
    [ -f "$sxhkd" ] || continue
    if [ "$EDITOR_GUI" = "1" ]; then
        sed -i "s|^\tcode \.$|\t$EDITOR_BIN .|" "$sxhkd"
    else
        sed -i "s|^\tcode \.$|\tTerm --$EDITOR_BIN|" "$sxhkd"
    fi
done
if [ -f "$OPENAPPS" ]; then
    if [ "$EDITOR_GUI" = "1" ]; then
        sed -i "/--editor)/,/;;/{s|^\t\t[a-zA-Z].*$|\t\t$EDITOR_BIN|}" "$OPENAPPS"
    else
        sed -i "/--editor)/,/;;/{s|^\t\t[a-zA-Z].*$|\t\tTerm --$EDITOR_BIN|}" "$OPENAPPS"
    fi
fi
ZSHRC_BAK="$DOTFILES_DIR/.zshrc.bak"
if [ -f "$ZSHRC_BAK" ]; then
    sed -i "s|^export EDITOR=.*|export EDITOR='$EDITOR_BIN'|" "$ZSHRC_BAK"
    sed -i "s|^export BROWSER=.*|export BROWSER='$BROWSER_BIN'|" "$ZSHRC_BAK"
    info ".zshrc.bak EDITOR=$EDITOR_BIN and BROWSER=$BROWSER_BIN patched."
fi
# Patch yazi fallback editor
YAZI_CFG="$DOTFILES_DIR/.config/yazi/yazi.toml"
[ -f "$YAZI_CFG" ] && sed -i "s|\${EDITOR:-[a-z]*}|\${EDITOR:-$EDITOR_BIN}|" "$YAZI_CFG"
info "sxhkdrc, OpenApps, .zshrc.bak and yazi.toml patched for editor=$EDITOR_BIN browser=$BROWSER_BIN."

# ── Default cursor theme (required by 05-gtk.sh on first boot) ───────────────
info "Creating ~/.icons/default/index.theme..."
mkdir -p "$HOME/.icons/default"
if [ ! -f "$HOME/.icons/default/index.theme" ]; then
    printf '[Icon Theme]\nName=Default\nComment=Default Cursor Theme\nInherits=Qogirr-Dark\n' \
        > "$HOME/.icons/default/index.theme"
fi

# ── Config backup dir (required by bspwmrc on every startup) ─────────────────
info "Setting up ~/.local/share/gh0stzk/config/bspwm/config backup dir..."
BACKUP_CFG="$HOME/.local/share/gh0stzk/config/bspwm/config"
mkdir -p "$BACKUP_CFG"
for f in dunstrc picom.conf picom-animations.conf xsettingsd jgmenurc; do
    src="$DOTFILES_DIR/.config/bspwm/config/$f"
    [ -f "$src" ] && cp "$src" "$BACKUP_CFG/$f"
done
info "Backup config files copied."

# ── Bluetooth service ─────────────────────────────────────────────────────────
warn "Bluetooth: enable the service on your host system with:"
warn "  sudo systemctl enable --now bluetooth.service"

# ── Cleanup cache ──────────────────────────────────────────────────────────────
info "Cleaning up pacman cache..."
sudo pacman -Sc --noconfirm >/dev/null 2>&1 || true
info "Cache cleaned."

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
info "All prerequisites installed."
warn "Note: This config was built for a 42 school junest environment."
warn "      ft_lock (/host/usr/share/42/ft_lock) is 42-specific and won't exist elsewhere."
warn "      The lock button in the eww profilecard will need to be changed for non-42 use."