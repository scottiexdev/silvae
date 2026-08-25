#!/usr/bin/env bash
set -euo pipefail

for name in SILVAE_API_BASE_URL SILVAE_SUPABASE_URL SILVAE_SUPABASE_ANON_KEY \
    SILVAE_ORGANIZATION_ID; do
  if [[ -z "${!name:-}" ]]; then
    echo "${name} is required for the Flutter Web release build." >&2
    exit 1
  fi
done

flutter_root="${HOME}/.cache/silvae-flutter"
if [[ ! -x "${flutter_root}/bin/flutter" ]]; then
  rm -rf "${flutter_root}"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${flutter_root}"
fi

export PATH="${flutter_root}/bin:${PATH}"
flutter config --enable-web --no-analytics

cd src/mobile/silvae_app
flutter pub get
flutter build web --release \
  --dart-define="SILVAE_API_BASE_URL=${SILVAE_API_BASE_URL}" \
  --dart-define="SILVAE_SUPABASE_URL=${SILVAE_SUPABASE_URL}" \
  --dart-define="SILVAE_SUPABASE_ANON_KEY=${SILVAE_SUPABASE_ANON_KEY}" \
  --dart-define="SILVAE_ORGANIZATION_ID=${SILVAE_ORGANIZATION_ID}"
