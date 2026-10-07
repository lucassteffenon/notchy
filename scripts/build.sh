#!/bin/bash
# Compila o Notchy.app em ./build
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Notchy.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

swiftc -O -swift-version 5 \
  -target "$(uname -m)-apple-macos14.0" \
  -o "$APP/Contents/MacOS/Notchy" \
  "$ROOT"/src/*.swift \
  -framework Cocoa -framework SwiftUI -framework AVFoundation -framework ApplicationServices \
  -framework EventKit -framework IOKit -framework ServiceManagement

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
IDENTITY="$(security find-identity -p codesigning -v | awk -F'"' '/Apple Development/ {print $2; exit}')"
codesign --force --sign "${IDENTITY:--}" "$APP"

echo "✅ Pronto: $APP"

# Instala em /Applications para aparecer no Launchpad e no Spotlight
INSTALLED="/Applications/Notchy.app"
pkill -x Notchy 2>/dev/null || true
rm -rf "$INSTALLED"
ditto "$APP" "$INSTALLED"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALLED"
echo "📦 Instalado: $INSTALLED"
