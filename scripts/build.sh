#!/bin/bash
# Compila o Notchy.app em ./build e instala em /Applications.
#
#   ./scripts/build.sh               compila, instala e abre
#   ./scripts/build.sh --no-install  só compila (usado pelo release.sh)
#
# Variáveis opcionais:
#   ARCHS="arm64"        arquiteturas (padrão: arm64 e x86_64, app universal)
#   NOTCHY_SIGN=adhoc    força assinatura ad-hoc, mesmo com certificado de desenvolvedor
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Notchy.app"
ARCHS="${ARCHS:-arm64 x86_64}"
INSTALL=true
[[ "${1:-}" == "--no-install" ]] && INSTALL=false

if ! command -v swiftc >/dev/null; then
  echo "❌ Precisa das ferramentas de linha de comando da Apple. Rode: xcode-select --install"
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Compila uma vez por arquitetura e junta tudo num binário universal
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for arch in $ARCHS; do
  echo "🔨 Compilando ($arch)..."
  swiftc -O -swift-version 5 \
    -target "$arch-apple-macos14.0" \
    -module-cache-path "$TMP/cache" \
    -o "$TMP/Notchy-$arch" \
    "$ROOT"/src/*.swift \
    -framework Cocoa -framework SwiftUI -framework AVFoundation -framework ApplicationServices \
    -framework EventKit -framework IOKit -framework ServiceManagement
done
lipo -create "$TMP"/Notchy-* -output "$APP/Contents/MacOS/Notchy"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Notchy</string>
  <key>CFBundleDisplayName</key><string>Notchy</string>
  <key>CFBundleIdentifier</key><string>com.lucassteffenon.notchy</string>
  <key>CFBundleExecutable</key><string>Notchy</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>O Notchy controla o Spotify e o Música para mostrar e trocar a faixa.</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>O Notchy mostra seus próximos compromissos no notch.</string>
  <key>NSCalendarsUsageDescription</key><string>O Notchy mostra seus próximos compromissos no notch.</string>
  <key>NSCameraUsageDescription</key><string>O Notchy usa a câmera para mostrar seu reflexo no notch.</string>
</dict>
</plist>
PLIST

# Assina com o certificado de desenvolvedor (identidade estável entre builds, então o macOS
# lembra das permissões). Sem certificado, cai na assinatura ad-hoc, que muda a cada build.
IDENTITY=""
if [[ "${NOTCHY_SIGN:-}" != "adhoc" ]]; then
  IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')"
fi
codesign --force --sign "${IDENTITY:--}" "$APP"

echo "✅ Pronto: $APP"
$INSTALL || exit 0

# Instala em /Applications (ou ~/Applications, se não tiver permissão) para aparecer no Launchpad e no Spotlight
DEST="/Applications"
[[ -w "$DEST" ]] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
INSTALLED="$DEST/Notchy.app"
pkill -x Notchy 2>/dev/null || true
rm -rf "$INSTALLED"
ditto "$APP" "$INSTALLED"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALLED"
echo "📦 Instalado: $INSTALLED"
open "$INSTALLED"
