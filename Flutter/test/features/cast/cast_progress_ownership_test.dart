import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/features/cast/domain/cast_progress_write_ownership.dart';
import 'package:localtube_flutter/features/cast/domain/cast_receiver_progress_hold.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

import 'cast_doubles.dart';

/// Where a Cast Session's playback progress actually lands, against the app's real
/// playback-progress path rather than a recorded stand-in.
///
/// Two devices, each signed in to its own account with its own store on the server, which is what
/// a Cast Session to a shared Receiver is. The video is watched by the person holding the phone, so
/// its progress is the phone's account's, and the server keeps it there from what the Receiver
/// reports. Neither device writes the cast video on its ordinary path while that is so: the phone
/// has only where the viewer was when the Receiver took over, and the Receiver's account never
/// watched it.
void main() {
  const int castVideoId = 42;
  const int ownVideoId = 7;

  late _FakePlaybackPositionRemoteDataSource phoneAccount;
  late _FakePlaybackPositionRemoteDataSource receiverAccount;
  late CastProgressWriteOwnershipFlag ownership;
  late CastReceiverProgressHoldFlag hold;
  late _Device receiver;
  late _Device phone;

  setUp(() async {
    phoneAccount = _FakePlaybackPositionRemoteDataSource();
    receiverAccount = _FakePlaybackPositionRemoteDataSource();
    ownership = CastProgressWriteOwnershipFlag();
    hold = CastReceiverProgressHoldFlag();

    // The Receiver, whose Receiver Controller holds the cast video back from its own account.
    receiver = await _Device.create(
      server: receiverAccount,
      isProgressWrittenElsewhere: (int videoId) => hold.isHeld(videoId),
    );

    // The phone, whose Cast Controller hands progress writing over for as long as the Receiver
    // is playing.
    phone = await _Device.create(
      server: phoneAccount,
      isProgressWrittenElsewhere: (int _) => ownership.isReceiverOwned,
    );
  });

  test('a phone in Remote Control Mode writes progress nowhere at all',
      () async {
    ownership.giveToReceiver();

    await phone.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 30,
    );

    expect(phoneAccount.setCallCount, 0);
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

    expect(phoneAccount.remoteByVideoId[castVideoId]?.positionSeconds, 660);
    expect(
      await phone.progress.resolveStartPosition(castVideoId, localOnly: true),
      const Duration(minutes: 11),
    );
  });

  test('a Receiver writes nothing of a held cast video to its own account',
      () async {
    hold.hold(castVideoId);

    await receiver.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 600,
    );

    expect(receiverAccount.setCallCount, 0);
    expect(receiverAccount.remoteByVideoId, isEmpty);
    expect(
      await receiver.progress
          .resolveStartPosition(castVideoId, localOnly: true),
      Duration.zero,
    );
    expect(await receiver.outbox.listPending(limit: 100), isEmpty);
  });

  test('a Receiver still keeps its own videos while a cast video is held',
      () async {
    hold.hold(castVideoId);

    // The video the cast displaced is this room's own viewing, kept before it is replaced.
    await receiver.progress.savePosition(
      videoId: ownVideoId,
      positionSeconds: 120,
    );

    expect(receiverAccount.remoteByVideoId[ownVideoId]?.positionSeconds, 120);
  });

  test('a held cast video is not reconciled against the Receiver account',
      () async {
    // The Receiver's own account watched this video long ago, five minutes in.
    await receiver.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 300,
    );

    hold.hold(castVideoId);

    // Resuming after a pause asks for the reconciled position before it plays on. During a cast
    // there is none to give: the session's position is the one that counts.
    expect(await receiver.progress.reconcileVideo(castVideoId), isNull);
  });

  test('a Receiver keeps the video again once the hold is released', () async {
    hold.hold(castVideoId);
    await receiver.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 600,
    );

    // Somebody in front of the Receiver picked the video up again after the cast: their viewing.
    hold.release(castVideoId);
    await receiver.progress.savePosition(
      videoId: castVideoId,
      positionSeconds: 610,
    );

    expect(receiverAccount.remoteByVideoId[castVideoId]?.positionSeconds, 610);
  });
}

/// One installation: its own storage, and its own playback-progress path onto the shared server.
class _Device {
  _Device._({required this.progress, required this.outbox});

  static Future<_Device> create({
    required PlaybackPositionRemoteDataSource server,
    bool Function(int videoId)? isProgressWrittenElsewhere,
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
