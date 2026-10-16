import '../app_database.dart';

class SyncOutboxDao {
  SyncOutboxDao(this._database);

  final AppDatabase _database;

  Future<void> enqueue({
    required String operationType,
    required String payloadJson,
  }) {
    return _database.execute(
      '''
      INSERT INTO sync_outbox(operation_type, payload_json, status, attempts, updated_at)
      VALUES (?, ?, 'pending', 0, ?)
      ''',
      variables: <Object?>[
        operationType,
        payloadJson,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<List<Map<String, Object?>>> listPending({int limit = 50}) {
    return listPendingByOperationTypes(limit: limit);
  }

  Future<List<Map<String, Object?>>> listPendingByOperationTypes({
    int limit = 50,
    List<String> operationTypes = const <String>[],
  }) {
    final StringBuffer sql = StringBuffer(
      '''
      SELECT id, operation_type, payload_json, status, attempts, updated_at
      FROM sync_outbox
      WHERE status = 'pending'
      ''',
    );
    final List<Object?> variables = <Object?>[];
    if (operationTypes.isNotEmpty) {
      final String placeholders = List<String>.filled(
        operationTypes.length,
        '?',
      ).join(', ');
      sql.write(' AND operation_type IN ($placeholders)');
      variables.addAll(operationTypes);
    }
    sql.write(' ORDER BY id LIMIT ?');
    variables.add(limit);
    return _database.query(
      sql.toString(),
      variables: variables,
    );
  }

  Future<void> markProcessed(int id) {
    return _database.execute(
      '''
      UPDATE sync_outbox
      SET status = 'processed', updated_at = ?
      WHERE id = ?
      ''',
      variables: <Object?>[
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  Future<void> markFailed(int id) {
    return _database.execute(
      '''
      UPDATE sync_outbox
      SET attempts = attempts + 1, updated_at = ?
      WHERE id = ?
      ''',
      variables: <Object?>[
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }
}
