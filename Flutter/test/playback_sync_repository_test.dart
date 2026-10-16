import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

void main() {
  late AppDatabase database;
  late LocalPlaybackRepository localPlaybackRepository;
  late LocalSyncOutboxRepository localSyncOutboxRepository;
  late _FakePlaybackPositionRemoteDataSource remoteDataSource;
  late PlaybackSyncRepository repository;
  late _FakeClock clock;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();

    clock = _FakeClock(DateTime.utc(2026, 2, 12, 10, 0, 0));
    localPlaybackRepository = LocalPlaybackRepository(
      PlaybackPositionsDao(database),
    );
    localSyncOutboxRepository =
        LocalSyncOutboxRepository(SyncOutboxDao(database));
    remoteDataSource = _FakePlaybackPositionRemoteDataSource();
    repository = PlaybackSyncRepository(
      localPlaybackRepository: localPlaybackRepository,
      remoteDataSource: remoteDataSource,
      localSyncOutboxRepository: localSyncOutboxRepository,
      logService: _NoopLogService(),
      remoteReadCooldown: const Duration(seconds: 30),
      staleReconcileDelay: const Duration(seconds: 5),
      nowProvider: clock.nowUtc,
    );
  });

  test('does not retry outbox operation immediately after failed attempt',
      () async {
    remoteDataSource.throwOnSet = true;

    await repository.savePosition(videoId: 1, positionSeconds: 20);
    expect(remoteDataSource.setCallCount, 1);
    expect(
      await localSyncOutboxRepository.listPending(limit: 100),
      hasLength(1),
    );

    await repository.processOutbox();
    expect(remoteDataSource.setCallCount, 2);

    final List<Map<String, Object?>> rowsAfterFailure =
        await localSyncOutboxRepository.listPending(limit: 100);
    expect(rowsAfterFailure, hasLength(1));
    expect((rowsAfterFailure.first['attempts'] as int?) ?? 0, 1);

    await repository.processOutbox();
    expect(remoteDataSource.setCallCount, 2);
  });

  test('deduplicates outbox batch by video and schedules single reconcile',
      () async {
    const int videoId = 5;
    remoteDataSource.returnFalseOnSet = true;

    for (int index = 0; index < 100; index++) {
      await localSyncOutboxRepository.enqueue(
        operationType: 'playback_position_set',
        payloadJson: jsonEncode(
          <String, Object?>{
            'videoId': videoId,
            'positionSeconds': index.toDouble(),
            'updatedDate': clock.nowUtc().toIso8601String(),
          },
        ),
      );
    }

    await repository.processOutbox();

    expect(remoteDataSource.setCallCount, 1);
    expect(remoteDataSource.getCallCount, 0);
    expect(
      await localSyncOutboxRepository.listPending(limit: 200),
      isEmpty,
    );

    clock.advance(const Duration(seconds: 6));
    await repository.processOutbox();
    expect(remoteDataSource.getCallCount, 1);

    await repository.processOutbox();
    expect(remoteDataSource.getCallCount, 1);
  });

  test('limits stale reconcile reads to one request per cooldown window',
      () async {
    const int videoId = 9;
    remoteDataSource.returnFalseOnSet = true;
    remoteDataSource.remoteByVideoId[videoId] = RemotePlaybackPosition(
      positionSeconds: 75,
      updatedAt: DateTime.utc(2026, 2, 12, 10, 0, 0),
    );

    await repository.savePosition(videoId: videoId, positionSeconds: 10);
    expect(remoteDataSource.getCallCount, 0);

    clock.advance(const Duration(seconds: 6));
    await repository.processOutbox();
    expect(remoteDataSource.getCallCount, 1);

    await repository.savePosition(videoId: videoId, positionSeconds: 11);
    clock.advance(const Duration(seconds: 6));
    await repository.processOutbox();
    expect(remoteDataSource.getCallCount, 1);

    clock.advance(const Duration(seconds: 30));
    await repository.processOutbox();
    expect(remoteDataSource.getCallCount, 2);
  });

  test('reconcileRecent respects per-video cooldown across repeated triggers',
      () async {
    for (int videoId = 1; videoId <= 3; videoId++) {
      await localPlaybackRepository.savePosition(
        videoId: videoId,
        positionSeconds: 10 * videoId.toDouble(),
        updatedAt: DateTime.utc(2026, 2, 12, 9, 0, 0),
      );
      remoteDataSource.remoteByVideoId[videoId] = RemotePlaybackPosition(
        positionSeconds: 100 + videoId.toDouble(),
        updatedAt: DateTime.utc(2026, 2, 12, 10, 0, 0),
      );
    }

    await repository.reconcileRecent(limit: 20);
    expect(remoteDataSource.getCallCount, 3);

    await repository.reconcileRecent(limit: 20);
    expect(remoteDataSource.getCallCount, 3);

    clock.advance(const Duration(seconds: 31));
    await repository.reconcileRecent(limit: 20);
    expect(remoteDataSource.getCallCount, 6);
  });

  test('reconciliation uses greater position when timestamps are equal',
      () async {
    const int videoId = 11;
    final DateTime sharedTimestamp = DateTime.utc(2026, 2, 12, 7, 0, 0);

    await localPlaybackRepository.savePosition(
      videoId: videoId,
      positionSeconds: 15,
      updatedAt: sharedTimestamp,
    );
    remoteDataSource.remoteByVideoId[videoId] = RemotePlaybackPosition(
      positionSeconds: 25,
      updatedAt: sharedTimestamp,
    );

    await repository.reconcileVideo(videoId);

    final snapshot = await localPlaybackRepository.getSnapshot(videoId);
    expect(snapshot?.positionSeconds, 25);
  });

  test('stale local update is replaced by fresher server snapshot', () async {
    const int videoId = 2;
    remoteDataSource.remoteByVideoId[videoId] = RemotePlaybackPosition(
      positionSeconds: 55,
      updatedAt: DateTime.utc(2026, 2, 12, 9, 0, 0),
    );

    await repository.savePosition(
      videoId: videoId,
      positionSeconds: 12,
      updatedAt: DateTime.utc(2026, 2, 12, 8, 59, 0),
    );

    clock.advance(const Duration(seconds: 6));
    await repository.processOutbox();

    final snapshot = await localPlaybackRepository.getSnapshot(videoId);
    expect(snapshot?.positionSeconds, 55);
    expect(snapshot?.updatedAt, DateTime.utc(2026, 2, 12, 9, 0, 0));
  });
}

class _FakePlaybackPositionRemoteDataSource
    extends PlaybackPositionRemoteDataSource {
  _FakePlaybackPositionRemoteDataSource() : super(Dio());

  bool throwOnSet = false;
  bool returnFalseOnSet = false;
  int setCallCount = 0;
  int getCallCount = 0;
  final Map<int, RemotePlaybackPosition> remoteByVideoId =
      <int, RemotePlaybackPosition>{};

  @override
  Future<RemotePlaybackPosition?> getPosition(int videoId) async {
    getCallCount++;
    return remoteByVideoId[videoId];
  }

  @override
  Future<bool> setPosition({
    required int videoId,
    required double positionSeconds,
    required DateTime updatedAt,
  }) async {
    setCallCount++;
    if (throwOnSet) {
      throw DioException(
        requestOptions: RequestOptions(path: '/files/setPositionMaui/$videoId'),
      );
    }
    if (returnFalseOnSet) {
      return false;
    }

    final RemotePlaybackPosition? existing = remoteByVideoId[videoId];
    if (existing != null && existing.updatedAt.isAfter(updatedAt.toUtc())) {
      return false;
    }

    remoteByVideoId[videoId] = RemotePlaybackPosition(
      positionSeconds: positionSeconds,
      updatedAt: updatedAt.toUtc(),
    );
    return true;
  }
}

class _NoopLogService extends LogService {
  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, Object error, StackTrace stackTrace) {}
}

class _FakeClock {
  _FakeClock(this._nowUtc);

  DateTime _nowUtc;

  DateTime nowUtc() => _nowUtc;

  void advance(Duration duration) {
    _nowUtc = _nowUtc.add(duration);
  }
}
