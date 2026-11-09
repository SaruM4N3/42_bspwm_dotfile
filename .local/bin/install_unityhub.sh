#!/bin/sh
# Installe Unity Hub et Unity CLI dans /tmp sans droits root, configure leurs
# dossiers et installe la dernière version stable de l'éditeur Unity.
#
# Usage : sh install_unityhub.sh
# Variables optionnelles :
#   INSTALL_DIR=/chemin       dossier de Unity Hub et du CLI  (défaut : /tmp/unityhub)
#   EDITOR_DIR=/chemin        dossier d'install des éditeurs (défaut : $INSTALL_DIR/Editor)
#   DOWNLOAD_DIR=/chemin      dossier des téléchargements    (défaut : $INSTALL_DIR/Downloads)
#   UNITY_VERSION=6000.x.yfz  version de l'éditeur (défaut : 6000.5.6f1,
#                             UNITY_VERSION=latest pour la dernière stable)
#   UNITY_MODULES="webgl ..." modules à installer avec l'éditeur (défaut : webgl linux-il2cpp,
#                             UNITY_MODULES="" pour aucun)
#   SKIP_EDITOR=1             ne pas installer d'éditeur
set -eu

INSTALL_DIR="${INSTALL_DIR:-/tmp/unityhub}"
EDITOR_DIR="${EDITOR_DIR:-$INSTALL_DIR/Editor}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$INSTALL_DIR/Downloads}"
UNITY_VERSION="${UNITY_VERSION:-6000.5.6f1}"
UNITY_MODULES="${UNITY_MODULES-webgl linux-il2cpp}"
SKIP_EDITOR="${SKIP_EDITOR:-0}"
REPO="https://hub.unity3d.com/linux/repos/deb"
CLI_CDN="https://public-cdn.cloud.unity3d.com/hub/prod/cli"
HUB_CONFIG="$HOME/.config/unityhub"

# Unity CLI sans questions, bannière ni pager
export UNITY_NON_INTERACTIVE=1 UNITY_NO_BANNER=1 UNITY_NO_PAGER=1 UNITY_NO_CONSENT_PROMPT=1

# ---------------------------------------------------------------- Unity Hub
echo "==> Recherche de la dernière version de Unity Hub..."
DEB_PATH=$(curl -fsSL "$REPO/dists/stable/main/binary-amd64/Packages" \
	| awk '/^Version:/ {v=$2} /^Filename:/ {print v, $2}' \
	| sort -V | tail -n 1 | cut -d' ' -f2)
[ -n "$DEB_PATH" ] || { echo "Impossible de trouver le paquet." >&2; exit 1; }
echo "    $DEB_PATH"

# Le Hub ne doit pas tourner pendant qu'on modifie sa config et ses fichiers
if pgrep -f unityhub-bin >/dev/null 2>&1; then
	echo "==> Fermeture de Unity Hub..."
	pkill -f unityhub-bin || true
	while pgrep -f unityhub-bin >/dev/null 2>&1; do sleep 1; done
fi

mkdir -p "$INSTALL_DIR"
DEB_FILE="$INSTALL_DIR/unityhub.deb"

echo "==> Téléchargement..."
curl -fL --progress-bar -o "$DEB_FILE" "$REPO/$DEB_PATH"

echo "==> Extraction dans $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/root"
mkdir -p "$INSTALL_DIR/root"
if command -v dpkg-deb >/dev/null 2>&1; then
	dpkg-deb -x "$DEB_FILE" "$INSTALL_DIR/root"
else
	(cd "$INSTALL_DIR/root" && ar p "$DEB_FILE" "$(ar t "$DEB_FILE" | grep '^data\.tar')" | tar -xJf - 2>/dev/null \
		|| ar p "$DEB_FILE" "$(ar t "$DEB_FILE" | grep '^data\.tar')" | tar -xzf -)
fi
rm -f "$DEB_FILE"

# Le binaire est dans usr/lib/unityhub (nouveau paquet) ou opt/unityhub (ancien)
HUB_BIN=""
for f in "$INSTALL_DIR/root/usr/lib/unityhub/unityhub-bin" \
         "$INSTALL_DIR/root/opt/unityhub/unityhub-bin" \
         "$INSTALL_DIR/root/opt/unityhub/unityhub"; do
	[ -x "$f" ] && { HUB_BIN="$f"; break; }
done
[ -n "$HUB_BIN" ] || { echo "Binaire Unity Hub introuvable dans $INSTALL_DIR/root" >&2; exit 1; }

# --no-sandbox car chrome-sandbox exige d'être setuid root
HUB_CMD="\"$HUB_BIN\" --no-sandbox"
rm -f "$INSTALL_DIR/unityhub" "$INSTALL_DIR/hub-cli.log"  # anciens fichiers

# ---------------------------------------------------------------- Unity CLI
# Remplace le mode --headless du Hub, déprécié. Les stables sont dans
# latest.json, les bêtas dans latest-beta.json (seul canal pour l'instant).
echo "==> Installation de Unity CLI..."
MANIFEST=$(curl -fsSL "$CLI_CDN/latest.json" 2>/dev/null || curl -fsSL "$CLI_CDN/latest-beta.json")
CLI_VERSION=$(printf '%s\n' "$MANIFEST" | sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' | head -n 1)
CLI_SHA=$(printf '%s\n' "$MANIFEST" \
	| awk '/"linux-x64": *\{/ {f=1} f && /"sha256"/ {gsub(/.*: *"|".*/, ""); print; exit}')
[ -n "$CLI_VERSION" ] && [ -n "$CLI_SHA" ] || { echo "Manifeste de Unity CLI illisible." >&2; exit 1; }
UNITY_CLI="$INSTALL_DIR/bin/unity"
mkdir -p "$INSTALL_DIR/bin"
curl -fL --progress-bar -o "$UNITY_CLI.part" "$CLI_CDN/$CLI_VERSION/unity-linux-x64"
echo "$CLI_SHA  $UNITY_CLI.part" | sha256sum -c --quiet - \
	|| { rm -f "$UNITY_CLI.part"; echo "Somme de contrôle de Unity CLI invalide." >&2; exit 1; }
chmod +x "$UNITY_CLI.part"
mv -f "$UNITY_CLI.part" "$UNITY_CLI"
echo "    Unity CLI $CLI_VERSION"

# ------------------------------------------------------- Alias et menu
# Alias "unityhub" et "unity" dans les rc des shells (remplacés s'ils existent déjà)
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
	[ -f "$rc" ] || continue
	sed -i '/# unityhub-tmp$/d' "$rc"
	echo "alias unityhub='$HUB_CMD' # unityhub-tmp" >> "$rc"
	echo "alias unity='\"$UNITY_CLI\"' # unityhub-tmp" >> "$rc"
	echo "    Alias ajoutés dans $rc"
done
if command -v fish >/dev/null 2>&1; then
	FISH_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d"
	mkdir -p "$FISH_CONF"
	cat > "$FISH_CONF/unityhub-tmp.fish" <<EOF
alias unityhub '$HUB_CMD'
alias unity '"$UNITY_CLI"'
EOF
	echo "    Alias ajoutés dans $FISH_CONF/unityhub-tmp.fish"
fi

# Entrée du menu : même nom que celle du système (/usr/share/applications/unityhub.desktop)
# pour la remplacer, y compris pour les liens unityhub:// (connexion au compte)
APPS="$HOME/.local/share/applications"
mkdir -p "$APPS"
rm -f "$APPS/unityhub-tmp.desktop"
cat > "$APPS/unityhub.desktop" <<EOF
[Desktop Entry]
Name=Unity Hub
Exec=$HUB_CMD %U
Icon=$INSTALL_DIR/root/usr/share/icons/hicolor/256x256/apps/unityhub.png
Type=Application
Categories=Development;
MimeType=x-scheme-handler/unityhub;
EOF
update-desktop-database "$APPS" 2>/dev/null || true
xdg-mime default unityhub.desktop x-scheme-handler/unityhub 2>/dev/null || true

# ------------------------------------------------- Dossiers d'install et de DL
echo "==> Configuration des dossiers..."
mkdir -p "$EDITOR_DIR" "$DOWNLOAD_DIR" "$HUB_CONFIG"
# Pour le Hub
printf '"%s"' "$EDITOR_DIR" > "$HUB_CONFIG/secondaryInstallPath.json"
printf '{"path":"%s"}' "$DOWNLOAD_DIR" > "$HUB_CONFIG/secondaryDownloadLocation.json"
# Pour le CLI : il télécharge toujours dans ~/.config/unityhub/downloads,
# qu'on redirige vers /tmp pour ne pas remplir le home
if [ ! -L "$HUB_CONFIG/downloads" ]; then
	rm -rf "$HUB_CONFIG/downloads"
fi
ln -sfn "$DOWNLOAD_DIR" "$HUB_CONFIG/downloads"
"$UNITY_CLI" install-path --set "$EDITOR_DIR" >/dev/null
echo "    Éditeurs        : $("$UNITY_CLI" install-path --get)"
echo "    Téléchargements : $DOWNLOAD_DIR"

# ------------------------------------------------------------ Éditeur Unity
if [ "$SKIP_EDITOR" != 1 ]; then
	if [ "$UNITY_VERSION" = latest ]; then
		echo "==> Recherche de la dernière version stable de Unity..."
		# Les versions stables finissent par fN (aN = alpha, bN = bêta)
		UNITY_VERSION=$("$UNITY_CLI" releases --limit 100 --json \
			| sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' \
			| grep -E 'f[0-9]+$' | sort -V | tail -n 1)
		[ -n "$UNITY_VERSION" ] || { echo "Impossible de récupérer la liste des versions." >&2; exit 1; }
	fi

	if [ -x "$EDITOR_DIR/$UNITY_VERSION/Editor/Unity" ]; then
		echo "==> Unity $UNITY_VERSION est déjà installé."
		# Modules demandés qui ne sont pas encore "Installed"
		INSTALLED=$("$UNITY_CLI" install-modules --editor-version "$UNITY_VERSION" --list --format tsv \
			| awk -F '\t' '$4 == "Installed" {print $1}')
		MISSING=""
		for m in $UNITY_MODULES; do
			printf '%s\n' "$INSTALLED" | grep -qx "$m" || MISSING="$MISSING $m"
		done
		if [ -n "$MISSING" ]; then
			echo "==> Ajout des modules :$MISSING..."
			# shellcheck disable=SC2086 # on veut découper la liste des modules
			"$UNITY_CLI" install-modules --editor-version "$UNITY_VERSION" --module $MISSING \
				--child-modules --accept-eula || true
		elif [ -n "$UNITY_MODULES" ]; then
			echo "    Modules déjà installés : $UNITY_MODULES"
		fi
	else
		echo "==> Installation de Unity $UNITY_VERSION (plusieurs Go, ça peut être long)..."
		if [ -n "$UNITY_MODULES" ]; then
			# shellcheck disable=SC2086 # on veut découper la liste des modules
			"$UNITY_CLI" install "$UNITY_VERSION" --module $UNITY_MODULES --child-modules --accept-eula
		else
			"$UNITY_CLI" install "$UNITY_VERSION" --accept-eula
		fi
		[ -x "$EDITOR_DIR/$UNITY_VERSION/Editor/Unity" ] \
			|| { echo "L'installation de Unity a échoué." >&2; exit 1; }
	fi
fi

echo "==> Terminé !"
echo "    Ouvre un nouveau terminal puis lance : unityhub (ou unity --help pour le CLI)"
[ "$SKIP_EDITOR" = 1 ] || echo "    Unity $UNITY_VERSION : $EDITOR_DIR/$UNITY_VERSION"
