# STEP 11: Timestamps and Quick Jumps

## 1. What Was Implemented

1. Timestamp parsing use case from description:
- `Flutter/lib/features/player/domain/player_models.dart`
  - Added `VideoTimestamp` model.
- `Flutter/lib/features/player/domain/usecases/extract_timestamps_use_case.dart`
  - Added `ExtractTimestampsUseCase`:
    - supports `mm:ss` and `hh:mm:ss`,
    - extracts labels from description text,
    - deduplicates timestamp positions,
    - builds fallback labels when text is absent.

2. Jump to nearest next timestamp:
- `Flutter/lib/features/player/domain/usecases/jump_to_nearest_timestamp_use_case.dart`
  - Added `JumpToNearestTimestampUseCase`:
    - sorts timestamps by position,
    - returns the first timestamp strictly after current playback position.

3. Player UI for timestamps and quick transitions:
- `Flutter/lib/features/home/presentation/home_page.dart`
  - Passes `title/description` to player route through `extra`.
- `Flutter/lib/app/router/app_router.dart`
  - Reads player route `extra` and injects data into `PlayerPage`.
- `Flutter/lib/features/player/presentation/player_page.dart`
  - Added timestamp list section built from description.
  - Added per-item seek on tap.
  - Added `Next` action using `JumpToNearestTimestampUseCase`.
  - Added dynamic page title fallback (`videoTitle` -> `Player #id`).

4. DI/bootstrap wiring:
- `Flutter/lib/app/bootstrap/bootstrap_providers.dart`
  - Added providers for new timestamp use cases.
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
  - Added use case construction and provider overrides.
- `Flutter/lib/features/features.dart`
  - Added exports for new use cases.

5. Tests:
- `Flutter/test/timestamp_use_cases_test.dart`
  - Added unit tests for parser and nearest-jump behavior.

## 2. Step Artifact

### 2.1 Checks
- Passed:
  - `dart format lib/app/bootstrap/app_bootstrap.dart lib/app/bootstrap/bootstrap_providers.dart lib/app/router/app_router.dart lib/features/features.dart lib/features/home/presentation/home_page.dart lib/features/player/domain/player_models.dart lib/features/player/domain/usecases/extract_timestamps_use_case.dart lib/features/player/domain/usecases/jump_to_nearest_timestamp_use_case.dart lib/features/player/presentation/player_page.dart test/timestamp_use_cases_test.dart`
  - `flutter test`
  - `flutter analyze lib/app/bootstrap lib/app/router lib/features/home/presentation/home_page.dart lib/features/player test/timestamp_use_cases_test.dart --no-fatal-infos --no-fatal-warnings`
- Note:
  - `flutter analyze` reports 8 existing info-level warnings in `home_page.dart` (deprecated API / `use_build_context_synchronously`), unrelated to step 11 logic and unchanged by this step.

### 2.2 Short changelog
- Added parser for chapter timestamps in video descriptions.
- Added nearest-next timestamp jump logic.
- Added timestamp UI controls in player with direct seeks.
- Added unit tests for both timestamp use cases.

### 2.3 Demo scenario
1. Open Home and tap any catalog item with description timestamps like `00:00 Intro`, `05:10 Topic`.
2. In Player, verify timestamp list appears below controls.
3. Tap any timestamp in the list and verify seek to selected position.
4. Press `Next` and verify jump to the nearest next timestamp relative to current position.
