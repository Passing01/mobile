#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK (stable) for Vercel build..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git /tmp/flutter-sdk
  export PATH="/tmp/flutter-sdk/bin:$PATH"
fi

flutter --version
flutter pub get
flutter build web --release
cp -f vercel.json build/web/vercel.json

