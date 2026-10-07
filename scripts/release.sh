#!/bin/bash
# Gera build/Notchy.zip (app universal, assinatura ad-hoc) para anexar a um release do GitHub.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOTCHY_SIGN=adhoc "$ROOT/scripts/build.sh" --no-install

ZIP="$ROOT/build/Notchy.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$ROOT/build/Notchy.app" "$ZIP"
echo "🗜️  Release: $ZIP"
