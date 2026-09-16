#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_LINE="$(grep -E '^version: ' "$ROOT/pubspec.yaml" | head -n1)"
[[ "$VERSION_LINE" =~ ^version:\ ([0-9A-Za-z.-]+)\+([0-9]+)$ ]] || {
  echo "Versão inválida em pubspec.yaml: $VERSION_LINE" >&2
  exit 1
}
VERSION_NAME="${BASH_REMATCH[1]}"
VERSION_CODE="${BASH_REMATCH[2]}"

JSON_VERSION="$(sed -n 's/^[[:space:]]*"version": "\([^"]*\)",$/\1/p' "$ROOT/github-manager.json" | head -n1)"
JSON_ANDROID_VERSION="$(sed -n 's/^[[:space:]]*"versionName": "\([^"]*\)",$/\1/p' "$ROOT/github-manager.json" | head -n1)"
JSON_CODE="$(sed -n 's/^[[:space:]]*"versionCode": \([0-9][0-9]*\)$/\1/p' "$ROOT/github-manager.json" | head -n1)"

test "$JSON_VERSION" = "$VERSION_NAME" || { echo "github-manager.json version=$JSON_VERSION difere de $VERSION_NAME" >&2; exit 1; }
test "$JSON_ANDROID_VERSION" = "$VERSION_NAME" || { echo "github-manager.json android.versionName=$JSON_ANDROID_VERSION difere de $VERSION_NAME" >&2; exit 1; }
test "$JSON_CODE" = "$VERSION_CODE" || { echo "github-manager.json versionCode=$JSON_CODE difere de $VERSION_CODE" >&2; exit 1; }

echo "versionName=$VERSION_NAME"
echo "versionCode=$VERSION_CODE"
