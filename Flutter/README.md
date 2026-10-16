# LocalTube Flutter

Universal Android client. On first launch, enter your API address, open a
`localtube-server.json` file, or scan a server QR code. Obtain the file or QR from
**Мобильное приложение** in the signed-in web interface of your LocalTube server.
Review the imported address before saving, then sign in separately in the app.
Configuration carries no account passwords or access tokens.

To change the server, sign out and choose **Настроить сервер** on the login page.
Finish or cancel pending downloads first. Each server has a separate local catalog;
changing servers clears authentication. Configuration is saved on the device.

## Development and Android build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/env/prod.json
```

Android version numbering requires a full Git checkout. GitHub Actions runs on
mobile changes or manual dispatch. Download `localtube-debug-apk` from Artifacts;
artifacts are retained for seven days. Debug signing is intended for testing.

This directory is synchronized from the primary repository. Make source changes
there; later synchronization replaces mobile source in this repository. Other
projects in this repository are preserved.
