import '../app_database.dart';

class BookmarksDao {
  BookmarksDao(this._database);

  final AppDatabase _database;

  Future<void> upsertBookmark({
    required int bookmarkId,
    required int videoId,
    required double positionSeconds,
    String? caption,
    DateTime? updatedAt,
  }) {
    return _database.execute(
      '''
      INSERT OR REPLACE INTO bookmarks(bookmark_id, video_id, caption, position_seconds, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ''',
      variables: <Object?>[
        bookmarkId,
        videoId,
        caption ?? '',
        positionSeconds,
        (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
      ],
    );
  }

  Future<List<Map<String, Object?>>> readForVideo(int videoId) {
    return _database.query(
      '''
      SELECT bookmark_id, video_id, caption, position_seconds, updated_at
      FROM bookmarks
      WHERE video_id = ?
      ORDER BY position_seconds
      ''',
      variables: <Object?>[videoId],
    );
  }

  Future<Map<String, Object?>?> readById(int bookmarkId) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT bookmark_id, video_id, caption, position_seconds, updated_at
      FROM bookmarks
      WHERE bookmark_id = ?
      LIMIT 1
      ''',
      variables: <Object?>[bookmarkId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<void> deleteBookmark(int bookmarkId) {
    return _database.execute(
      'DELETE FROM bookmarks WHERE bookmark_id = ?',
      variables: <Object?>[bookmarkId],
    );
  }

  Future<bool> hasAnyBookmarks() async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT 1
      FROM bookmarks
      LIMIT 1
      ''',
    );
    return rows.isNotEmpty;
  }
}
