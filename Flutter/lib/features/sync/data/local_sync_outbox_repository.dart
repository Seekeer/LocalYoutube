import '../../../core/db/daos/sync_outbox_dao.dart';

class LocalSyncOutboxRepository {
  LocalSyncOutboxRepository(this._dao);

  final SyncOutboxDao _dao;
  static const Duration _defaultInitialRetryDelay = Duration(seconds: 2);
  static const Duration _defaultMaxRetryDelay = Duration(minutes: 5);

  Future<void> enqueue({
    required String operationType,
    required String payloadJson,
  }) {
    return _dao.enqueue(
      operationType: operationType,
      payloadJson: payloadJson,
    );
  }

  Future<List<Map<String, Object?>>> listPending({
    int limit = 50,
    List<String> operationTypes = const <String>[],
  }) {
    return _dao.listPendingByOperationTypes(
      limit: limit,
      operationTypes: operationTypes,
    );
  }

  Future<List<Map<String, Object?>>> listPendingReady({
    int limit = 50,
    List<String> operationTypes = const <String>[],
    DateTime? nowUtc,
    Duration initialRetryDelay = _defaultInitialRetryDelay,
    Duration maxRetryDelay = _defaultMaxRetryDelay,
  }) async {
    final DateTime current = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final List<Map<String, Object?>> pending = await listPending(
      limit: limit,
      operationTypes: operationTypes,
    );
    return pending
        .where(
          (Map<String, Object?> row) => _isReady(
            row: row,
            nowUtc: current,
            initialRetryDelay: initialRetryDelay,
            maxRetryDelay: maxRetryDelay,
          ),
        )
        .toList(growable: false);
  }

  Future<void> markProcessed(int id) {
    return _dao.markProcessed(id);
  }

  Future<void> markFailed(int id) {
    return _dao.markFailed(id);
  }

  bool _isReady({
    required Map<String, Object?> row,
    required DateTime nowUtc,
    required Duration initialRetryDelay,
    required Duration maxRetryDelay,
  }) {
    final int attempts = _asInt(row['attempts']);
    if (attempts <= 0) {
      return true;
    }

    final DateTime? updatedAt = _asDateTime(row['updated_at']);
    if (updatedAt == null) {
      return true;
    }

    final Duration retryDelay = _retryDelayForAttempt(
      attempt: attempts,
      initialRetryDelay: initialRetryDelay,
      maxRetryDelay: maxRetryDelay,
    );
    final DateTime readyAt = updatedAt.add(retryDelay);
    return !readyAt.isAfter(nowUtc);
  }

  Duration _retryDelayForAttempt({
    required int attempt,
    required Duration initialRetryDelay,
    required Duration maxRetryDelay,
  }) {
    if (attempt <= 0) {
      return Duration.zero;
    }

    final int shift = attempt - 1;
    final int cappedShift = shift > 20 ? 20 : shift;
    final int factor = 1 << cappedShift;
    final int computedMs = initialRetryDelay.inMilliseconds * factor;
    final int clampedMs = computedMs > maxRetryDelay.inMilliseconds
        ? maxRetryDelay.inMilliseconds
        : computedMs;
    return Duration(milliseconds: clampedMs);
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _asDateTime(Object? value) {
    final String raw = (value ?? '').toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }
}
