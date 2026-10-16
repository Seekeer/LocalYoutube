import '../app_database.dart';

class PlaybackPositionsDao {
  PlaybackPositionsDao(this._database);

  final AppDatabase _database;

  Future<void> savePosition({
    required int videoId,
    required double positionSeconds,
    DateTime? updatedAt,
  }) {
    return _database.execute(
      '''
      INSERT OR REPLACE INTO playback_positions(video_id, position_seconds, updated_at)
      VALUES (?, ?, ?)
      ''',
      variables: <Object?>[
        videoId,
        positionSeconds,
        (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      ],
    );
  }

  Future<double?> readPosition(int videoId) async {
    final Map<String, Object?>? row = await readPositionEntry(videoId);
    return (row?['position_seconds'] as num?)?.toDouble();
  }

  Future<Map<String, Object?>?> readPositionEntry(int videoId) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT video_id, position_seconds, updated_at
      FROM playback_positions
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

  Future<List<Map<String, Object?>>> listRecent({int limit = 50}) {
    return _database.query(
      '''
      SELECT video_id, position_seconds, updated_at
      FROM playback_positions
      ORDER BY updated_at DESC
      LIMIT ?
      ''',
      variables: <Object?>[limit],
    );
  }

  Future<bool> hasAnyPositions() async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT 1
      FROM playback_positions
      LIMIT 1
      ''',
    );
    return rows.isNotEmpty;
  }
}
