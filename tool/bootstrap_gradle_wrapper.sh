#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID="$ROOT/android"

command -v flutter >/dev/null 2>&1 || {
  echo "Flutter não encontrado. Instale o SDK definido no projeto antes de gerar o wrapper." >&2
  exit 3
}

if [[ -x "$ANDROID/gradlew" && -f "$ANDROID/gradle/wrapper/gradle-wrapper.jar" ]]; then
  echo "Gradle Wrapper já existe."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

flutter create --platforms=android --project-name al_wrapper_seed "$TMP/seed" >/dev/null
cp "$TMP/seed/android/gradlew" "$ANDROID/gradlew"
cp "$TMP/seed/android/gradlew.bat" "$ANDROID/gradlew.bat"
cp "$TMP/seed/android/gradle/wrapper/gradle-wrapper.jar" "$ANDROID/gradle/wrapper/gradle-wrapper.jar"
chmod +x "$ANDROID/gradlew"

echo "Gradle Wrapper oficial materializado a partir do SDK Flutter instalado."
