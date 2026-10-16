# LocalTube Flutter

Flutter client for the LocalTube media server, with Android and Windows targets.

## Configuration

Published source uses reserved example addresses. The GitHub Actions APK requires
your own API configuration to connect to a server.

Copy `config/env/prod.json` to `config/env/prod.local.json` (ignored by Git), then
set `LOCALTUBE_API_BASE_URL` to your compatible LocalTube API. Local network
routing is disabled by default. If needed, configure the LAN host and port and
the Android network security allowlist for your deployment.

```bash
flutter pub get
flutter run --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/env/prod.local.json
```

## Android build

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --debug --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/env/prod.local.json
```

Use a complete Git checkout: Android version codes are derived from commit count.
The neutral Android package is `org.localtube.app` (`.debug` for debug builds),
with matching native method channels. This build installs separately from the
original application and does not share its data or signing identity.

## GitHub Actions

`../.github/workflows/flutter-build.yml` runs analysis, tests, and an Android debug
APK build on Flutter changes or manual dispatch. Download `localtube-debug-apk`
from the completed run's Artifacts section. Artifacts are retained for seven days.
No signing secrets or deployment credentials are required for this debug build.

For release distribution, configure your own signing keystore through CI secrets.
Never commit `key.properties`, keystores, private environment overrides, or logs.
