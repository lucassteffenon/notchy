#!/bin/bash
# Instala a última versão do Notchy a partir dos releases do GitHub.
#   curl -fsSL https://raw.githubusercontent.com/lucassteffenon/notchy/main/scripts/install.sh | bash
set -euo pipefail

URL="https://github.com/lucassteffenon/notchy/releases/latest/download/Notchy.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "⬇️  Baixando o Notchy..."
curl -fL --progress-bar "$URL" -o "$TMP/Notchy.zip"
ditto -x -k "$TMP/Notchy.zip" "$TMP"

DEST="/Applications"
[[ -w "$DEST" ]] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
pkill -x Notchy 2>/dev/null || true
rm -rf "$DEST/Notchy.app"
ditto "$TMP/Notchy.app" "$DEST/Notchy.app"
# O app não é notarizado pela Apple; tira a quarentena para o macOS deixar abrir
xattr -dr com.apple.quarantine "$DEST/Notchy.app" 2>/dev/null || true

echo "✅ Notchy instalado em $DEST. Abrindo..."
open "$DEST/Notchy.app"
