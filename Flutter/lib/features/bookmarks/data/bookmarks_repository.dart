import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/logging/log_service.dart';
import '../../sync/data/local_sync_outbox_repository.dart';
import '../domain/bookmark_models.dart';
import 'bookmarks_remote_data_source.dart';
import 'local_bookmarks_repository.dart';

class BookmarksRepository {
  BookmarksRepository({
    required BookmarksRemoteDataSource remoteDataSource,
    required LocalBookmarksRepository localBookmarksRepository,
    required LocalSyncOutboxRepository localSyncOutboxRepository,
    required LogService logService,
  })  : _remoteDataSource = remoteDataSource,
        _localBookmarksRepository = localBookmarksRepository,
        _localSyncOutboxRepository = localSyncOutboxRepository,
        _logService = logService;

  static const String _operationAdd = 'bookmark_add';
  static const String _operationDelete = 'bookmark_delete';
  static const Duration _duplicateWindow = Duration(seconds: 5);
  static const List<String> _outboxOperationTypes = <String>[
    _operationAdd,
    _operationDelete,
  ];

  final BookmarksRemoteDataSource _remoteDataSource;
  final LocalBookmarksRepository _localBookmarksRepository;
  final LocalSyncOutboxRepository _localSyncOutboxRepository;
  final LogService _logService;

  int _nextLocalBookmarkId = -DateTime.now().microsecondsSinceEpoch;
  bool _isProcessingOutbox = false;

  Future<List<BookmarkItem>> loadForVideo(int videoId) async {
    await reconcileVideo(videoId);
    await processOutbox();
    return listLocalForVideo(videoId);
  }

  Future<List<BookmarkItem>> listLocalForVideo(int videoId) async {
    final List<Map<String, Object?>> rows =
        await _localBookmarksRepository.listForVideo(videoId);
    return rows.map(BookmarkItem.fromLocalRow).toList(growable: false);
  }

  Future<bool> addBookmark({
    required int videoId,
    required double positionSeconds,
    required String caption,
  }) async {
    final double normalizedPosition =
        positionSeconds.clamp(0, double.infinity).toDouble();
    final List<BookmarkItem> existing = await listLocalForVideo(videoId);
    if (_hasNearbyBookmark(existing, normalizedPosition)) {
      return false;
    }

    final int localBookmarkId = _allocateLocalBookmarkId();
    final DateTime now = DateTime.now().toUtc();

    await _localBookmarksRepository.upsertBookmark(
      bookmarkId: localBookmarkId,
      videoId: videoId,
      positionSeconds: normalizedPosition,
      caption: caption,
      updatedAt: now,
    );

    try {
      final int remoteId = await _remoteDataSource.add(
        videoId: videoId,
        positionSeconds: normalizedPosition,
        caption: caption,
      );
      if (remoteId <= 0) {
        throw const FormatException('Remote bookmark id must be positive');
      }
      await _replaceLocalBookmarkId(
        localBookmarkId: localBookmarkId,
        remoteBookmarkId: remoteId,
        videoId: videoId,
        positionSeconds: normalizedPosition,
        caption: caption,
      );
    } catch (error, stackTrace) {
      _logService.error('addBookmark remote call failed', error, stackTrace);
      await _localSyncOutboxRepository.enqueue(
        operationType: _operationAdd,
        payloadJson: jsonEncode(
          <String, Object?>{
            'localBookmarkId': localBookmarkId,
            'videoId': videoId,
            'positionSeconds': normalizedPosition,
            'caption': caption,
          },
        ),
      );
    }

    return true;
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    await _localBookmarksRepository.deleteBookmark(bookmarkId);

    if (bookmarkId <= 0) {
      return;
    }

    try {
      await _remoteDataSource.delete(bookmarkId);
    } catch (error, stackTrace) {
      _logService.error('deleteBookmark remote call failed', error, stackTrace);
      await _localSyncOutboxRepository.enqueue(
        operationType: _operationDelete,
        payloadJson: jsonEncode(
          <String, Object?>{
            'bookmarkId': bookmarkId,
          },
        ),
      );
    }
  }

  Future<void> processOutbox() async {
    if (_isProcessingOutbox) {
      return;
    }

    _isProcessingOutbox = true;
    try {
      final List<Map<String, Object?>> pending =
          await _localSyncOutboxRepository.listPendingReady(
        limit: 100,
        operationTypes: _outboxOperationTypes,
      );
      for (final Map<String, Object?> row in pending) {
        final int outboxId = _asInt(row['id']);
        final String operationType = (row['operation_type'] ?? '').toString();
        final String payloadJson = (row['payload_json'] ?? '{}').toString();

        if (outboxId <= 0) {
          continue;
        }

        Map<String, dynamic> payload;
        try {
          final dynamic decoded = jsonDecode(payloadJson);
          if (decoded is! Map) {
            throw const FormatException('payload must be json object');
          }
          payload = decoded.map(
            (dynamic key, dynamic value) => MapEntry('$key', value),
          );
        } catch (error, stackTrace) {
          _logService.error(
            'processOutbox payload decode failed',
            error,
            stackTrace,
          );
          await _localSyncOutboxRepository.markProcessed(outboxId);
          continue;
        }

        try {
          switch (operationType) {
            case _operationAdd:
              await _processAddOperation(payload);
              break;
            case _operationDelete:
              await _processDeleteOperation(payload);
              break;
            default:
              _logService.warn('Unknown outbox operation: $operationType');
              continue;
          }
          await _localSyncOutboxRepository.markProcessed(outboxId);
        } catch (error, stackTrace) {
          if (_isNotFound(error)) {
            await _localSyncOutboxRepository.markProcessed(outboxId);
            continue;
          }
          _logService.error(
              'processOutbox operation failed', error, stackTrace);
          await _localSyncOutboxRepository.markFailed(outboxId);
        }
      }
    } finally {
      _isProcessingOutbox = false;
    }
  }

  Future<void> reconcileVideo(int videoId) async {
    try {
      final List<BookmarkItem> localItems = await listLocalForVideo(videoId);
      final Map<int, BookmarkItem> localById = <int, BookmarkItem>{
        for (final BookmarkItem item in localItems)
          if (item.id > 0) item.id: item,
      };

      final List<Map<String, dynamic>> remoteRows =
          await _remoteDataSource.getAllForVideo(videoId);
      final Map<int, BookmarkItem> remoteById = <int, BookmarkItem>{};
      for (final Map<String, dynamic> row in remoteRows) {
        final BookmarkItem remoteItem = BookmarkItem.fromRemoteJson(row);
        if (remoteItem.id <= 0 || remoteItem.videoId != videoId) {
          continue;
        }
        remoteById[remoteItem.id] = remoteItem;
      }

      for (final MapEntry<int, BookmarkItem> remoteEntry
          in remoteById.entries) {
        final BookmarkItem remoteItem = remoteEntry.value;
        final BookmarkItem? localItem = localById[remoteEntry.key];
        final BookmarkItem winner = localItem == null
            ? remoteItem
            : _pickBookmarkWinner(
                local: localItem,
                remote: remoteItem,
              );
        if (winner == remoteItem) {
          await _localBookmarksRepository.upsertBookmark(
            bookmarkId: remoteItem.id,
            videoId: remoteItem.videoId,
            positionSeconds: remoteItem.positionSeconds,
            caption: remoteItem.caption,
            updatedAt: remoteItem.updatedAt,
          );
        }
      }

      // Positive local ids absent on server are treated as remotely deleted.
      for (final BookmarkItem localItem in localById.values) {
        if (!remoteById.containsKey(localItem.id)) {
          await _localBookmarksRepository.deleteBookmark(localItem.id);
        }
      }
    } catch (error, stackTrace) {
      _logService.error('reconcileVideo failed', error, stackTrace);
    }
  }

  Future<void> _processAddOperation(Map<String, dynamic> payload) async {
    final int localBookmarkId = _asInt(payload['localBookmarkId']);
    final int videoId = _asInt(payload['videoId']);
    final double positionSeconds = _asDouble(payload['positionSeconds']);
    final String caption = (payload['caption'] ?? 'Bookmark').toString();

    final Map<String, Object?>? localRow =
        await _localBookmarksRepository.findById(localBookmarkId);
    if (localRow == null) {
      return;
    }

    final int remoteId = await _remoteDataSource.add(
      videoId: videoId,
      positionSeconds: positionSeconds,
      caption: caption,
    );
    if (remoteId <= 0) {
      throw const FormatException('Remote bookmark id must be positive');
    }

    await _replaceLocalBookmarkId(
      localBookmarkId: localBookmarkId,
      remoteBookmarkId: remoteId,
      videoId: videoId,
      positionSeconds: positionSeconds,
      caption: caption,
    );
  }

  Future<void> _processDeleteOperation(Map<String, dynamic> payload) async {
    final int bookmarkId = _asInt(payload['bookmarkId']);
    if (bookmarkId <= 0) {
      return;
    }
    await _remoteDataSource.delete(bookmarkId);
  }

  Future<void> _replaceLocalBookmarkId({
    required int localBookmarkId,
    required int remoteBookmarkId,
    required int videoId,
    required double positionSeconds,
    required String caption,
  }) async {
    await _localBookmarksRepository.deleteBookmark(localBookmarkId);
    await _localBookmarksRepository.upsertBookmark(
      bookmarkId: remoteBookmarkId,
      videoId: videoId,
      positionSeconds: positionSeconds,
      caption: caption,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  bool _hasNearbyBookmark(List<BookmarkItem> items, double positionSeconds) {
    for (final BookmarkItem item in items) {
      final double delta = (item.positionSeconds - positionSeconds).abs();
      if (delta <= _duplicateWindow.inSeconds) {
        return true;
      }
    }
    return false;
  }

  BookmarkItem _pickBookmarkWinner({
    required BookmarkItem local,
    required BookmarkItem remote,
  }) {
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return remote;
    }
    if (local.updatedAt.isAfter(remote.updatedAt)) {
      return local;
    }
    return remote.positionSeconds >= local.positionSeconds ? remote : local;
  }

  int _allocateLocalBookmarkId() {
    _nextLocalBookmarkId--;
    return _nextLocalBookmarkId;
  }

  bool _isNotFound(Object error) {
    return error is DioException && error.response?.statusCode == 404;
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

  double _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
