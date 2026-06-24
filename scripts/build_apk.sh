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

echo "==> Flutter pub get"
cd "$ROOT"
"$FLUTTER" pub get

echo "==> Build APK release (split par architecture)"
"$FLUTTER" build apk --release --split-per-abi

mkdir -p "$OUT_DIR"
APK_DIR="$ROOT/build/app/outputs/flutter-apk"
for abi in arm64-v8a armeabi-v7a x86_64; do
  src="$APK_DIR/app-${abi}-release.apk"
  if [[ -f "$src" ]]; then
    dest="$OUT_DIR/SPIRIT-LIVRAISON-v${VERSION_NAME}-${abi}.apk"
    cp "$src" "$dest"
    echo "  $dest"
  fi
done

echo ""
echo "APK prêts dans $OUT_DIR"
echo "Téléphones récents (ex. Pixel 7a) : SPIRIT-LIVRAISON-v${VERSION_NAME}-arm64-v8a.apk"
ls -lh "$OUT_DIR"/SPIRIT-LIVRAISON-v"${VERSION_NAME}"-*.apk 2>/dev/null || true
