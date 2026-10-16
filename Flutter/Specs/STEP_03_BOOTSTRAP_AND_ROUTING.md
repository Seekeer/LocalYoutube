# STEP 03: Bootstrap and Routing

## 1. What Was Implemented

1. Implemented unified app bootstrap:
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
- `Flutter/lib/app/bootstrap/bootstrap_providers.dart`

Bootstrap now initializes:
- app config,
- logger service,
- secure storage service,
- app database (bootstrap placeholder),
- token repository,
- auth API,
- Dio client,
- auth/catalog repositories,
- auth notifier and router.

2. Configured navigation routes exactly as required:
- `/login`
- `/home`
- `/player/:videoId`
- `/downloads`
- `/logs`

Files:
- `Flutter/lib/app/router/app_router.dart`
- `Flutter/lib/app/router/app_routes.dart`
- `Flutter/lib/app/router/auth_notifier.dart`

3. Added auth guard and redirects:
- Unauthorized users are redirected to `/login`.
- Authorized users are redirected from `/login` to `/home`.

4. Added minimal presentation pages for route targets:
- `Flutter/lib/features/auth/presentation/login_page.dart`
- `Flutter/lib/features/home/presentation/home_page.dart`
- `Flutter/lib/features/player/presentation/player_page.dart`
- `Flutter/lib/features/downloads/presentation/downloads_page.dart`
- `Flutter/lib/features/logs/presentation/logs_page.dart`

## 2. Step Artifact

### 2.1 Tests
- Updated widget smoke test:
  - `Flutter/test/app_smoke_test.dart`
  - Verifies unauthorized startup redirects to login.

### 2.2 Short changelog
- Introduced bootstrap dependency graph with provider overrides.
- Added centralized route constants and guarded `go_router` configuration.
- Added auth state notifier for route protection.
- Added minimal screen set for all required routes.

### 2.3 Demo scenario
1. Start app without tokens -> app opens `/login`.
2. Tap `Mock Login` -> app navigates to `/home`.
3. From `/home`, open `/player/42`, `/downloads`, `/logs`.
4. Tap `Logout` on `/home` -> redirected back to `/login`.
