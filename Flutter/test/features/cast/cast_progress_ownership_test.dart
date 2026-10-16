import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/features/cast/domain/cast_progress_write_ownership.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

import 'cast_doubles.dart';

/// Where a Cast Session's playback progress actually lands, against the app's real
/// playback-progress path rather than a recorded stand-in.
///
/// Two devices and one server, which is what a Cast Session is. The Receiver plays the cast video
/// through the ordinary player, so its progress travels the path an ordinary viewer's progress
/// travels and the server keeps what arrives on it. The phone in Remote Control Mode has only where
/// the viewer was when the Receiver took over, and its silence is what leaves the Receiver's
/// progress standing: nothing here reorders writes or teaches the server whose they are.
void main() {
  const int castVideoId = 42;

  late _FakePlaybackPositionRemoteDataSource server;
  late CastProgressWriteOwnershipFlag ownership;
  late _Device receiver;
  late _Device phone;

  setUp(() async {
    server = _FakePlaybackPositionRemoteDataSource();
    ownership = CastProgressWriteOwnershipFlag();

    // The Receiver: the device playing the cast video, writing where it has got to exactly as
    // any device writes its own progress. Only a device's own Cast Controller ever says otherwise,
    // and a Receiver's never does.
    receiver = await _Device.create(server: server);

    // The phone, whose Cast Controller hands progress writing over for as long as the Receiver
    // is playing.
    phone = await _Device.create(
      server: server,
      isProgressWrittenElsewhere: () => ownership.isReceiverOwned,
    );
  });

  test('the progress the server keeps during a Cast Session is the Receiver\'s',
      () async {
    await receiver.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 600,
    );

    // The phone's last idea of this video is where the viewer was when the Receiver took over,
    // ten minutes behind and carrying the newer timestamp of the two.
    ownership.giveToReceiver();
    await phone.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 30,
    );

    expect(server.remoteByVideoId[castVideoId]?.positionSeconds, 600);
  });

  test('a phone in Remote Control Mode writes progress nowhere at all',
      () async {
    ownership.giveToReceiver();

    await phone.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 30,
    );

    expect(server.setCallCount, 0);
    expect(
      await phone.progress.resolveStartPosition(castVideoId, localOnly: true),
      Duration.zero,
    );
    // Nor is it left in the outbox to arrive later, which would be the same overwrite a few
    // seconds late.
    expect(await phone.outbox.listPending(limit: 100), isEmpty);
  });

  test('the phone writes its own progress again once the Cast Session ends',
      () async {
    ownership.giveToReceiver();
    await phone.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 30,
    );

    ownership.takeBack();
    await phone.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 660,
    );

    expect(server.remoteByVideoId[castVideoId]?.positionSeconds, 660);
    expect(
      await phone.progress.resolveStartPosition(castVideoId, localOnly: true),
      const Duration(minutes: 11),
    );
  });

  test('a Receiver writes its progress on the ordinary playback-progress path',
      () async {
    ownership.giveToReceiver();

    await receiver.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 600,
    );

    // The existing server persistence behaviour, reached by the same call an ordinary viewer's
    // progress reaches it by. A Cast Session adds no second way of keeping a position.
    expect(server.setCallCount, 1);
    expect(server.remoteByVideoId[castVideoId]?.positionSeconds, 600);
    expect(
      await receiver.progress
          .resolveStartPosition(castVideoId, localOnly: true),
      const Duration(minutes: 10),
    );
  });
}

/// One installation: its own storage, and its own playback-progress path onto the shared server.
class _Device {
  _Device._({required this.progress, required this.outbox});

  static Future<_Device> create({
    required PlaybackPositionRemoteDataSource server,
    bool Function()? isProgressWrittenElsewhere,
  }) async {
    final AppDatabase database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();

    final LocalSyncOutboxRepository outbox =
        LocalSyncOutboxRepository(SyncOutboxDao(database));
    return _Device._(
      progress: PlaybackSyncRepository(
        localPlaybackRepository: LocalPlaybackRepository(
          PlaybackPositionsDao(database),
        ),
        remoteDataSource: server,
        localSyncOutboxRepository: outbox,
        logService: NoopLogService(),
        isProgressWrittenElsewhere: isProgressWrittenElsewhere,
      ),
      outbox: outbox,
    );
  }

  final PlaybackSyncRepository progress;
  final LocalSyncOutboxRepository outbox;
}

/// The server both devices write to, keeping the existing behaviour that matters here: a position
/// older than the one already stored is refused rather than applied.
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
