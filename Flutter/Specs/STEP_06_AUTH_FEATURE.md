# STEP 06: Auth Feature

## 1. What Was Implemented

1. Remote data source for `login/refresh/logout`:
- `Flutter/lib/features/auth/data/auth_remote_data_source.dart`
- `Flutter/lib/core/network/auth_api.dart` extended with:
  - `login`
  - `refreshToken`
  - `logout`

2. Use case layer:
- `Flutter/lib/features/auth/domain/usecases/login_use_case.dart`
- `Flutter/lib/features/auth/domain/usecases/refresh_session_use_case.dart`
- `Flutter/lib/features/auth/domain/usecases/try_auto_login_use_case.dart`
- `Flutter/lib/features/auth/domain/usecases/logout_use_case.dart`

3. Auth repository and policy updates:
- `Flutter/lib/features/auth/data/auth_repository.dart`
  - login/refresh/tryAutoLogin/logout
  - token persistence
  - auth state updates
  - local session metadata write/cleanup

4. Login screen with validation + errors + auto-login:
- `Flutter/lib/features/auth/presentation/login_page.dart`
  - form validation for login/password
  - loading states
  - error messages
  - auto-login attempt on page open

5. Startup auto-login wiring:
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
  - `await authRepository.tryAutoLogin()` before router startup.

## 2. Step Artifact

### 2.1 Tests
- Existing smoke test remains in `Flutter/test/app_smoke_test.dart`.
- Runtime execution of `flutter test` is blocked in current environment because Flutter CLI is unavailable.

### 2.2 Short changelog
- Introduced complete auth data/use-case flow.
- Added validated login UI with explicit loading/error UX.
- Added startup auto-login behavior and logout cleanup.

### 2.3 Demo scenario
1. Start app with valid stored refresh token -> auto-login to private zone.
2. Start app without valid session -> stay on login.
3. Enter credentials and login.
4. Logout from Home -> session cleared, redirect to login.
