#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK (stable) for Vercel build..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git /tmp/flutter-sdk
  export PATH="/tmp/flutter-sdk/bin:$PATH"
fi

# .env est ignoré par Git mais listé dans pubspec.yaml > assets
if [ ! -f .env ]; then
  cat > .env <<EOF
API_BASE_URL=${API_BASE_URL:-https://qvgestion-backend-production.up.railway.app/api/v1}
ENVIRONMENT=${ENVIRONMENT:-prod}
EOF
fi

flutter --version
flutter pub get
flutter build web --release --no-wasm-dry-run \
  --dart-define=ENVIRONMENT="${ENVIRONMENT:-prod}" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://qvgestion-backend-production.up.railway.app/api/v1}"
cp -f vercel.json build/web/vercel.json
