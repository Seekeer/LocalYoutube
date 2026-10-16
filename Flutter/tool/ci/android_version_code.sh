#!/usr/bin/env bash
# Run from Flutter, after pub get. Keep the ordering policy in Gradle alone.
set -euo pipefail
# Flutter generates the ignored Gradle wrapper and local.properties on clean checkouts.
flutter build apk --config-only --no-pub >&2
bash android/gradlew -p android -q :app:writeUpdateVersionCode >&2
cat build/app-update-version-code.txt
