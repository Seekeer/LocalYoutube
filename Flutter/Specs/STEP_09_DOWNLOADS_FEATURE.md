# STEP 09: Downloads Feature

## 1. What Was Implemented

1. Domain `DownloadService` and status model:
- `Flutter/lib/features/downloads/domain/download_models.dart`
  - Added unified download status model: `queued / downloading / paused / completed / failed`.
  - Added typed `DownloadItem` with DB mapping.
- `Flutter/lib/features/downloads/domain/download_service.dart`
  - Added platform-agnostic contract for download lifecycle:
    - `initialize`, `watchDownloads`, `enqueue`, `pause`, `resume`, `stop`, `deleteLocal`.

2. Android persistent background downloads (Foreground + WorkManager-compatible plugin):
- `Flutter/pubspec.yaml`
  - Added `background_downloader`.
- `Flutter/lib/features/downloads/data/background_downloader_download_service.dart`
  - Added Android implementation (`AndroidDownloadService`) based on `background_downloader`.
  - Enabled foreground execution via plugin config (`Config.runInForeground`).
  - Configured foreground notifications for running/completed/failed tasks.
  - Subscribed to status/progress stream and persisted updates into local DB.

3. Windows implementation with resume support:
- `Flutter/lib/features/downloads/data/background_downloader_download_service.dart`
  - Added `WindowsDownloadService`.
  - Implemented resume flow through `taskCanResume -> resume`, with enqueue fallback.
  - Implemented pause/stop/delete behavior with persisted task IDs.
- `Flutter/lib/features/downloads/data/download_service_factory.dart`
  - Added platform factory (`Android/Windows/Generic`) selected by `Platform`.

4. Active downloads screen with progress and stop:
- `Flutter/lib/features/downloads/presentation/downloads_controller.dart`
  - Added Riverpod `StateNotifier` for downloads stream + actions.
- `Flutter/lib/features/downloads/presentation/downloads_page.dart`
  - Replaced stub with real downloads screen:
    - task list
    - status labels
    - progress bars
    - actions: pause/resume/stop/delete/retry

5. Integration into existing architecture:
- `Flutter/lib/app/bootstrap/bootstrap_providers.dart`
  - Added `downloadServiceProvider`.
- `Flutter/lib/app/bootstrap/app_bootstrap.dart`
  - Wired download service creation and initialization in bootstrap.
- `Flutter/lib/features/catalog/data/catalog_repository.dart`
  - Switched queue/delete-local logic to `DownloadService` so downloads now start through a single domain API.
- `Flutter/lib/core/db/app_database.dart`
  - Added `task_id` field to `downloads`.
  - Added backward-compatible migration attempt (`ALTER TABLE ... ADD COLUMN task_id`).
- `Flutter/lib/core/db/daos/downloads_dao.dart`
  - Added upsert + lookup by `videoId/taskId`.
- `Flutter/lib/features/downloads/data/local_downloads_repository.dart`
  - Added typed repository methods for `DownloadItem`.

6. Tests:
- Added `Flutter/test/download_models_test.dart` for domain model/status mapping.

## 2. Step Artifact

### 2.1 Checks
- Passed:
  - `dart --suppress-analytics pub get` (using local `PUB_CACHE` inside workspace)
- Could not run in current sandbox:
  - `dart --suppress-analytics analyze lib test`
  - `dart --suppress-analytics test test/download_models_test.dart`
  - Reason: runtime crash in environment (`CreateFile failed 5`) unrelated to business logic.

### 2.2 Short changelog
- Implemented full download domain service and platform adapter layer.
- Added Android foreground/background download integration via plugin.
- Added Windows-specific resumable flow.
- Replaced placeholder downloads page with functional control UI.
- Persisted `task_id` + progress/status updates in local DB.

### 2.3 Demo scenario
1. Open Home and queue a video download (`Download` action).
2. Open `Downloads` screen.
3. Observe item status transitions and progress updates.
4. Press `Pause` or `Stop`.
5. Press `Resume` (or `Retry` for failed item).
6. After completion, verify status is `Completed` and local file path is displayed.
