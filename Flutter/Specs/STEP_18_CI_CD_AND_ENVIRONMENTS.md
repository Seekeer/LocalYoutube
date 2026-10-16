# STEP 18: CI/CD and Environments

## 1. What Was Implemented

1. CI pipeline for Flutter quality + platform builds:
- `.github/workflows/flutter-ci.yml`
  - Added `quality` job:
    - `flutter analyze`
    - `flutter test`
  - Added `build_android` job:
    - release build path with hardening flags via CI script.
    - Android permissions audit.
  - Added `build_windows` job:
    - Windows release build path via CI script.
  - Added `strict_quality` manual job (`workflow_dispatch`) for strict gate:
    - `flutter analyze --fatal-infos --fatal-warnings`
    - `flutter test`

2. Flavor environments `dev/stage/prod` with URL/logging/feature flags:
- `Flutter/config/env/dev.json`
- `Flutter/config/env/stage.json`
- `Flutter/config/env/prod.json`
  - Added per-environment config values:
    - `LOCALTUBE_ENV`
    - `LOCALTUBE_API_BASE_URL`
    - timeout values
    - `LOCALTUBE_LOG_LEVEL`
    - feature flags:
      - `LOCALTUBE_FEATURE_NETWORK_LOGS`
      - `LOCALTUBE_FEATURE_SYNC_COMMAND_ROUTING`
      - `LOCALTUBE_FEATURE_CRASH_REPORTING`
- `Flutter/lib/core/config/app_config.dart`
  - Added `AppEnvironment` + `AppLogLevel`.
  - Added environment parsing and defaults.
  - Added feature flag parsing.
- `Flutter/lib/main_dev.dart`
- `Flutter/lib/main_stage.dart`
- `Flutter/lib/main_prod.dart`
  - Added dedicated flavor entrypoints.
- `Flutter/lib/main.dart`
  - Added shared `runLocalTubeApp(...)` runner with optional environment override.
  - Added conditional sync command listener by feature flag.
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
  - Added environment override handling for bootstrap.
  - Bound logger minimum level to config log level.
- `Flutter/lib/core/logging/log_service.dart`
  - Added minimum log level filtering.
- `Flutter/lib/core/network/dio_client.dart`
  - Added optional HTTP request/response debug logging controlled by config flag.
- `Flutter/lib/core/crash/crash_reporter.dart`
  - Added crash-reporting feature-flag gate.

3. Release hardening automation:
- `Flutter/tool/ci/flutter_quality.ps1`
  - Extended with CI options:
    - `-Flavor dev|stage|prod`
    - `-BuildAndroid`
    - `-BuildWindows`
    - `-HardenRelease`
    - `-StrictAnalyze`
  - Build commands now support:
    - flavor target entrypoint (`lib/main_<flavor>.dart`)
    - `--dart-define-from-file=config/env/<flavor>.json`
    - Android release obfuscation + split-debug-info when hardening enabled.
  - Added strict exit-code handling for all Flutter commands (pipeline now fails on command errors).
- `Flutter/tool/ci/android_release_hardening.ps1`
  - Added Android permission audit against allowlist.
  - Added hardened release-build command (obfuscate + split debug info).
  - Added `-SkipBuild` mode for audit-only runs.
  - Added optional connected-device smoke test path for integration test.
  - Added strict exit-code handling for build/test invocations.

4. Platform scaffold restoration:
- Restored full Flutter platform files for:
  - `Flutter/android/*`
  - `Flutter/windows/*`
- Aligned Android namespace/applicationId and `MainActivity` package to `org.localtube.flutter` to match manifest and existing app identity.

5. Developer documentation updates:
- `Flutter/README.md`
  - Added local build prerequisites (Android SDK / Visual Studio C++ workload).
  - Added flavor run commands.
  - Added CI script usage.
  - Added strict local quality gate command.
  - Added Android release hardening and smoke-test commands.

## 2. Step Artifact

### 2.1 Checks
- Passed:
  - `flutter test`
  - `./tool/ci/flutter_quality.ps1 -Flavor prod -SkipTest`
  - `./tool/ci/android_release_hardening.ps1 -Flavor prod -SkipBuild`
- Strict gate validation (expected failure, behavior confirmed):
  - `./tool/ci/flutter_quality.ps1 -Flavor prod -SkipTest -StrictAnalyze`
    - Fails because strict mode treats existing infos/warnings as fatal.
- Build path verification (executed, fails correctly on missing local toolchain):
  - `./tool/ci/flutter_quality.ps1 -Flavor prod -SkipTest -BuildAndroid -HardenRelease`
    - Failure reason in current machine: Android SDK not installed.
  - `./tool/ci/flutter_quality.ps1 -Flavor prod -SkipTest -BuildWindows`
    - Failure reason in current machine: suitable Visual Studio toolchain not installed.
  - `./tool/ci/android_release_hardening.ps1 -Flavor prod`
    - Failure reason in current machine: Android SDK not installed.
  - Both failures are now surfaced as non-zero exit (expected after strict exit handling fix).
- Notes:
  - Platform scaffolds are restored (`android/`, `windows/`), so build commands now run real platform toolchain checks instead of being skipped.
  - Analyzer still reports pre-existing infos/warnings (non-fatal mode in CI script by default).

### 2.2 Short changelog
- Added CI workflow for analyze/test/build flow.
- Added environment flavors `dev/stage/prod` with config files and entrypoints.
- Added runtime configuration for log level and feature flags.
- Added release hardening script (permissions audit + obfuscation path + smoke-test hooks).
- Updated README with operational commands.

### 2.3 Demo scenario
1. Run quality gate:
   - `./tool/ci/flutter_quality.ps1 -Flavor prod`
2. Build flavor locally:
   - `flutter run -t lib/main_stage.dart --dart-define-from-file=config/env/stage.json`
3. Run hardening checks:
   - `./tool/ci/android_release_hardening.ps1 -Flavor prod`
4. On a connected real Android device, run smoke path:
   - `./tool/ci/android_release_hardening.ps1 -Flavor prod -RunSmokeTests -RequireConnectedDevice`
