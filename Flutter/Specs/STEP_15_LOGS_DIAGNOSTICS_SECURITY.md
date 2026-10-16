# STEP 15: Logs, Diagnostics, Security

## 1. What Was Implemented

1. `LogService` with file persistence and in-memory buffer, plus logs viewer screen:
- `Flutter/lib/core/logging/log_service.dart`
  - Added structured log entries with levels and UTC timestamps.
  - Added in-memory ring buffer (`ListQueue`) and stream updates for UI.
  - Added file persistence with startup restore and max-size truncation.
- `Flutter/lib/features/logs/presentation/logs_page.dart`
  - Added logs screen with live stream rendering, severity badges, and clear action.
  - Added file path hint for diagnostics.
- `Flutter/lib/app/router/app_router.dart`
- `Flutter/lib/features/home/presentation/home_page.dart`
  - Added `/logs` route and home screen entry point to open diagnostics logs.

2. Secret masking and token-safe logging:
- `Flutter/lib/core/logging/log_service.dart`
  - Added sanitization rules for:
    - `Authorization: Bearer ...`
    - query params (`access_token`, `refresh_token`, `password`, `secret`, `apiKey`)
    - JSON and key-value payloads containing secrets.
  - Applied sanitization to message, error, and stack trace before storing/printing.
- `Flutter/test/log_service_test.dart`
  - Added coverage for masking in info/error logs and retained memory window behavior.

3. Release crash reporting (optional endpoint-based):
- `Flutter/lib/core/crash/crash_reporter.dart`
  - Added `CrashReporter` contract and `ReleaseCrashReporter` implementation.
  - Release-only activation with optional `LOCALTUBE_CRASH_REPORT_URL`.
  - Added sanitized crash payload submission with retry/refresh disabled.
- `Flutter/lib/core/config/app_config.dart`
  - Added `crashReportUrl` config from env.
- `Flutter/lib/main.dart`
  - Added `runZonedGuarded`, `FlutterError.onError`, and `PlatformDispatcher.onError` wiring.
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
  - Added crash reporter bootstrap initialization and DI override.

4. Crash reporter tests:
- `Flutter/test/crash_reporter_test.dart`
  - Added tests for:
    - release-mode crash payload submission,
    - no submission in non-release mode,
    - `recordFlutterError(...)` reason mapping + secret masking.

## 2. Step Artifact

### 2.1 Checks
- Passed:
  - `flutter test test/log_service_test.dart test/crash_reporter_test.dart`

### 2.2 Short changelog
- Added local diagnostics stack (`LogService` + `/logs` screen).
- Added defensive log sanitization for secrets/tokens.
- Added release-only crash reporting entry points and transport.
- Added automated tests for crash reporter behavior and sanitization.

### 2.3 Demo scenario
1. Open Home and navigate to `Logs`.
2. Trigger an operation that logs warning/error (e.g., failed refresh/auth request).
3. Verify sensitive values are masked in the logs UI (`***` instead of token/password).
4. In release build with `LOCALTUBE_CRASH_REPORT_URL` configured, trigger an unhandled error.
5. Verify crash payload is sent and secrets are masked in submitted fields.
