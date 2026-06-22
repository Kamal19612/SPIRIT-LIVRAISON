#!/usr/bin/env bash
# Build Android APK (release) for SPIRIT-LIVRAISON.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_SDK="${ANDROID_HOME:-$HOME/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64}"
FLUTTER="${FLUTTER:-flutter}"

export ANDROID_HOME="$ANDROID_SDK"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_SDK/cmdline-tools/latest/bin:$ANDROID_SDK/platform-tools:$PATH"

VERSION="$("$FLUTTER" pub run --no-sound-null-safety 2>/dev/null || true)"
VERSION_NAME="$(grep '^version:' "$ROOT/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
OUT_DIR="$ROOT/releases"
OUT_APK="$OUT_DIR/SPIRIT-LIVRAISON-v${VERSION_NAME}.apk"

echo "==> Flutter pub get"
cd "$ROOT"
"$FLUTTER" pub get

echo "==> Build APK release"
"$FLUTTER" build apk --release

mkdir -p "$OUT_DIR"
cp "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$OUT_APK"

echo ""
echo "APK prêt : $OUT_APK"
ls -lh "$OUT_APK"
