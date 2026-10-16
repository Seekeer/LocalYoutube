import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/features/cast/data/playback_sync_cast_progress_writer.dart';
import 'package:localtube_flutter/features/cast/domain/cast_playback_progress_writer.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

import 'cast_doubles.dart';

/// What happens to the video a cast displaced, against the app's real playback-progress path
/// rather than a recorded stand-in.
///
/// This is the half of "the position is there when that video is reopened" that the Receiver
/// Controller cannot prove on its own: the write has to land where an ordinary viewer's progress
/// lands, so that reopening the video finds it.
void main() {
  const int displacedVideoId = 7;

  late AppDatabase database;
  late PlaybackSyncRepository playbackSyncRepository;
  late _FakePlaybackPositionRemoteDataSource remoteDataSource;
  late CastPlaybackProgressWriter writer;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();

    remoteDataSource = _FakePlaybackPositionRemoteDataSource();
    playbackSyncRepository = PlaybackSyncRepository(
      localPlaybackRepository: LocalPlaybackRepository(
        PlaybackPositionsDao(database),
      ),
      remoteDataSource: remoteDataSource,
      localSyncOutboxRepository: LocalSyncOutboxRepository(
        SyncOutboxDao(database),
      ),
      logService: NoopLogService(),
    );
    writer = PlaybackSyncCastProgressWriter(playbackSyncRepository);
  });

  test('a displaced video is found where it was left when it is opened again',
      () async {
    await writer.saveProgress(
      videoId: displacedVideoId,
      position: const Duration(minutes: 10),
    );

    expect(
      await playbackSyncRepository.resolveStartPosition(
        displacedVideoId,
        localOnly: true,
      ),
      const Duration(minutes: 10),
    );
  });

  test('a displaced video progress reaches the server', () async {
    await writer.saveProgress(
      videoId: displacedVideoId,
      position: const Duration(minutes: 10),
    );

    // The existing server persistence behaviour, not a cast-specific one: the same call an
    // ordinary viewer's progress goes through.
    expect(remoteDataSource.setCallCount, 1);
    expect(
      remoteDataSource.remoteByVideoId[displacedVideoId]?.positionSeconds,
      600,
    );
  });

  test('a position that cannot exist is written as the start of the video',
      () async {
    await writer.saveProgress(
      videoId: displacedVideoId,
      position: const Duration(seconds: -5),
    );

    expect(
      await playbackSyncRepository.resolveStartPosition(
        displacedVideoId,
        localOnly: true,
      ),
      Duration.zero,
    );
  });
}

class _FakePlaybackPositionRemoteDataSource
    extends PlaybackPositionRemoteDataSource {
  _FakePlaybackPositionRemoteDataSource() : super(Dio());

  int setCallCount = 0;
  final Map<int, RemotePlaybackPosition> remoteByVideoId =
      <int, RemotePlaybackPosition>{};

  @override
  Future<RemotePlaybackPosition?> getPosition(int videoId) async {
    return remoteByVideoId[videoId];
  }

  @override
  Future<bool> setPosition({
    required int videoId,
    required double positionSeconds,
    required DateTime updatedAt,
  }) async {
    setCallCount++;
    remoteByVideoId[videoId] = RemotePlaybackPosition(
      positionSeconds: positionSeconds,
      updatedAt: updatedAt.toUtc(),
    );
    return true;
  }
}
