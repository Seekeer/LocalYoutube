# STEP 12: Bookmarks Feature

## 1. What Was Implemented

1. Manual bookmarks in player (create/delete):
- `Flutter/lib/features/player/presentation/player_controller.dart`
  - Added controller actions:
    - `addManualBookmark()`
    - `deleteBookmark(int bookmarkId)`
  - Added bookmarks list in `PlayerUiState`.
- `Flutter/lib/features/player/presentation/player_page.dart`
  - Added bookmarks UI section:
    - `Add` action,
    - list of bookmarks with seek on tap,
    - delete action for each bookmark,
    - pending-sync marker for local unsent items.

2. Auto-bookmarks on short pause/resume:
- `Flutter/lib/features/player/presentation/player_controller.dart`
  - Added pause/play transition tracking.
  - Added short pause threshold (`<= 5s`) for automatic bookmark creation.
  - Auto-bookmark is created when playback resumes after a short pause.

3. Outbox-backed offline sync with retries:
- `Flutter/lib/features/bookmarks/data/bookmarks_remote_data_source.dart`
  - Added `marks/*` API calls:
    - `GET /marks/getAllMarks?fileId=...`
    - `POST /marks/add`
    - `DELETE /marks/{id}`
- `Flutter/lib/features/bookmarks/data/bookmarks_repository.dart`
  - Added local-first bookmarks flow:
    - optimistic local create,
    - enqueue failed operations into `sync_outbox`,
    - periodic retry via `processOutbox()`.
  - Added duplicate guard (no new bookmark within 5 seconds of existing mark).
- `Flutter/lib/core/db/daos/sync_outbox_dao.dart`
- `Flutter/lib/features/sync/data/local_sync_outbox_repository.dart`
  - Added `markFailed(id)` to accumulate retry attempts for unsent operations.
- `Flutter/lib/core/db/daos/bookmarks_dao.dart`
- `Flutter/lib/features/bookmarks/data/local_bookmarks_repository.dart`
  - Added read-by-id support used by outbox replay logic.

4. Bootstrap/DI wiring:
- `Flutter/lib/app/bootstrap/bootstrap_providers.dart`
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
- `Flutter/lib/features/features.dart`
  - Registered and exported new bookmarks remote/repository services.

5. Tests:
- `Flutter/test/bookmarks_repository_test.dart`
  - Added unit tests for:
    - outbox enqueue + successful retry for failed create,
    - duplicate suppression within 5-second window,
    - safe skipping of stale outbox create after local deletion.

## 2. Step Artifact

### 2.1 Checks
- Passed:
  - `dart format` for all changed Dart files.
  - `flutter test` (full project test suite including new bookmarks tests).
- Could not complete in this environment:
  - `dart analyze ...`
  - Reason: runtime failure `CreateFile failed 5` in analyzer process.
  - `flutter analyze ...` also timed out in sandbox.

### 2.2 Short changelog
- Added manual create/delete bookmarks in player UI.
- Added auto-bookmarks on short pause/resume playback cycle.
- Added offline-safe bookmarks sync with `sync_outbox` retry replay.
- Added repository-level duplicate filtering and outbox retry tests.

### 2.3 Demo scenario
1. Open any video in player and press `Add` in bookmarks section.
2. Verify bookmark appears in list and tap it to jump to saved position.
3. Pause video and resume within 5 seconds; verify auto-bookmark appears.
4. Disable network, add bookmark(s), then re-enable network.
5. Wait a few seconds and verify pending bookmarks leave `Pending sync` state.
6. Delete a bookmark from list and verify it disappears locally and stays deleted after retry cycle.
