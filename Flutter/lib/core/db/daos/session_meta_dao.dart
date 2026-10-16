import '../app_database.dart';

class SessionMetaDao {
  SessionMetaDao(this._database);

  final AppDatabase _database;

  Future<void> upsertValue({
    required String key,
    required String value,
  }) {
    return _database.execute(
      '''
      INSERT OR REPLACE INTO session_meta(key, value, updated_at)
      VALUES (?, ?, ?)
      ''',
      variables: <Object?>[
        key,
        value,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<String?> readValue(String key) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT value
      FROM session_meta
      WHERE key = ?
      LIMIT 1
      ''',
      variables: <Object?>[key],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value']?.toString();
  }

  Future<void> clearAll() {
    return _database.execute('DELETE FROM session_meta');
  }
}
