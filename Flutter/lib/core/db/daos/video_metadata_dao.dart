import '../app_database.dart';

class VideoMetadataDao {
  VideoMetadataDao(this._database);

  final AppDatabase _database;

  Future<void> upsert({
    required int videoId,
    required String title,
    required String description,
    int? durationSeconds,
    String? seasonName,
    int? seasonId,
    String? thumbnailLocalPath,
    DateTime? thumbnailUpdatedAt,
    DateTime? updatedAt,
  }) {
    final DateTime effectiveUpdatedAt =
        (updatedAt ?? DateTime.now().toUtc()).toUtc();
    return _database.execute(
      '''
      INSERT INTO video_metadata(
        video_id,
        title,
        description,
        duration_seconds,
        season_name,
        season_id,
        thumbnail_local_path,
        thumbnail_updated_at,
        updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(video_id) DO UPDATE SET
        title = CASE
          WHEN excluded.title != '' THEN excluded.title
          ELSE video_metadata.title
        END,
        description = CASE
          WHEN excluded.description != '' THEN excluded.description
          ELSE video_metadata.description
        END,
        duration_seconds = COALESCE(excluded.duration_seconds, video_metadata.duration_seconds),
        season_name = CASE
          WHEN excluded.season_name IS NOT NULL AND excluded.season_name != '' THEN excluded.season_name
          ELSE video_metadata.season_name
        END,
        season_id = COALESCE(excluded.season_id, video_metadata.season_id),
        thumbnail_local_path = CASE
          WHEN excluded.thumbnail_local_path IS NOT NULL AND excluded.thumbnail_local_path != '' THEN excluded.thumbnail_local_path
          ELSE video_metadata.thumbnail_local_path
        END,
        thumbnail_updated_at = COALESCE(excluded.thumbnail_updated_at, video_metadata.thumbnail_updated_at),
        updated_at = excluded.updated_at
      ''',
      variables: <Object?>[
        videoId,
        title.trim(),
        description.trim(),
        durationSeconds,
        seasonName?.trim() ?? '',
        seasonId,
        thumbnailLocalPath?.trim() ?? '',
        thumbnailUpdatedAt?.toUtc().toIso8601String(),
        effectiveUpdatedAt.toIso8601String(),
      ],
    );
  }

  Future<Map<String, Object?>?> findByVideoId(int videoId) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT video_id, title, description, duration_seconds, season_name,
             season_id, thumbnail_local_path, thumbnail_updated_at, updated_at
      FROM video_metadata
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

  Future<Map<int, String>> listThumbnailPaths() async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT video_id, thumbnail_local_path
      FROM video_metadata
      WHERE thumbnail_local_path IS NOT NULL
        AND thumbnail_local_path != ''
      ''',
    );
    final Map<int, String> thumbnailPaths = <int, String>{};
    for (final Map<String, Object?> row in rows) {
      final int? videoId = (row['video_id'] as num?)?.toInt();
      final String thumbnailPath =
          (row['thumbnail_local_path'] ?? '').toString().trim();
      if (videoId == null || videoId <= 0 || thumbnailPath.isEmpty) {
        continue;
      }
      thumbnailPaths[videoId] = thumbnailPath;
    }
    return thumbnailPaths;
  }

  Future<void> updateThumbnail({
    required int videoId,
    required String thumbnailLocalPath,
    DateTime? updatedAt,
  }) {
    final DateTime effectiveUpdatedAt =
        (updatedAt ?? DateTime.now().toUtc()).toUtc();
    return _database.execute(
      '''
      UPDATE video_metadata
      SET thumbnail_local_path = ?,
          thumbnail_updated_at = ?,
          updated_at = ?
      WHERE video_id = ?
      ''',
      variables: <Object?>[
        thumbnailLocalPath.trim(),
        effectiveUpdatedAt.toIso8601String(),
        effectiveUpdatedAt.toIso8601String(),
        videoId,
      ],
    );
  }
}
