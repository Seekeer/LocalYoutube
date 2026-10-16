import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/logging/log_service.dart';
import '../../sync/data/local_sync_outbox_repository.dart';
import 'local_playback_repository.dart';
import 'playback_position_remote_data_source.dart';

class PlaybackSyncRepository {
  PlaybackSyncRepository({
    required LocalPlaybackRepository localPlaybackRepository,
    required PlaybackPositionRemoteDataSource remoteDataSource,
    required LocalSyncOutboxRepository localSyncOutboxRepository,
    required LogService logService,
    Duration remoteReadCooldown = const Duration(seconds: 30),
    Duration staleReconcileDelay = const Duration(seconds: 5),
    DateTime Function()? nowProvider,
    bool Function()? isProgressWrittenElsewhere,
  })  : _localPlaybackRepository = localPlaybackRepository,
        _remoteDataSource = remoteDataSource,
        _localSyncOutboxRepository = localSyncOutboxRepository,
        _logService = logService,
        _remoteReadCooldown = remoteReadCooldown,
        _staleReconcileDelay = staleReconcileDelay,
        _nowProvider = nowProvider ?? _defaultNowUtc,
        _isProgressWrittenElsewhere =
            isProgressWrittenElsewhere ?? _progressIsNeverWrittenElsewhere;

  static const String _operationSetPosition = 'playback_position_set';
  static const List<String> _outboxOperationTypes = <String>[
    _operationSetPosition,
  ];

  final LocalPlaybackRepository _localPlaybackRepository;
  final PlaybackPositionRemoteDataSource _remoteDataSource;
  final LocalSyncOutboxRepository _localSyncOutboxRepository;
  final LogService _logService;
  final Duration _remoteReadCooldown;
  final Duration _staleReconcileDelay;
  final DateTime Function() _nowProvider;

  /// Whether playback progress is another device's to write right now.
  ///
  /// During a Cast Session the Receiver is the device that is playing, and the progress kept for
  /// the video is the one it reports through this very path. Defaults to never, which is what a
  /// device that is casting nowhere is.
  final bool Function() _isProgressWrittenElsewhere;
  bool _isProcessingOutbox = false;
  bool _isRunningScheduledReconciles = false;
  final Map<int, DateTime> _lastRemoteReadAtByVideo = <int, DateTime>{};
  final Map<int, DateTime> _scheduledReconcileAtByVideo = <int, DateTime>{};

  Future<void> savePosition({
    required int videoId,
    required double positionSeconds,
    DateTime? updatedAt,
    bool syncRemote = true,
  }) async {
    if (_isProgressWrittenElsewhere()) {
      // Another device is the one playing, and its progress is the progress this video has. That
      // is a Cast Session seen from the phone: the Receiver plays the video and writes what it is
      // doing on this same path, while all this device has is where the viewer was when the
      // Receiver took over. Written from here it would carry a fresh timestamp and overwrite the
      // Receiver's real position with a stale one - on the server, and locally where the next
      // reconcile would carry it there anyway. So nothing is written at all.
      return;
    }

    final DateTime effectiveUpdatedAt =
        (updatedAt ?? DateTime.now().toUtc()).toUtc();
    final double normalizedPosition = _normalizePosition(positionSeconds);

    await _localPlaybackRepository.savePosition(
      videoId: videoId,
      positionSeconds: normalizedPosition,
      updatedAt: effectiveUpdatedAt,
    );

    if (!syncRemote) {
      return;
    }
    await _pushToRemote(
      videoId: videoId,
      positionSeconds: normalizedPosition,
      updatedAt: effectiveUpdatedAt,
      enqueueOnFailure: true,
    );
  }

  Future<Duration> resolveStartPosition(
    int videoId, {
    bool localOnly = false,
  }) async {
    final PlaybackPositionSnapshot? merged = localOnly
        ? await _localPlaybackRepository.getSnapshot(videoId)
        : await reconcileVideo(videoId);
    if (merged == null) {
      return Duration.zero;
    }
    return Duration(milliseconds: (merged.positionSeconds * 1000).round());
  }

  Future<PlaybackPositionSnapshot?> reconcileVideo(int videoId) async {
    await _runDueScheduledReconciles();
    return _reconcileVideo(videoId: videoId);
  }

  Future<PlaybackPositionSnapshot?> _reconcileVideo({
    required int videoId,
  }) async {
    if (videoId <= 0) {
      return null;
    }

    final PlaybackPositionSnapshot? local =
        await _localPlaybackRepository.getSnapshot(videoId);

    final _RemoteReadResult remoteRead = await _readRemotePosition(videoId);
    final RemotePlaybackPosition? remote = remoteRead.position;
    if (remoteRead.skippedByCooldown && remoteRead.nextAllowedReadAt != null) {
      _scheduleReconcileAt(videoId, remoteRead.nextAllowedReadAt!);
    }

    final PlaybackPositionSnapshot? merged = _mergeSnapshots(
      videoId: videoId,
      local: local,
      remote: remote,
    );
    if (merged == null) {
      return null;
    }

    if (!_sameSnapshot(local, merged)) {
      await _localPlaybackRepository.savePosition(
        videoId: videoId,
        positionSeconds: merged.positionSeconds,
        updatedAt: merged.updatedAt,
      );
    }

    if (_shouldPushRemote(
      local: local,
      remote: remote,
      merged: merged,
      canUseRemoteForPushDecision: remoteRead.canUseForPushDecision,
    )) {
      await _pushToRemote(
        videoId: videoId,
        positionSeconds: merged.positionSeconds,
        updatedAt: merged.updatedAt,
        enqueueOnFailure: true,
      );
    }

    return merged;
  }

  Future<void> reconcileRecent({int limit = 20}) async {
    await _runDueScheduledReconciles();
    final List<PlaybackPositionSnapshot> recent =
        await _localPlaybackRepository.listRecent(limit: limit);
    for (final PlaybackPositionSnapshot item in recent) {
      if (item.videoId <= 0) {
        continue;
      }
      await _reconcileVideo(videoId: item.videoId);
    }
  }

  Future<void> processOutbox() async {
    if (_isProcessingOutbox) {
      return;
    }

    _isProcessingOutbox = true;
    try {
      await _runDueScheduledReconciles();
      final List<Map<String, Object?>> pending =
          await _localSyncOutboxRepository.listPendingReady(
        limit: 100,
        operationTypes: _outboxOperationTypes,
      );
      final Map<int, _OutboxCandidate> latestByVideoId =
          <int, _OutboxCandidate>{};
      final Set<int> supersededOutboxIds = <int>{};
      for (final Map<String, Object?> row in pending) {
        final _OutboxCandidate? candidate = _parseOutboxCandidate(row);
        if (candidate == null) {
          final int outboxId = _asInt(row['id']);
          if (outboxId > 0) {
            await _localSyncOutboxRepository.markProcessed(outboxId);
          }
          continue;
        }

        final _OutboxCandidate? existing = latestByVideoId[candidate.videoId];
        if (existing != null) {
          supersededOutboxIds.add(existing.outboxId);
        }
        latestByVideoId[candidate.videoId] = candidate;
      }

      for (final int supersededOutboxId in supersededOutboxIds) {
        await _localSyncOutboxRepository.markProcessed(supersededOutboxId);
      }

      final List<_OutboxCandidate> deduped = latestByVideoId.values.toList()
        ..sort(
          (_OutboxCandidate a, _OutboxCandidate b) =>
              a.outboxId.compareTo(b.outboxId),
        );
      for (final _OutboxCandidate candidate in deduped) {
        final int outboxId = candidate.outboxId;

        try {
          final bool accepted = await _remoteDataSource.setPosition(
            videoId: candidate.videoId,
            positionSeconds: candidate.positionSeconds,
            updatedAt: candidate.updatedAt,
          );
          await _localSyncOutboxRepository.markProcessed(outboxId);
          if (!accepted) {
            _scheduleDelayedReconcile(candidate.videoId);
          }
        } catch (error, stackTrace) {
          if (_isNotFound(error)) {
            await _localSyncOutboxRepository.markProcessed(outboxId);
            continue;
          }
          _logService.error(
            'processOutbox playback operation failed',
            error,
            stackTrace,
          );
          await _localSyncOutboxRepository.markFailed(outboxId);
        }
      }

      await _runDueScheduledReconciles();
    } finally {
      _isProcessingOutbox = false;
    }
  }

  Future<void> _pushToRemote({
    required int videoId,
    required double positionSeconds,
    required DateTime updatedAt,
    required bool enqueueOnFailure,
  }) async {
    try {
      final bool accepted = await _remoteDataSource.setPosition(
        videoId: videoId,
        positionSeconds: positionSeconds,
        updatedAt: updatedAt,
      );
      if (accepted) {
        return;
      }

      _scheduleDelayedReconcile(videoId);
    } catch (error, stackTrace) {
      _logService.error('pushToRemote failed', error, stackTrace);
      if (!enqueueOnFailure) {
        return;
      }
      await _localSyncOutboxRepository.enqueue(
        operationType: _operationSetPosition,
        payloadJson: jsonEncode(
          <String, Object?>{
            'videoId': videoId,
            'positionSeconds': _normalizePosition(positionSeconds),
            'updatedDate': updatedAt.toUtc().toIso8601String(),
          },
        ),
      );
    }
  }

  PlaybackPositionSnapshot? _mergeSnapshots({
    required int videoId,
    required PlaybackPositionSnapshot? local,
    required RemotePlaybackPosition? remote,
  }) {
    final PlaybackPositionSnapshot? localSnapshot = local == null
        ? null
        : PlaybackPositionSnapshot(
            videoId: videoId,
            positionSeconds: _normalizePosition(local.positionSeconds),
            updatedAt: local.updatedAt.toUtc(),
          );
    final PlaybackPositionSnapshot? remoteSnapshot = remote == null
        ? null
        : PlaybackPositionSnapshot(
            videoId: videoId,
            positionSeconds: _normalizePosition(remote.positionSeconds),
            updatedAt: remote.updatedAt.toUtc(),
          );

    if (localSnapshot == null && remoteSnapshot == null) {
      return null;
    }
    if (localSnapshot == null) {
      return remoteSnapshot;
    }
    if (remoteSnapshot == null) {
      return localSnapshot;
    }
    if (localSnapshot.updatedAt.isAfter(remoteSnapshot.updatedAt)) {
      return localSnapshot;
    }
    if (remoteSnapshot.updatedAt.isAfter(localSnapshot.updatedAt)) {
      return remoteSnapshot;
    }
    return localSnapshot.positionSeconds >= remoteSnapshot.positionSeconds
        ? localSnapshot
        : remoteSnapshot;
  }

  bool _shouldPushRemote({
    required PlaybackPositionSnapshot? local,
    required RemotePlaybackPosition? remote,
    required PlaybackPositionSnapshot merged,
    required bool canUseRemoteForPushDecision,
  }) {
    if (local == null) {
      return false;
    }
    if (!_sameSnapshot(local, merged)) {
      return false;
    }
    if (!canUseRemoteForPushDecision) {
      return false;
    }
    if (remote == null) {
      return true;
    }
    if (merged.updatedAt.isAfter(remote.updatedAt)) {
      return true;
    }
    if (merged.updatedAt.isAtSameMomentAs(remote.updatedAt) &&
        merged.positionSeconds > remote.positionSeconds) {
      return true;
    }
    return false;
  }

  bool _sameSnapshot(
    PlaybackPositionSnapshot? a,
    PlaybackPositionSnapshot? b,
  ) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.videoId == b.videoId &&
        a.updatedAt.isAtSameMomentAs(b.updatedAt) &&
        (a.positionSeconds - b.positionSeconds).abs() < 0.001;
  }

  bool _isNotFound(Object error) {
    return error is DioException && error.response?.statusCode == 404;
  }

  _OutboxCandidate? _parseOutboxCandidate(Map<String, Object?> row) {
    final int outboxId = _asInt(row['id']);
    if (outboxId <= 0) {
      return null;
    }

    final String payloadJson = (row['payload_json'] ?? '{}').toString();
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
        'processOutbox playback payload decode failed',
        error,
        stackTrace,
      );
      return null;
    }

    final int videoId = _asInt(payload['videoId']);
    if (videoId <= 0) {
      return null;
    }

    return _OutboxCandidate(
      outboxId: outboxId,
      videoId: videoId,
      positionSeconds: _asDouble(payload['positionSeconds']),
      updatedAt: _asDateTime(payload['updatedDate']),
    );
  }

  void _scheduleDelayedReconcile(int videoId) {
    if (videoId <= 0) {
      return;
    }

    final DateTime scheduledAt = _nowUtc().add(_staleReconcileDelay);
    _scheduleReconcileAt(videoId, scheduledAt);
  }

  void _scheduleReconcileAt(int videoId, DateTime scheduledAt) {
    if (videoId <= 0) {
      return;
    }

    final DateTime normalized = scheduledAt.toUtc();
    final DateTime? existing = _scheduledReconcileAtByVideo[videoId];
    if (existing == null || normalized.isBefore(existing)) {
      _scheduledReconcileAtByVideo[videoId] = normalized;
    }
  }

  Future<void> _runDueScheduledReconciles() async {
    if (_isRunningScheduledReconciles) {
      return;
    }

    _isRunningScheduledReconciles = true;
    try {
      while (true) {
        final DateTime now = _nowUtc();
        final List<int> dueVideoIds = _scheduledReconcileAtByVideo.entries
            .where(
              (MapEntry<int, DateTime> entry) => !entry.value.isAfter(now),
            )
            .map((MapEntry<int, DateTime> entry) => entry.key)
            .toList(growable: false);
        if (dueVideoIds.isEmpty) {
          return;
        }

        for (final int videoId in dueVideoIds) {
          final DateTime? scheduledAt = _scheduledReconcileAtByVideo[videoId];
          if (scheduledAt == null || scheduledAt.isAfter(_nowUtc())) {
            continue;
          }
          _scheduledReconcileAtByVideo.remove(videoId);
          await _reconcileVideo(videoId: videoId);
        }
      }
    } finally {
      _isRunningScheduledReconciles = false;
    }
  }

  Future<_RemoteReadResult> _readRemotePosition(int videoId) async {
    final DateTime now = _nowUtc();
    final DateTime? lastReadAt = _lastRemoteReadAtByVideo[videoId];
    if (lastReadAt != null &&
        now.difference(lastReadAt) < _remoteReadCooldown) {
      final DateTime nextAllowedReadAt = lastReadAt.add(_remoteReadCooldown);
      return _RemoteReadResult.skippedByCooldown(
        nextAllowedReadAt: nextAllowedReadAt,
      );
    }

    try {
      final RemotePlaybackPosition? remote =
          await _remoteDataSource.getPosition(videoId);
      _lastRemoteReadAtByVideo[videoId] = now;
      return _RemoteReadResult.success(position: remote);
    } catch (error, stackTrace) {
      _logService.error('reconcileVideo remote read failed', error, stackTrace);
      return const _RemoteReadResult.failed();
    }
  }

  DateTime _nowUtc() => _nowProvider().toUtc();

  static DateTime _defaultNowUtc() => DateTime.now().toUtc();

  /// What a device that is not casting anywhere answers: its own progress is its own to write.
  static bool _progressIsNeverWrittenElsewhere() => false;

  double _normalizePosition(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0;
    }
    return value < 0 ? 0 : value;
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

  DateTime _asDateTime(Object? value) {
    final String raw = (value ?? '').toString().trim();
    final DateTime? parsed = DateTime.tryParse(raw);
    return (parsed ?? DateTime.now().toUtc()).toUtc();
  }
}

class _OutboxCandidate {
  const _OutboxCandidate({
    required this.outboxId,
    required this.videoId,
    required this.positionSeconds,
    required this.updatedAt,
  });

  final int outboxId;
  final int videoId;
  final double positionSeconds;
  final DateTime updatedAt;
}

class _RemoteReadResult {
  const _RemoteReadResult._({
    required this.position,
    required this.canUseForPushDecision,
    required this.skippedByCooldown,
    required this.nextAllowedReadAt,
  });

  const _RemoteReadResult.success({
    required RemotePlaybackPosition? position,
  }) : this._(
          position: position,
          canUseForPushDecision: true,
          skippedByCooldown: false,
          nextAllowedReadAt: null,
        );

  const _RemoteReadResult.failed()
      : this._(
          position: null,
          canUseForPushDecision: false,
          skippedByCooldown: false,
          nextAllowedReadAt: null,
        );

  const _RemoteReadResult.skippedByCooldown({
    required DateTime nextAllowedReadAt,
  }) : this._(
          position: null,
          canUseForPushDecision: false,
          skippedByCooldown: true,
          nextAllowedReadAt: nextAllowedReadAt,
        );

  final RemotePlaybackPosition? position;
  final bool canUseForPushDecision;
  final bool skippedByCooldown;
  final DateTime? nextAllowedReadAt;
}
