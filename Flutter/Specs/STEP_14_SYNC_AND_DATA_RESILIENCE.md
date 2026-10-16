# STEP 14: Sync and Data Resilience

## 1. What Was Implemented

1. Background `sync_outbox` processing with exponential retry:
- `Flutter/lib/features/sync/data/local_sync_outbox_repository.dart`
  - Added operation-type filtering for outbox reads.
  - Added `listPendingReady(...)` with exponential retry gating based on `attempts` and `updated_at`.
- `Flutter/lib/core/db/daos/sync_outbox_dao.dart`
  - Added pending fetch with optional operation type filter.
- `Flutter/lib/features/bookmarks/data/bookmarks_repository.dart`
  - Outbox processing now uses `listPendingReady(...)` and handles only bookmark operation types.
- `Flutter/lib/features/player/data/playback_sync_repository.dart`
  - Added playback position outbox processing (`playback_position_set`) with retry and stale-update handling.

2. Local/remote reconciliation for position and bookmarks:
- Playback position:
  - `Flutter/lib/features/player/data/playback_position_remote_data_source.dart`
    - Added `/files/getPositionMaui/:id` and `/files/setPositionMaui/:id` integration.
  - `Flutter/lib/features/player/data/playback_sync_repository.dart`
    - Added merge strategy by freshest `updatedDate`.
    - Added deterministic tie-break: higher position wins when timestamps are equal.
    - Added stale update handling when server rejects old position updates.
  - `Flutter/lib/features/player/domain/usecases/play_video_use_case.dart`
    - Start position is now resolved through reconciliation (`PlaybackSyncRepository`).
- Bookmarks:
  - `Flutter/lib/features/bookmarks/data/bookmarks_repository.dart`
    - Added `reconcileVideo(videoId)` for local/remote merge flow.
  - `Flutter/lib/features/bookmarks/domain/bookmark_models.dart`
    - Added parsing of remote update timestamps (`updatedDate`/`updatedAt`).

3. Sync triggers bound to network and app lifecycle:
- `Flutter/lib/app/sync/app_sync_coordinator.dart`
  - Added app-level coordinator with periodic sync cycle.
- `Flutter/lib/app/sync/app_sync_lifecycle_listener.dart`
  - Added connectivity and `AppLifecycleState.resumed` triggers for synchronization.
- `Flutter/lib/main.dart`
  - Wrapped app root with `AppSyncLifecycleListener`.
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
  - Registered and initialized sync coordinator and new playback sync dependencies.

## 2. Step Artifact

### 2.1 Checks
- Passed:
  - `flutter test`
- `flutter analyze`:
  - Returned project-level pre-existing warnings/infos not introduced by this step.

### 2.2 Short changelog
- Added resilient outbox retry scheduling (exponential backoff).
- Added remote playback position sync + conflict reconciliation.
- Added app-level sync orchestration triggered by network/lifecycle and periodic background cycle.
- Updated player start-position resolution to use merged local/remote state.

### 2.3 Demo scenario
1. Start playback, move timeline, then disable network.
2. Continue playback and pause (positions are saved locally, remote sync goes to outbox).
3. Re-enable network and return app to foreground.
4. Verify queued sync operations are replayed and remote position catches up.
5. Open the same video on another session/client and verify resume uses freshest merged position.
