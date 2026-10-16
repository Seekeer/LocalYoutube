import '../app_database.dart';

class DownloadsDao {
  DownloadsDao(this._database);

  final AppDatabase _database;

  Future<void> upsertDownload({
    required int videoId,
    required String status,
    required double progress,
    required String remoteUrl,
    required DateTime queuedAt,
    String? title,
    double? speedMbps,
    int? etaSeconds,
    String? taskId,
    String? localPath,
  }) {
    return _database.execute(
      '''
      INSERT INTO downloads(
        video_id,
        status,
        progress,
        title,
        task_id,
        local_path,
        remote_url,
        queued_at,
        speed_mbps,
        eta_seconds,
        updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(video_id) DO UPDATE SET
        status = excluded.status,
        progress = excluded.progress,
        title = CASE
          WHEN excluded.title IS NOT NULL AND excluded.title != '' THEN excluded.title
          ELSE downloads.title
        END,
        task_id = excluded.task_id,
        local_path = excluded.local_path,
        remote_url = excluded.remote_url,
        queued_at = CASE
          WHEN excluded.status = 'queued' THEN COALESCE(excluded.queued_at, NULLIF(downloads.queued_at, ''), excluded.updated_at)
          ELSE COALESCE(NULLIF(downloads.queued_at, ''), excluded.queued_at, excluded.updated_at)
        END,
        speed_mbps = excluded.speed_mbps,
        eta_seconds = excluded.eta_seconds,
        updated_at = excluded.updated_at
      ''',
      variables: <Object?>[
        videoId,
        status,
        progress,
        (title ?? '').trim(),
        taskId ?? '',
        localPath ?? '',
        remoteUrl,
        queuedAt.toUtc().toIso8601String(),
        speedMbps,
        etaSeconds,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<List<Map<String, Object?>>> listAll() {
    return _database.query(
      '''
      SELECT video_id, status, progress, title, task_id, local_path, remote_url,
             queued_at, speed_mbps, eta_seconds, updated_at
      FROM downloads
      ORDER BY COALESCE(NULLIF(queued_at, ''), updated_at) DESC, updated_at DESC
      ''',
    );
  }

  Future<Map<String, Object?>?> findByVideoId(int videoId) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT video_id, status, progress, title, task_id, local_path, remote_url,
             queued_at, speed_mbps, eta_seconds, updated_at
      FROM downloads
      WHERE video_id = ?
      LIMIT 1
      ''',
      variables: <Object?>[videoId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<Map<String, Object?>?> findByTaskId(String taskId) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT video_id, status, progress, title, task_id, local_path, remote_url,
             queued_at, speed_mbps, eta_seconds, updated_at
      FROM downloads
      WHERE task_id = ?
      LIMIT 1
      ''',
      variables: <Object?>[taskId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<void> deleteByVideoId(int videoId) {
    return _database.execute(
      'DELETE FROM downloads WHERE video_id = ?',
      variables: <Object?>[videoId],
    );
  }

  Future<bool> hasAnyDownloads() async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT 1
      FROM downloads
      LIMIT 1
      ''',
    );
    return rows.isNotEmpty;
  }
}
