# STEP 04: Network Layer and Failures

## 1. What Was Implemented

1. Built `DioClient` with defaults and retry wiring:
- `Flutter/lib/core/network/dio_client.dart`
- Base URL, JSON headers, connect/send/receive timeouts.

2. Implemented retry policy and idempotent retry interceptor:
- `Flutter/lib/core/network/retry_policy.dart`
- `Flutter/lib/core/network/retry_interceptor.dart`

Behavior:
- retries only idempotent requests (`GET/HEAD/PUT/DELETE/OPTIONS`) or explicit `extra.idempotent=true`;
- retries timeout/connection errors and selected server statuses (`408/429/502/503/504`);
- exponential backoff by policy;
- request retry attempts tracked via `request.extra`.

3. Implemented `AuthInterceptor`:
- `Flutter/lib/core/network/auth_interceptor.dart`

Behavior:
- injects Bearer token into requests;
- handles `401` by refresh flow;
- uses single-flight refresh (`Completer`) to prevent parallel refresh races;
- retries original request once after successful refresh;
- clears session and switches auth state to unauthenticated on refresh failure.

4. Added auth refresh API and token storage abstractions:
- `Flutter/lib/core/network/auth_api.dart`
- `Flutter/lib/core/auth/session_tokens.dart`
- `Flutter/lib/core/auth/token_repository.dart`
- `Flutter/lib/core/storage/secure_storage_service.dart`

5. Added centralized error model and mapper:
- `Flutter/lib/core/errors/failure.dart`
- `Flutter/lib/core/errors/failure_mapper.dart`

Failure types:
- `NetworkFailure`
- `AuthFailure`
- `ValidationFailure`
- `ServerFailure`
- `CancelledFailure`
- `UnknownFailure`

## 2. Step Artifact

### 2.1 Tests
- Existing widget test remains compatible with guarded router flow.
- Runtime execution of `flutter analyze` / `flutter test` is not possible in current environment until Flutter SDK is available in `PATH`.

### 2.2 Short changelog
- Added robust HTTP client setup with timeout + retry strategy.
- Added atomic token refresh flow on 401 without refresh storms.
- Standardized infrastructure error mapping to app-level `Failure` classes.
- Added initial auth and catalog repositories that use new network/failure infrastructure.

### 2.3 Demo scenario
1. Perform any authorized API request with expired access token.
2. First `401` triggers refresh once.
3. Concurrent requests wait for single refresh completion.
4. On refresh success, original requests are replayed.
5. On refresh failure, local session is cleared and router guard leads user to `/login`.
