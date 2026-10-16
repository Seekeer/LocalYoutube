import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_playback_endpoint.dart';
import 'package:localtube_flutter/features/cast/domain/cast_session_models.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_receiver_controller.dart';

import 'cast_doubles.dart';

/// The Receiver's half of a Handoff, driven without a video decoder.
///
/// The video the cast displaces is video 7 throughout, and the video being cast is video 42, so
/// every assertion about "the one that was playing" and "the one that took over" reads plainly.
void main() {
  const int castVideoId = 42;
  const int displacedVideoId = 7;

  test('a Handoff loads the requested video and answers that it is prepared',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();

    harness.gateway.emitPrepareCommand(
      videoId: castVideoId,
      controllerName: 'Pixel 8',
    );
    await pumpEventQueue();

    expect(harness.playback.prepared, <int>[castVideoId]);
    expect(harness.gateway.preparedConfirmations, <String>['session-1']);
    expect(harness.controller.state.isPreparingHandoff, isTrue);
    expect(harness.controller.state.castVideoId, castVideoId);
    expect(harness.controller.state.controllerName, 'Pixel 8');
  });

  test('preparing a Handoff leaves what is already playing alone', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    harness.gateway.emitPrepareCommand(videoId: castVideoId);
    await pumpEventQueue();

    // The phone is still the device playing. Nothing here has been replaced, and nothing has been
    // written about a video that is still running.
    expect(harness.playback.starts, isEmpty);
    expect(harness.playback.playback?.videoId, displacedVideoId);
    expect(harness.progressWriter.writes, isEmpty);
    expect(harness.controller.state.isCasting, isFalse);
  });

  test('a commit starts the cast video at the committed position', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();

    await _handOff(harness, position: const Duration(seconds: 30));

    expect(harness.playback.starts, hasLength(1));
    expect(harness.playback.starts.single.videoId, castVideoId);
    expect(harness.playback.starts.single.position, const Duration(seconds: 30));
    expect(harness.playback.starts.single.isPlaying, isTrue);
    expect(harness.controller.state.isCasting, isTrue);
  });

  test('a paused Handoff arrives paused on the Receiver', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();

    await _handOff(harness, isPlaying: false);

    expect(harness.playback.starts.single.isPlaying, isFalse);
    expect(harness.gateway.reports.single.isPlaying, isFalse);
  });

  test('the Receiver reports the state it actually reached', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();

    await _handOff(harness, position: const Duration(seconds: 30));

    expect(harness.gateway.reports, hasLength(1));
    expect(harness.gateway.reports.single.sessionId, 'session-1');
    expect(harness.gateway.reports.single.videoId, castVideoId);
    expect(
      harness.gateway.reports.single.position,
      const Duration(seconds: 30),
    );
  });

  test('a committed Handoff replaces local playback without being asked',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    await _handOff(harness);

    // One video playing, and it is the cast one: there was no prompt to answer and nothing else
    // was left running beside it.
    expect(harness.playback.starts, hasLength(1));
    expect(harness.playback.playback?.videoId, castVideoId);
  });

  test('replacement leaves exactly one Cast Session on the Receiver', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    await _handOff(harness);

    expect(harness.controller.state.isCasting, isTrue);
    expect(harness.controller.state.sessionId, 'session-1');
    expect(harness.controller.state.castVideoId, castVideoId);
    expect(harness.gateway.reports, hasLength(1));
  });

  test('the displaced video progress is written before the cast video starts',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    await _handOff(harness);

    // The order is the point. A write that landed after the replacement would be a position the
    // viewer could not rely on when they come back to video 7.
    expect(
      harness.journal,
      <String>[
        'prepare:$castVideoId',
        'progress:$displacedVideoId',
        'start:$castVideoId',
      ],
    );
  });

  test('the displaced video keeps the position it had when it was replaced',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    await _handOff(harness);

    expect(harness.progressWriter.writes, hasLength(1));
    expect(harness.progressWriter.writes.single.videoId, displacedVideoId);
    expect(
      harness.progressWriter.writes.single.position,
      const Duration(minutes: 10),
    );
  });

  test('a Receiver that was playing nothing has nothing to keep', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();

    await _handOff(harness);

    expect(harness.progressWriter.writes, isEmpty);
    expect(harness.playback.starts, hasLength(1));
  });

  test('casting the video that is already playing is not a replacement',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: castVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    await _handOff(harness, position: const Duration(seconds: 30));

    // Nothing was displaced: the same video simply continues from where the phone was.
    expect(harness.progressWriter.writes, isEmpty);
    expect(harness.playback.starts.single.position, const Duration(seconds: 30));
  });

  test('a progress write that fails does not stop the Handoff', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );
    harness.progressWriter.failure = StateError('storage is gone');

    await _handOff(harness);

    expect(harness.playback.starts, hasLength(1));
    expect(harness.gateway.reports, hasLength(1));
    expect(harness.controller.state.isCasting, isTrue);
  });

  test('a Receiver that cannot load the video never says it is prepared',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    harness.playback.prepareFailure = StateError('no player is bound');

    harness.gateway.emitPrepareCommand(videoId: castVideoId);
    await pumpEventQueue();

    // Nothing was taken away from anyone: the phone keeps playing and the API's own minute ends
    // the Handoff.
    expect(harness.gateway.preparedConfirmations, isEmpty);
    expect(harness.controller.state.isPreparingHandoff, isFalse);
    expect(harness.controller.state.sessionId, isNull);
  });

  test('a commit for another Handoff cannot take the screen', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();

    harness.gateway.emitPrepareCommand(sessionId: 'session-1');
    await pumpEventQueue();
    harness.gateway.emitCommitCommand(sessionId: 'session-9');
    await pumpEventQueue();

    expect(harness.playback.starts, isEmpty);
    expect(harness.gateway.reports, isEmpty);
    expect(harness.controller.state.isPreparingHandoff, isTrue);
  });

  test('a Handoff that ends before the commit leaves playback alone', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    harness.gateway.emitPrepareCommand(videoId: castVideoId);
    await pumpEventQueue();
    harness.gateway.emitSessionEnded(reason: CastEndReason.handoffCancelled);
    await pumpEventQueue();

    expect(harness.controller.state.isPreparingHandoff, isFalse);
    expect(harness.controller.state.sessionId, isNull);

    // A commit that was already on its way when the viewer backed out cannot replace anything.
    harness.gateway.emitCommitCommand(videoId: castVideoId);
    await pumpEventQueue();

    expect(harness.playback.starts, isEmpty);
    expect(harness.playback.playback?.videoId, displacedVideoId);
    expect(harness.progressWriter.writes, isEmpty);
  });

  // --- The command channel ------------------------------------------------------------
  // The phone's commands are absolute and numbered by their session. What matters here is that
  // they reach the player, and that one that has been overtaken never does.

  test('play, pause, seek and volume from the phone reach the player', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);

    harness.gateway.emitSetPlaying(seq: 1, isPlaying: false);
    await pumpEventQueue();
    harness.gateway.emitSetPlaying(seq: 2, isPlaying: true);
    await pumpEventQueue();
    harness.gateway.emitSeekTo(seq: 3, position: const Duration(minutes: 5));
    await pumpEventQueue();
    harness.gateway.emitSetVolume(seq: 4, volume: 0.25);
    await pumpEventQueue();

    expect(harness.playback.playingCommands, <bool>[false, true]);
    expect(harness.playback.seeks, <Duration>[const Duration(minutes: 5)]);
    expect(harness.playback.volumes, <double>[0.25]);
    expect(harness.controller.state.lastAppliedSeq, 4);
  });

  test('a seek moves the television to the position it was given', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness, position: const Duration(seconds: 30));

    harness.gateway.emitSeekTo(seq: 1, position: const Duration(minutes: 12));
    await pumpEventQueue();

    expect(harness.playback.playback?.position, const Duration(minutes: 12));
    expect(harness.playback.playback?.videoId, castVideoId);
  });

  test('a command that has been overtaken is ignored', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);

    harness.gateway.emitSeekTo(seq: 5, position: const Duration(minutes: 10));
    await pumpEventQueue();

    // A reconnect replaying an older seek must not put the viewer back where they were.
    harness.gateway.emitSeekTo(seq: 3, position: const Duration(minutes: 1));
    await pumpEventQueue();

    expect(harness.playback.seeks, <Duration>[const Duration(minutes: 10)]);
    expect(harness.playback.playback?.position, const Duration(minutes: 10));
    expect(harness.controller.state.lastAppliedSeq, 5);
  });

  test('a command repeated with the same number is applied only once', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);

    harness.gateway.emitSetVolume(seq: 1, volume: 0.2);
    await pumpEventQueue();
    harness.gateway.emitSetVolume(seq: 1, volume: 0.9);
    await pumpEventQueue();

    expect(harness.playback.volumes, <double>[0.2]);
    expect(harness.playback.volume, 0.2);
  });

  test('numbering starts again with each Cast Session', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);

    harness.gateway.emitSeekTo(seq: 7, position: const Duration(minutes: 3));
    await pumpEventQueue();
    expect(harness.controller.state.lastAppliedSeq, 7);

    harness.gateway.emitSessionEnded(reason: CastEndReason.participantTimeout);
    await pumpEventQueue();
    expect(harness.controller.state.lastAppliedSeq, 0);

    // The next Handoff counts from one, and a Receiver still comparing against 7 would ignore
    // everything the viewer did.
    harness.gateway.emitPrepareCommand(sessionId: 'session-2');
    await pumpEventQueue();
    harness.gateway.emitCommitCommand(sessionId: 'session-2');
    await pumpEventQueue();

    harness.gateway.emitSeekTo(
      sessionId: 'session-2',
      seq: 1,
      position: const Duration(minutes: 4),
    );
    await pumpEventQueue();

    expect(harness.playback.seeks, <Duration>[
      const Duration(minutes: 3),
      const Duration(minutes: 4),
    ]);
    expect(harness.controller.state.lastAppliedSeq, 1);
  });

  test('a command for another Cast Session is ignored', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);

    harness.gateway.emitSeekTo(
      sessionId: 'session-9',
      seq: 99,
      position: const Duration(minutes: 1),
    );
    await pumpEventQueue();

    expect(harness.playback.seeks, isEmpty);
    expect(harness.controller.state.lastAppliedSeq, 0);
  });

  test('a command that arrives before the television is playing is ignored',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    harness.gateway.emitPrepareCommand(videoId: castVideoId);
    await pumpEventQueue();
    harness.gateway.emitSetPlaying(seq: 1, isPlaying: false);
    await pumpEventQueue();

    // The phone is still the device playing. Pausing what this Receiver happens to be showing
    // would be pausing somebody else's video.
    expect(harness.playback.playingCommands, isEmpty);
    expect(harness.playback.playback?.isPlaying, isTrue);
    expect(harness.controller.state.lastAppliedSeq, 0);
  });

  test('a command that ends the Cast Session ends nothing', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);
    harness.playback.commandFailure = StateError('the player is gone');

    harness.gateway.emitSeekTo(seq: 1, position: const Duration(minutes: 2));
    await pumpEventQueue();

    // A command that did not land is a command the phone will simply never see having happened.
    expect(harness.controller.state.isCasting, isTrue);
    expect(harness.controller.state.sessionId, 'session-1');

    harness.playback.commandFailure = null;
    harness.gateway.emitSeekTo(seq: 2, position: const Duration(minutes: 6));
    await pumpEventQueue();

    expect(harness.playback.seeks, <Duration>[const Duration(minutes: 6)]);
  });

  test('a Handoff never writes the television volume', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );
    harness.playback.volume = 0.3;

    await _handOff(harness);

    // A phone's volume means nothing in a room with different acoustics, so nothing about it
    // travels: the Handoff writes no volume at all.
    expect(harness.playback.volumes, isEmpty);
    // And the volume the phone is told about is the one the person in the room left this
    // Receiver at, read off the player rather than taken from anything the Handoff carried.
    expect(harness.gateway.reports.single.volume, 0.3);
  });

  test('the television volume survives the video being replaced', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);

    harness.gateway.emitSetVolume(seq: 1, volume: 0.15);
    await pumpEventQueue();

    harness.gateway.emitSessionEnded(reason: CastEndReason.participantTimeout);
    await pumpEventQueue();
    harness.gateway.emitPrepareCommand(sessionId: 'session-2', videoId: 88);
    await pumpEventQueue();
    harness.gateway.emitCommitCommand(sessionId: 'session-2', videoId: 88);
    await pumpEventQueue();

    expect(harness.playback.volume, 0.15);
  });

  test('a status this version does not know ends the Receiver part of it',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();

    harness.gateway.emitPrepareCommand(videoId: castVideoId);
    await pumpEventQueue();
    harness.gateway.emitUnknownSessionStatus();
    await pumpEventQueue();

    expect(harness.controller.state.phase, CastReceiverPhase.idle);
    expect(harness.controller.state.sessionId, isNull);
  });

  test('a Return Handoff stops this television and leaves its player on screen',
      () async {
    final _ReceiverHarness harness = _ReceiverHarness.start();
    await _handOff(harness);
    expect(harness.playback.playback?.isPlaying, isTrue);

    harness.gateway.emitSessionEnded(reason: CastEndReason.returnHandoff);
    await pumpEventQueue();

    // Paused rather than closed: playback is going back to the phone, and somebody still sitting
    // in front of the Receiver can pick the video up again with its own remote.
    expect(harness.playback.playingCommands, <bool>[false]);
    expect(harness.playback.playback?.videoId, castVideoId);
    expect(harness.playback.playback?.isPlaying, isFalse);
    expect(harness.controller.state.phase, CastReceiverPhase.idle);
    expect(harness.controller.state.sessionId, isNull);
  });

  // Every way a Cast Session ends leaves this Receiver paused with its player still on screen.
  // There is no end after which it goes on playing to a room whose remote has stopped working -
  // and a paused player holds the screen awake no more than any other paused video does, which is
  // what keeps a finished Cast Session from keeping a Receiver's screen lit all night.
  for (final CastEndReason reason in <CastEndReason>[
    CastEndReason.returnHandoff,
    CastEndReason.participantTimeout,
    CastEndReason.participantSignedOut,
    CastEndReason.sessionMissing,
    CastEndReason.playbackCompleted,
    CastEndReason.unknown,
  ]) {
    test('a session that ends as ${reason.name} leaves this television paused',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.gateway.emitSessionEnded(reason: reason);
      await pumpEventQueue();

      expect(harness.playback.playingCommands, <bool>[false]);
      expect(harness.playback.playback?.videoId, castVideoId);
      expect(harness.playback.playback?.isPlaying, isFalse);
      expect(harness.controller.state.phase, CastReceiverPhase.idle);
    });
  }

  test('a Handoff that ended before it committed pauses nothing here', () async {
    final _ReceiverHarness harness = _ReceiverHarness.start(
      playing: const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 10),
        isPlaying: true,
      ),
    );

    harness.gateway.emitPrepareCommand(videoId: castVideoId);
    await pumpEventQueue();
    harness.gateway.emitSessionEnded(reason: CastEndReason.handoffCancelled);
    await pumpEventQueue();

    // This Receiver never played the cast video, so there is nothing of the session to stop.
    // Pausing would stop whatever the person in front of it was watching all along.
    expect(harness.playback.playingCommands, isEmpty);
    expect(harness.playback.playback?.videoId, displacedVideoId);
    expect(harness.playback.playback?.isPlaying, isTrue);
    expect(harness.controller.state.phase, CastReceiverPhase.idle);
  });

  group('Ends only this television can see', () {
    test('leaving the cast video ends the session as navigated away', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      // Somebody at the Receiver went back to the list: there is no player here any more.
      harness.playback.playback = null;
      await harness.advance(CastReceiverController.samplePeriod);

      expect(harness.gateway.ends, hasLength(1));
      expect(harness.gateway.ends.single.sessionId, 'session-1');
      expect(
        harness.gateway.ends.single.reason,
        CastEndReason.receiverNavigatedAway,
      );
      expect(harness.controller.state.phase, CastReceiverPhase.idle);
    });

    test('opening another video on the television ends the session', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.playback.playback = const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 1),
        isPlaying: true,
      );
      await harness.advance(CastReceiverController.samplePeriod);

      expect(
        harness.gateway.ends.single.reason,
        CastEndReason.receiverNavigatedAway,
      );

      // Nothing is paused on the way out: what is on screen now is this room's own business, and
      // the Cast Session never owned it.
      expect(harness.playback.playingCommands, isEmpty);
      expect(harness.playback.playback?.isPlaying, isTrue);
    });

    test('nothing more is reported once the television left the video',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);
      final int reported = harness.gateway.reports.length;

      harness.playback.playback = null;
      await harness.advance(const Duration(seconds: 30));

      expect(harness.gateway.reports, hasLength(reported));
      expect(harness.gateway.ends, hasLength(1));
    });

    test('a video that reached its end ends the session as completed',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.playback.moveTo(
        position: const Duration(minutes: 30),
        isPlaying: false,
        isCompleted: true,
      );
      await harness.advance(CastReceiverController.samplePeriod);

      // The phone hears the video finished before it hears the session is over, so the ended
      // session carries a completed state - which is the whole of what stops the phone from
      // starting a finished video again.
      expect(harness.gateway.reports.last.isCompleted, isTrue);
      expect(
        harness.gateway.ends.single.reason,
        CastEndReason.playbackCompleted,
      );
      expect(harness.controller.state.phase, CastReceiverPhase.idle);
      expect(harness.playback.playingCommands, <bool>[false]);
    });

    test('a completed video is not ended twice', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.playback.moveTo(
        position: const Duration(minutes: 30),
        isPlaying: false,
        isCompleted: true,
      );
      await harness.advance(const Duration(seconds: 30));

      expect(harness.gateway.ends, hasLength(1));
    });

    test('a report the API answers with no such session leaves cast state',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      // What a restarted API answers: it has never heard of this session.
      harness.gateway.reportFailure = Exception(
        "An unexpected error occurred invoking 'ReportCastPlaybackState' on "
        'the server. HubException: sessionNotFound',
      );
      harness.playback.moveTo(position: const Duration(seconds: 31));
      await harness.advance(const Duration(seconds: 1));

      expect(harness.controller.state.phase, CastReceiverPhase.idle);
      expect(harness.controller.state.sessionId, isNull);
      expect(harness.playback.playingCommands, <bool>[false]);
      // There is nobody to tell: the API is the one that has forgotten the session.
      expect(harness.gateway.ends, isEmpty);

      // And this Receiver has gone quiet. The connection would carry a report again, and half a
      // minute - well past either reporting interval, playing or paused - produces none.
      final int reported = harness.gateway.reports.length;
      harness.gateway.reportFailure = null;
      harness.playback.moveTo(position: const Duration(seconds: 32));
      await harness.advance(const Duration(seconds: 30));

      expect(harness.gateway.reports, hasLength(reported));
    });

    test('an end the API refuses still leaves this television out of it',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      // Most often because the API had already ended the session itself.
      harness.gateway.endFailure = Exception('HubException: sessionNotFound');
      harness.playback.playback = null;
      await harness.advance(CastReceiverController.samplePeriod);

      expect(harness.controller.state.phase, CastReceiverPhase.idle);
      expect(harness.controller.state.sessionId, isNull);

      // And it stays out of it. Somebody in the room opening the cast video again is this room's
      // own business now: half a minute of it, thirty times over the reporting interval, is
      // reported to nobody.
      final int reported = harness.gateway.reports.length;
      harness.playback.playback = const CastLocalPlayback(
        videoId: castVideoId,
        position: Duration(seconds: 31),
        isPlaying: true,
      );
      await harness.advance(const Duration(seconds: 30));

      expect(harness.gateway.reports, hasLength(reported));
    });

    test('a report that simply did not arrive keeps the Cast Session', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.gateway.reportFailure = StateError('the connection is down');
      harness.playback.moveTo(position: const Duration(seconds: 31));
      await harness.advance(const Duration(seconds: 1));

      expect(harness.controller.state.isCasting, isTrue);
      expect(harness.playback.playingCommands, isEmpty);
    });
  });

  group('A television that restarted', () {
    test('says it does not have the session the API hands back', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await pumpEventQueue();

      // The application came back and registered again, so the API binds it to the session it was
      // in and goes on describing one. Nothing here is playing it.
      harness.gateway.emitSession(
        castSession(
          status: CastSessionStatus.active,
          receiverDeviceId: _ReceiverHarness.ownDeviceId,
          confirmedState: const CastPlaybackState(
            videoId: 42,
            position: Duration(minutes: 5),
            isPlaying: true,
          ),
        ),
      );
      await pumpEventQueue();

      expect(harness.gateway.ends, hasLength(1));
      expect(harness.gateway.ends.single.sessionId, 'session-1');
      expect(harness.gateway.ends.single.reason, CastEndReason.sessionMissing);
      expect(harness.controller.state.phase, CastReceiverPhase.idle);
    });

    test('says so once, however often the API repeats itself', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await pumpEventQueue();

      for (int repeat = 0; repeat < 3; repeat++) {
        harness.gateway.emitSession(
          castSession(
            status: CastSessionStatus.active,
            receiverDeviceId: _ReceiverHarness.ownDeviceId,
          ),
        );
        await pumpEventQueue();
      }

      expect(harness.gateway.ends, hasLength(1));
    });

    test('says nothing about a session this device is not the Receiver of',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await pumpEventQueue();

      // A phone hears every session it is the Controller of on this very stream. Its own Receiver
      // Controller must not end one because it is not the one playing it.
      harness.gateway.emitSession(
        castSession(
          status: CastSessionStatus.active,
          controllerDeviceId: _ReceiverHarness.ownDeviceId,
          receiverDeviceId: 'some-other-receiver',
        ),
      );
      await pumpEventQueue();

      expect(harness.gateway.ends, isEmpty);
    });

    test('says nothing about a session it is in the middle of', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.gateway.emitSession(
        castSession(
          status: CastSessionStatus.active,
          receiverDeviceId: _ReceiverHarness.ownDeviceId,
          confirmedState: const CastPlaybackState(
            videoId: castVideoId,
            position: Duration(seconds: 30),
            isPlaying: true,
          ),
        ),
      );
      await pumpEventQueue();

      expect(harness.gateway.ends, isEmpty);
      expect(harness.controller.state.isCasting, isTrue);
    });
  });

  // --- Reporting what this Receiver is playing -------------------------------------------
  // The Receiver is Playback Authority, so while it is casting it is the only thing that knows
  // what playback is doing. Everything below is about saying so: often enough that the phone is
  // never out of date, and from the player itself so that a person using the Receiver's own
  // remote and a phone sending a command are described exactly the same way.

  group('Reporting confirmed state', () {
    test('a report carries the whole state the phone renders', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      harness.playback.duration = const Duration(minutes: 45);
      harness.playback.volume = 0.6;

      await _handOff(harness, position: const Duration(seconds: 30));

      final FakeCastReport report = harness.gateway.reports.single;
      expect(report.sessionId, 'session-1');
      expect(report.videoId, castVideoId);
      expect(report.position, const Duration(seconds: 30));
      expect(report.duration, const Duration(minutes: 45));
      expect(report.isPlaying, isTrue);
      expect(report.isBuffering, isFalse);
      expect(report.isCompleted, isFalse);
      expect(report.volume, 0.6);
      expect(report.lastAppliedSeq, 0);
    });

    test('a playing Receiver reports every second', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness, position: const Duration(seconds: 30));
      expect(harness.gateway.reports, hasLength(1));

      // A second of ordinary playback: the position moves and nothing else does.
      harness.playback.moveTo(position: const Duration(seconds: 31));
      await harness.advance(const Duration(seconds: 1));
      expect(harness.gateway.reports, hasLength(2));

      harness.playback.moveTo(position: const Duration(seconds: 32));
      await harness.advance(const Duration(seconds: 1));
      expect(harness.gateway.reports, hasLength(3));
      expect(harness.gateway.reports.last.position, const Duration(seconds: 32));
    });

    test('a paused Receiver reports every five seconds as a heartbeat',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness, isPlaying: false);
      expect(harness.gateway.reports, hasLength(1));

      // Nothing is moving, so a second of it is not news.
      await harness.advance(const Duration(seconds: 1));
      expect(harness.gateway.reports, hasLength(1));

      await harness.advance(const Duration(seconds: 4));
      expect(harness.gateway.reports, hasLength(2));
      expect(harness.gateway.reports.last.isPlaying, isFalse);
    });

    test('play on the television own remote is reported at once', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness, isPlaying: false);
      expect(harness.gateway.reports, hasLength(1));

      // Somebody in the room presses play. The heartbeat is five seconds away; this is news.
      harness.playback.moveTo(isPlaying: true);
      await harness.advance(CastReceiverController.samplePeriod);

      expect(harness.gateway.reports, hasLength(2));
      expect(harness.gateway.reports.last.isPlaying, isTrue);
      // Nothing was commanded from the phone, and the phone hears about it all the same.
      expect(harness.playback.playingCommands, isEmpty);
      expect(harness.gateway.reports.last.lastAppliedSeq, 0);
    });

    test('a seek on the television own remote is reported at once', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness, position: const Duration(seconds: 30));

      harness.playback.moveTo(position: const Duration(minutes: 12));
      await harness.advance(CastReceiverController.samplePeriod);

      expect(harness.gateway.reports, hasLength(2));
      expect(harness.gateway.reports.last.position, const Duration(minutes: 12));
      expect(harness.playback.seeks, isEmpty);
    });

    test('a volume change in the room is reported at once', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.playback.moveTo(volume: 0.2);
      await harness.advance(CastReceiverController.samplePeriod);

      expect(harness.gateway.reports, hasLength(2));
      expect(harness.gateway.reports.last.volume, 0.2);
      expect(harness.playback.volumes, isEmpty);
    });

    test('buffering is reported as it starts and as it stops', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.playback.moveTo(isBuffering: true);
      await harness.advance(CastReceiverController.samplePeriod);
      expect(harness.gateway.reports.last.isBuffering, isTrue);

      harness.playback.moveTo(isBuffering: false);
      await harness.advance(CastReceiverController.samplePeriod);
      expect(harness.gateway.reports.last.isBuffering, isFalse);
      expect(harness.gateway.reports, hasLength(3));
    });

    test('a video that reached its end is reported as completed', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.playback.moveTo(
        position: const Duration(minutes: 30),
        isPlaying: false,
        isCompleted: true,
      );
      await harness.advance(CastReceiverController.samplePeriod);

      // Completion is reported before it ends the session, and that order is the point: the ended
      // session the phone reads carries a completed state, which is what keeps it from starting a
      // finished video again. What the end itself does is asserted where the ends are.
      expect(harness.gateway.reports.last.isCompleted, isTrue);
      expect(harness.gateway.reports.last.position, const Duration(minutes: 30));
    });

    test('every report carries the number of the last command applied',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);
      expect(harness.gateway.reports.single.lastAppliedSeq, 0);

      harness.gateway.emitSeekTo(seq: 1, position: const Duration(minutes: 2));
      await pumpEventQueue();
      await harness.advance(CastReceiverController.samplePeriod);
      expect(harness.gateway.reports.last.lastAppliedSeq, 1);

      harness.gateway.emitSetVolume(seq: 2, volume: 0.4);
      await pumpEventQueue();
      await harness.advance(CastReceiverController.samplePeriod);
      expect(harness.gateway.reports.last.lastAppliedSeq, 2);
      expect(harness.controller.state.lastAppliedSeq, 2);
    });

    test('a command the television ignored does not raise the number reported',
        () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);

      harness.gateway.emitSeekTo(seq: 2, position: const Duration(minutes: 2));
      await pumpEventQueue();
      await harness.advance(CastReceiverController.samplePeriod);
      expect(harness.gateway.reports.last.lastAppliedSeq, 2);

      // Overtaken, so it is thrown away rather than applied - and the phone is told the number of
      // the command that really is the latest one here.
      harness.gateway.emitSeekTo(seq: 1, position: const Duration(minutes: 9));
      await pumpEventQueue();
      await harness.advance(const Duration(seconds: 1));

      expect(harness.gateway.reports.last.lastAppliedSeq, 2);
      expect(harness.playback.seeks, <Duration>[const Duration(minutes: 2)]);
    });

    test('nothing is reported until the Handoff commits', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start(
        playing: const CastLocalPlayback(
          videoId: displacedVideoId,
          position: Duration(minutes: 10),
          isPlaying: true,
        ),
      );

      harness.gateway.emitPrepareCommand(videoId: castVideoId);
      await pumpEventQueue();
      await harness.advance(const Duration(seconds: 30));

      // The phone is still the device playing, and this Receiver is showing a video the Cast
      // Session is not about.
      expect(harness.gateway.reports, isEmpty);
    });

    test('a television showing another video says nothing about it', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);
      final int reported = harness.gateway.reports.length;

      harness.playback.playback = const CastLocalPlayback(
        videoId: displacedVideoId,
        position: Duration(minutes: 1),
        isPlaying: true,
      );
      await harness.advance(const Duration(seconds: 30));

      // Reporting somebody else's video would be worse than saying nothing. What this device does
      // say instead is that it has left the cast video, which is asserted where the ends are.
      expect(harness.gateway.reports, hasLength(reported));
    });

    test('a report that did not arrive does not stop the next one', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness, position: const Duration(seconds: 30));

      harness.gateway.reportFailure = StateError('the connection is down');
      harness.playback.moveTo(position: const Duration(seconds: 31));
      await harness.advance(const Duration(seconds: 1));
      expect(harness.gateway.reports, hasLength(1));

      harness.gateway.reportFailure = null;
      harness.playback.moveTo(position: const Duration(seconds: 32));
      await harness.advance(const Duration(seconds: 1));

      // Reports are the whole state rather than deltas, so the one that arrived carries everything
      // the lost one would have.
      expect(harness.gateway.reports, hasLength(2));
      expect(harness.gateway.reports.last.position, const Duration(seconds: 32));
      expect(harness.controller.state.isCasting, isTrue);
    });

    test('the Receiver stops reporting when the Cast Session ends', () async {
      final _ReceiverHarness harness = _ReceiverHarness.start();
      await _handOff(harness);
      final int reported = harness.gateway.reports.length;

      harness.gateway.emitSessionEnded(
        reason: CastEndReason.participantTimeout,
      );
      await pumpEventQueue();
      await harness.advance(const Duration(seconds: 30));

      expect(harness.gateway.reports, hasLength(reported));
    });
  });
}

/// A whole Handoff seen from the Receiver: the API asks for the video, then commits where the
/// viewer actually is.
Future<void> _handOff(
  _ReceiverHarness harness, {
  int videoId = 42,
  Duration position = const Duration(seconds: 30),
  bool isPlaying = true,
}) async {
  harness.gateway.emitPrepareCommand(videoId: videoId);
  await pumpEventQueue();
  harness.gateway.emitCommitCommand(
    videoId: videoId,
    position: position,
    isPlaying: isPlaying,
  );
  await pumpEventQueue();
}

/// A Receiver Controller over a fake API connection, a player without a decoder and a recorded
/// playback-progress path, so a test drives exactly what the Receiver drives.
class _ReceiverHarness {
  _ReceiverHarness({
    required this.gateway,
    required this.playback,
    required this.progressWriter,
    required this.clock,
    required this.controller,
    required this.journal,
  });

  /// This installation's stable identity. It is the Receiver the sessions in [cast_doubles.dart]
  /// name, so a session pushed here is one this Receiver ought to be playing.
  static const String ownDeviceId = 'tv-2';

  static _ReceiverHarness start({
    CastLocalPlayback? playing,
    String deviceId = ownDeviceId,
  }) {
    // One journal shared by the player and the progress writer: the order between them is what
    // "persisted before replacement" means.
    final List<String> journal = <String>[];
    final FakeCastGateway gateway = FakeCastGateway();
    final FakeCastReceiverPlayback playback = FakeCastReceiverPlayback(
      playback: playing,
      journal: journal,
    );
    final RecordingCastProgressWriter progressWriter =
        RecordingCastProgressWriter(journal: journal);
    final FakeCastClock clock = FakeCastClock();
    final CastReceiverController controller = CastReceiverController(
      gateway: gateway,
      playback: playback,
      progressWriter: progressWriter,
      identityRepository: FixedCastDeviceIdentityRepository(deviceId),
      clock: clock,
      logService: NoopLogService(),
    );

    final _ReceiverHarness harness = _ReceiverHarness(
      gateway: gateway,
      playback: playback,
      progressWriter: progressWriter,
      clock: clock,
      controller: controller,
      journal: journal,
    );
    addTearDown(harness.dispose);
    return harness;
  }

  final FakeCastGateway gateway;
  final FakeCastReceiverPlayback playback;
  final RecordingCastProgressWriter progressWriter;
  final FakeCastClock clock;
  final CastReceiverController controller;
  final List<String> journal;

  /// Moves the Receiver's own clock on and lets everything it started finish.
  Future<void> advance(Duration by) async {
    clock.advance(by);
    await pumpEventQueue();
  }

  Future<void> dispose() async {
    controller.dispose();
    await gateway.close();
  }
}
