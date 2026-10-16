import 'dart:convert';

import '../app_database.dart';

class VideosCacheDao {
  VideosCacheDao(this._database);

  final AppDatabase _database;

  Future<void> saveSectionItems(
    String sectionKey,
    List<Map<String, dynamic>> items,
  ) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await _database.execute('BEGIN IMMEDIATE TRANSACTION');
    try {
      await _database.execute(
        'DELETE FROM videos_cache WHERE section_key = ?',
        variables: <Object?>[sectionKey],
      );

      for (final Map<String, dynamic> item in items) {
        final int entityId = (item['id'] as num?)?.toInt() ?? item.hashCode;
        await _database.execute(
          '''
          INSERT OR REPLACE INTO videos_cache(section_key, entity_id, payload_json, updated_at)
          VALUES (?, ?, ?, ?)
          ''',
          variables: <Object?>[
            sectionKey,
            entityId,
            jsonEncode(item),
            now,
          ],
        );
      }
      await _database.execute('COMMIT');
    } catch (_) {
      try {
        await _database.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> readSectionItems(String sectionKey) async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT payload_json
      FROM videos_cache
      WHERE section_key = ?
      ORDER BY updated_at DESC
      ''',
      variables: <Object?>[sectionKey],
    );

    return rows
        .map(
          (Map<String, Object?> row) =>
              (jsonDecode((row['payload_json'] ?? '{}').toString())
                      as Map<dynamic, dynamic>)
                  .map(
            (dynamic key, dynamic value) => MapEntry('$key', value),
          ),
        )
        .toList(growable: false);
  }

  Future<bool> hasAnyItems() async {
    final List<Map<String, Object?>> rows = await _database.query(
      '''
      SELECT 1
      FROM videos_cache
      LIMIT 1
      ''',
    );
    return rows.isNotEmpty;
  }
}
