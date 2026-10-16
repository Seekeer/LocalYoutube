# STEP 10: Player Feature

## 1. What Was Implemented

1. `PlayVideoUseCase` with local-first source selection and resume position:
- `Flutter/lib/features/player/domain/player_models.dart`
  - Added `PlayableVideo` and `PlayableSourceKind`.
- `Flutter/lib/features/player/domain/usecases/play_video_use_case.dart`
  - Added source resolution flow:
    - prefer existing `localPath` if file exists,
    - fallback to `remoteUrl`,
    - fallback to `/files/getFileById?fileId=:id`.
  - Added start-position restoration from `playback_positions`.

2. Player lifecycle and controls (`play/pause/seek`, background/foreground restore):
- `Flutter/lib/features/player/presentation/player_controller.dart`
  - Added `PlayerController` + `PlayerUiState` (Riverpod `StateNotifier` family).
  - Implemented playback control API: `togglePlayback`, `seek`, `seekRelative`.
  - Added lifecycle handling: save/sync on `resumed`, `inactive`, `paused`, `detached`, `hidden`.
  - Added periodic position persistence every 5 seconds.

3. Real player UI replacing stub:
- `Flutter/lib/features/player/presentation/player_page.dart`
  - Replaced placeholder text with functional screen:
    - timeline slider with seek,
    - back/forward 10s,
    - play/pause button,
    - buffering and error states,
    - source marker (`local` / `remote`).

4. Android background audio foundation (MediaSession + foreground notification path):
- `Flutter/pubspec.yaml`
  - Added `just_audio`, `just_audio_background`, `audio_service`.
- `Flutter/lib/main.dart`
  - Added `JustAudioBackground.init(...)` bootstrap on Android/iOS.
- `Flutter/android/app/src/main/AndroidManifest.xml`
  - Added permissions:
    - `FOREGROUND_SERVICE`,
    - `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
    - `WAKE_LOCK`,
    - `POST_NOTIFICATIONS`.
  - Added `AudioService` service + `MediaButtonReceiver`.

5. Wiring into existing DI/bootstrap:
- `Flutter/lib/app/bootstrap/bootstrap_providers.dart`
  - Added `playVideoUseCaseProvider`.
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
  - Wired `PlayVideoUseCase` instance into overrides.
- `Flutter/lib/features/features.dart`
  - Added exports for player domain/controller files.

6. Tests:
- `Flutter/test/play_video_use_case_test.dart`
  - Added unit tests for:
    - local file priority,
    - remote fallback when local file missing,
    - default remote URL when no download record.

## 2. Step Artifact

### 2.1 Checks
- Passed:
  - `flutter pub get`
  - `flutter test`
  - `flutter analyze --no-fatal-infos --no-fatal-warnings`
- Note:
  - `flutter analyze --fatal-infos --fatal-warnings` fails due pre-existing project warnings/infos unrelated to player step completion.

### 2.2 Short changelog
- Implemented player domain use case with offline-first source selection.
- Replaced player stub with controllable playback UI and lifecycle-aware controller.
- Added periodic and lifecycle-triggered resume-position persistence.
- Added Android background audio manifest/bootstrapping configuration.
- Added player use-case unit tests.

### 2.3 Demo scenario
1. Open Home and tap any catalog item.
2. Player starts with `local` source if downloaded file exists, otherwise `remote`.
3. Seek to a new position and pause/play.
4. Send app to background, then return to foreground.
5. Reopen the same video and verify resume starts near last saved position.
