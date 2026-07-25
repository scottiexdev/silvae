#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
api_project="$repo_dir/src/backend/Silvae.Api/Silvae.Api.csproj"
output_dir="$repo_dir/src/mobile/silvae_api_client"
temporary_dir="$(mktemp -d)"
api_pid=""

cleanup() {
  if [[ -n "$api_pid" ]]; then
    kill "$api_pid" 2>/dev/null || true
  fi
  rm -rf "$temporary_dir"
}
trap cleanup EXIT

dotnet run --project "$api_project" \
  --no-launch-profile \
  --urls http://127.0.0.1:5089 >"$temporary_dir/api.log" 2>&1 &
api_pid="$!"

for _ in {1..30}; do
  if curl --fail --silent \
    http://127.0.0.1:5089/openapi/v1.json \
    --output "$temporary_dir/openapi.json"; then
    break
  fi
  sleep 1
done

test -s "$temporary_dir/openapi.json"
npx --yes @openapitools/openapi-generator-cli generate \
  --input-spec "$temporary_dir/openapi.json" \
  --generator-name dart-dio \
  --output "$output_dir" \
  --additional-properties=pubName=silvae_api_client,pubVersion=0.1.0
