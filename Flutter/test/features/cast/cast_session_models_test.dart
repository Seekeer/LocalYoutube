import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_session_models.dart';

/// The Cast Session contract as the API actually sends it.
///
/// The payloads here are written out the way `CastProtocolWireFormatTests` observed them against
/// the real hub, so a change on either side shows up as a failure on this one.
void main() {
  test('a session is read from exactly the shape the API sends', () {
    final CastSession? session = CastSession.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'status': 'active',
      'controllerDeviceId': 'phone-1',
      'controllerName': 'Pixel 8',
      'receiverDeviceId': 'tv-1',
      'receiverName': 'Living room',
      'videoId': 42,
      'isReceiverPrepared': true,
      'confirmedState': <String, Object?>{
        'videoId': 42,
        'positionMs': 30120,
        'durationMs': 1800000,
        'isPlaying': true,
        'isBuffering': false,
        'isCompleted': false,
        'volume': 0.35,
        'lastAppliedSeq': 4,
      },
      'endReason': null,
    });

    expect(session, isNotNull);
    expect(session!.sessionId, 'abc');
    expect(session.status, CastSessionStatus.active);
    expect(session.controllerDeviceId, 'phone-1');
    expect(session.controllerName, 'Pixel 8');
    expect(session.receiverDeviceId, 'tv-1');
    expect(session.receiverName, 'Living room');
    expect(session.videoId, 42);
    expect(session.isReceiverPrepared, isTrue);
    expect(session.endReason, isNull);
    expect(session.isLive, isTrue);

    final CastPlaybackState confirmed = session.confirmedState!;
    expect(confirmed.videoId, 42);
    expect(confirmed.position, const Duration(milliseconds: 30120));
    expect(confirmed.duration, const Duration(milliseconds: 1800000));
    expect(confirmed.isPlaying, isTrue);
    expect(confirmed.isBuffering, isFalse);
    expect(confirmed.isCompleted, isFalse);
    expect(confirmed.volume, 0.35);
    expect(confirmed.lastAppliedSeq, 4);
  });

  test('a buffering, finished or silent Receiver is read as it is reported', () {
    final CastPlaybackState? state =
        CastPlaybackState.tryParse(<String, Object?>{
      'videoId': 42,
      'positionMs': 1800000,
      'durationMs': 1800000,
      'isPlaying': false,
      'isBuffering': true,
      'isCompleted': true,
      'volume': 0,
      'lastAppliedSeq': 9,
    });

    expect(state, isNotNull);
    expect(state!.isPlaying, isFalse);
    expect(state.isBuffering, isTrue);
    expect(state.isCompleted, isTrue);
    expect(state.volume, 0);
    expect(state.lastAppliedSeq, 9);
  });

  test('a confirmed state this client cannot fully read still plays', () {
    // A volume outside the player's range and a number that names no command are values this
    // protocol has no meaning for. Reading the nearest thing that does is better than showing the
    // viewer nothing at all about a Receiver that is playing perfectly well.
    final CastPlaybackState? state =
        CastPlaybackState.tryParse(<String, Object?>{
      'videoId': 42,
      'positionMs': 1000,
      'isPlaying': true,
      'volume': 11,
      'lastAppliedSeq': -3,
    });

    expect(state, isNotNull);
    expect(state!.isPlaying, isTrue);
    expect(state.volume, 1.0);
    expect(state.lastAppliedSeq, 0);
    expect(state.duration, Duration.zero);
    expect(state.isBuffering, isFalse);
    expect(state.isCompleted, isFalse);
  });

  test('a preparing session has no confirmed state yet', () {
    final CastSession? session = CastSession.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'status': 'preparing',
      'controllerDeviceId': 'phone-1',
      'controllerName': 'Pixel 8',
      'receiverDeviceId': 'tv-1',
      'receiverName': 'Living room',
      'videoId': 42,
      'isReceiverPrepared': false,
      'confirmedState': null,
      'endReason': null,
    });

    expect(session!.status, CastSessionStatus.preparing);
    expect(session.isReceiverPrepared, isFalse);
    expect(session.confirmedState, isNull);
    expect(session.isLive, isTrue);
  });

  test('every status the API can report is understood', () {
    expect(CastSessionStatus.parse('preparing'), CastSessionStatus.preparing);
    expect(CastSessionStatus.parse('active'), CastSessionStatus.active);
    expect(
      CastSessionStatus.parse('reconnecting'),
      CastSessionStatus.reconnecting,
    );
    expect(CastSessionStatus.parse('ended'), CastSessionStatus.ended);

    // Reconnecting is still this device's session, so Remote Control Mode stays.
    expect(CastSessionStatus.reconnecting.isLive, isTrue);
    expect(CastSessionStatus.ended.isLive, isFalse);
  });

  test('a status this client does not know leaves the device out of cast state',
      () {
    final CastSession? session = CastSession.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'status': 'somethingNewer',
      'controllerDeviceId': 'phone-1',
      'controllerName': 'Pixel 8',
      'receiverDeviceId': 'tv-1',
      'receiverName': 'Living room',
      'videoId': 42,
      'isReceiverPrepared': true,
    });

    // The message is still a session - it is simply not one this version can act on, so the phone
    // treats it exactly like a session that ended rather than staying in Remote Control Mode.
    expect(session, isNotNull);
    expect(session!.status, CastSessionStatus.unknown);
    expect(session.isLive, isFalse);
  });

  test('every end reason the API can report is understood', () {
    expect(CastEndReason.parse('returnHandoff'), CastEndReason.returnHandoff);
    expect(
      CastEndReason.parse('handoffCancelled'),
      CastEndReason.handoffCancelled,
    );
    expect(CastEndReason.parse('handoffExpired'), CastEndReason.handoffExpired);
    expect(
      CastEndReason.parse('receiverNavigatedAway'),
      CastEndReason.receiverNavigatedAway,
    );
    expect(
      CastEndReason.parse('playbackCompleted'),
      CastEndReason.playbackCompleted,
    );
    expect(
      CastEndReason.parse('participantSignedOut'),
      CastEndReason.participantSignedOut,
    );
    expect(
      CastEndReason.parse('participantTimeout'),
      CastEndReason.participantTimeout,
    );
    expect(CastEndReason.parse('sessionMissing'), CastEndReason.sessionMissing);
  });

  test('an end reason this client does not know still ends the session', () {
    final CastSession? session = CastSession.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'status': 'ended',
      'controllerDeviceId': 'phone-1',
      'controllerName': 'Pixel 8',
      'receiverDeviceId': 'tv-1',
      'receiverName': 'Living room',
      'videoId': 42,
      'isReceiverPrepared': true,
      'endReason': 'somethingNewer',
    });

    expect(session!.endReason, CastEndReason.unknown);
    expect(session.isLive, isFalse);
  });

  test('a payload that is not a session is refused', () {
    expect(CastSession.tryParse(null), isNull);
    expect(CastSession.tryParse('ended'), isNull);
    expect(CastSession.tryParse(<String, Object?>{'status': 'active'}), isNull);
  });

  test('a confirmed state without a video is not a confirmed state', () {
    expect(CastPlaybackState.tryParse(null), isNull);
    expect(
      CastPlaybackState.tryParse(<String, Object?>{'positionMs': 10}),
      isNull,
    );
  });

  test('a missing or impossible position reads as the start of the video', () {
    final CastPlaybackState? missing =
        CastPlaybackState.tryParse(<String, Object?>{'videoId': 42});
    expect(missing?.position, Duration.zero);

    final CastPlaybackState? negative = CastPlaybackState.tryParse(
      <String, Object?>{'videoId': 42, 'positionMs': -1},
    );
    expect(negative?.position, Duration.zero);
  });

  test('a refusal is read out of whatever the transport wrapped it in', () {
    final Exception failure = Exception(
      "An unexpected error occurred invoking 'StartCastSession' on the server. "
      'HubException: sessionAlreadyActive',
    );

    expect(
      CastErrorReason.tryParse(failure),
      CastErrorReason.sessionAlreadyActive,
    );
  });

  test('a refusal this client does not know cannot be named', () {
    // The caller turns this into CastErrorReason.unrecognised: the cast did not happen, and the
    // viewer is told that much rather than being left waiting.
    expect(CastErrorReason.tryParse(Exception('somethingNewer')), isNull);
    expect(CastErrorReason.tryParse(null), isNull);
  });

  test('a prepare command is read from exactly the shape the API sends', () {
    final CastPrepareCommand? command =
        CastPrepareCommand.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'videoId': 42,
      'controllerDeviceId': 'phone-1',
      'controllerName': 'Pixel 8',
    });

    expect(command, isNotNull);
    expect(command!.sessionId, 'abc');
    expect(command.videoId, 42);
    expect(command.controllerDeviceId, 'phone-1');
    expect(command.controllerName, 'Pixel 8');
  });

  test('a prepare command without a session or a video is not one', () {
    expect(CastPrepareCommand.tryParse(null), isNull);
    expect(
      CastPrepareCommand.tryParse(<String, Object?>{'videoId': 42}),
      isNull,
    );
    expect(
      CastPrepareCommand.tryParse(<String, Object?>{'sessionId': 'abc'}),
      isNull,
    );
  });

  test('a commit command carries the position and the playing intent', () {
    final CastCommitCommand? command =
        CastCommitCommand.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'videoId': 42,
      'positionMs': 30000,
      'isPlaying': false,
    });

    expect(command, isNotNull);
    expect(command!.sessionId, 'abc');
    expect(command.videoId, 42);
    expect(command.position, const Duration(seconds: 30));
    expect(command.isPlaying, isFalse);
  });

  test('a commit command without a session or a video is not one', () {
    expect(CastCommitCommand.tryParse(null), isNull);
    expect(
      CastCommitCommand.tryParse(<String, Object?>{
        'videoId': 42,
        'positionMs': 30000,
      }),
      isNull,
    );
  });

  // --- Controller commands ------------------------------------------------------------
  // Only the value a command's own type names is filled in; the rest arrive as explicit nulls,
  // which is exactly what the hub was observed to send.

  test('a play or pause command carries the state to reach', () {
    final CastCommand? command = CastCommand.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'seq': 1,
      'type': 'setPlaying',
      'isPlaying': false,
      'positionMs': null,
      'volume': null,
    });

    expect(command, isNotNull);
    expect(command!.sessionId, 'abc');
    expect(command.seq, 1);
    expect(command.type, CastCommandType.setPlaying);
    expect(command.isPlaying, isFalse);
    expect(command.position, isNull);
    expect(command.volume, isNull);
  });

  test('a seek command carries an absolute position', () {
    final CastCommand? command = CastCommand.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'seq': 7,
      'type': 'seekTo',
      'isPlaying': null,
      'positionMs': 90000,
      'volume': null,
    });

    expect(command, isNotNull);
    expect(command!.seq, 7);
    expect(command.type, CastCommandType.seekTo);
    expect(command.position, const Duration(seconds: 90));
    expect(command.isPlaying, isNull);
  });

  test('a volume command carries a normalised player volume', () {
    final CastCommand? command = CastCommand.tryParse(<String, Object?>{
      'sessionId': 'abc',
      'seq': 3,
      'type': 'setVolume',
      'isPlaying': null,
      'positionMs': null,
      'volume': 0.25,
    });

    expect(command, isNotNull);
    expect(command!.type, CastCommandType.setVolume);
    expect(command.volume, 0.25);

    // Both ends of the range are ordinary values: silent is a volume, not a stop command.
    expect(_volumeOf(0), 0.0);
    expect(_volumeOf(1), 1.0);
  });

  test('a command whose type this version does not know is not acted on', () {
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'seq': 1,
        'type': 'togglePlayback',
      }),
      isNull,
    );
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'seq': 1,
        'type': 'setSpeed',
        'speed': 2,
      }),
      isNull,
    );
  });

  test('a command without a session or a number is not one', () {
    expect(CastCommand.tryParse(null), isNull);
    expect(
      CastCommand.tryParse(<String, Object?>{
        'seq': 1,
        'type': 'setPlaying',
        'isPlaying': true,
      }),
      isNull,
    );
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'type': 'setPlaying',
        'isPlaying': true,
      }),
      isNull,
    );
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'seq': 0,
        'type': 'setPlaying',
        'isPlaying': true,
      }),
      isNull,
    );
  });

  test('a command missing the value its own type names is not one', () {
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'seq': 1,
        'type': 'setPlaying',
        'isPlaying': null,
      }),
      isNull,
    );
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'seq': 1,
        'type': 'seekTo',
        'positionMs': null,
      }),
      isNull,
    );
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'seq': 1,
        'type': 'setVolume',
        'volume': null,
      }),
      isNull,
    );
  });

  test('a value this protocol has no meaning for is not a command', () {
    expect(
      CastCommand.tryParse(<String, Object?>{
        'sessionId': 'abc',
        'seq': 1,
        'type': 'seekTo',
        'positionMs': -1,
      }),
      isNull,
    );
    for (final num volume in <num>[-0.1, 1.5, 11]) {
      expect(
        CastCommand.tryParse(<String, Object?>{
          'sessionId': 'abc',
          'seq': 1,
          'type': 'setVolume',
          'volume': volume,
        }),
        isNull,
        reason: 'volume $volume is outside the player range',
      );
    }
  });
}

double? _volumeOf(num volume) {
  return CastCommand.tryParse(<String, Object?>{
    'sessionId': 'abc',
    'seq': 1,
    'type': 'setVolume',
    'volume': volume,
  })?.volume;
}
