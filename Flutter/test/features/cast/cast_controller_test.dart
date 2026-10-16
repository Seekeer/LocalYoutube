import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_identity_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_labels.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_playback_endpoint.dart';
import 'package:localtube_flutter/features/cast/domain/cast_registration_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_session_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_settings.dart';
import 'package:localtube_flutter/features/sync/domain/sync_models.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_controller.dart';

import 'cast_doubles.dart';

void main() {
  test('only the account\'s Receivers are offered as cast targets', () async {
    final _CastHarness harness = await _CastHarness.start();

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'phone-9', name: 'Another phone', model: 'Pixel 8', role: CastDeviceRole.controller),
      castDevice(deviceId: 'tv-2', name: 'Living room'),
    ]);
    await pumpEventQueue();

    expect(
      harness.controller.state.receivers
          .map((CastDeviceLabel receiver) => receiver.deviceId),
      <String>['tv-2'],
    );
  });

  test('a device is never offered as a place to cast to itself', () async {
    final _CastHarness harness = await _CastHarness.start(
      settings: const CastSettings(
        isReceiverMode: true,
        deviceName: 'Living room',
        lastSelectedReceiverDeviceId: null,
      ),
    );

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'device-1', name: 'Living room'),
      castDevice(deviceId: 'tv-2', name: 'Bedroom'),
    ]);
    await pumpEventQueue();

    expect(
      harness.controller.state.receivers
          .map((CastDeviceLabel receiver) => receiver.deviceId),
      <String>['tv-2'],
    );
  });

  test('a Receiver that goes offline leaves the list', () async {
    final _CastHarness harness = await _CastHarness.start();

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'tv-2', name: 'Living room'),
    ]);
    await pumpEventQueue();
    expect(harness.controller.state.hasReceivers, isTrue);

    // Closing LocalTube on the Receiver is simply its absence from the next snapshot.
    harness.gateway.emitDevices(const <CastDevice>[]);
    await pumpEventQueue();

    expect(harness.controller.state.hasReceivers, isFalse);
  });

  test('Receivers sharing a name are told apart in the offered list', () async {
    final _CastHarness harness = await _CastHarness.start();

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'tv-2', name: 'Living room', model: 'Shield TV'),
      castDevice(deviceId: 'tv-3', name: 'Living room', model: 'Pixel Tablet'),
    ]);
    await pumpEventQueue();

    expect(
      harness.controller.state.receivers
          .map((CastDeviceLabel receiver) => receiver.displayLabel),
      <String>['Living room (Shield TV)', 'Living room (Pixel Tablet)'],
    );
  });

  test('the last selected Receiver is preselected while it is online',
      () async {
    final _CastHarness harness = await _CastHarness.start(
      settings: const CastSettings(
        isReceiverMode: false,
        deviceName: '',
        lastSelectedReceiverDeviceId: 'tv-2',
      ),
    );

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'tv-2', name: 'Living room'),
    ]);
    await pumpEventQueue();

    expect(harness.controller.state.selectedReceiverDeviceId, 'tv-2');
    expect(harness.controller.state.selectedReceiver?.name, 'Living room');
  });

  test('the last selected Receiver is not preselected while it is offline',
      () async {
    final _CastHarness harness = await _CastHarness.start(
      settings: const CastSettings(
        isReceiverMode: false,
        deviceName: '',
        lastSelectedReceiverDeviceId: 'tv-2',
      ),
    );

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'tv-3', name: 'Bedroom'),
    ]);
    await pumpEventQueue();

    expect(harness.controller.state.selectedReceiverDeviceId, isNull);

    // It is remembered, not forgotten: coming back online preselects it again.
    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'tv-3', name: 'Bedroom'),
      castDevice(deviceId: 'tv-2', name: 'Living room'),
    ]);
    await pumpEventQueue();

    expect(harness.controller.state.selectedReceiverDeviceId, 'tv-2');
  });

  test('picking a Receiver records the choice and starts nothing', () async {
    final _CastHarness harness = await _CastHarness.start();

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'tv-2', name: 'Living room'),
    ]);
    await pumpEventQueue();
    final int registrationsBefore = harness.gateway.registrations.length;

    await harness.controller.selectReceiver('tv-2');

    expect(harness.controller.state.selectedReceiverDeviceId, 'tv-2');
    expect(
      harness.settingsRepository.settings.lastSelectedReceiverDeviceId,
      'tv-2',
    );
    // Nothing left for the API: Handoff is a separate, explicit action.
    expect(harness.gateway.registrations, hasLength(registrationsBefore));
  });

  test('a picked Receiver can be unpicked', () async {
    final _CastHarness harness = await _CastHarness.start();

    harness.gateway.emitDevices(<CastDevice>[
      castDevice(deviceId: 'tv-2', name: 'Living room'),
    ]);
    await pumpEventQueue();

    await harness.controller.selectReceiver('tv-2');
    await harness.controller.selectReceiver(null);

    expect(harness.controller.state.selectedReceiverDeviceId, isNull);
    expect(
      harness.settingsRepository.settings.lastSelectedReceiverDeviceId,
      isNull,
    );
  });

  test('turning Receiver Mode on persists it and announces the new role',
      () async {
    final _CastHarness harness = await _CastHarness.start();
    expect(harness.controller.state.isReceiverMode, isFalse);

    await harness.controller.setReceiverMode(true);
    await pumpEventQueue();

    expect(harness.controller.state.isReceiverMode, isTrue);
    expect(harness.settingsRepository.settings.isReceiverMode, isTrue);
    expect(harness.gateway.registrations.last.role, CastDeviceRole.receiver);
  });

  test('a newly designated Receiver is named after its Android model',
      () async {
    final _CastHarness harness = await _CastHarness.start();

    await harness.controller.setReceiverMode(true);
    await pumpEventQueue();

    expect(harness.controller.state.deviceName, 'Pixel Tablet');
    expect(harness.controller.state.deviceModel, 'Pixel Tablet');
    expect(harness.gateway.registrations.last.name, 'Pixel Tablet');
  });

  test('renaming persists the name and announces it', () async {
    final _CastHarness harness = await _CastHarness.start();

    await harness.controller.renameDevice('  Living room  ');
    await pumpEventQueue();

    expect(harness.controller.state.deviceName, 'Living room');
    expect(harness.settingsRepository.settings.deviceName, 'Living room');
    expect(harness.gateway.registrations.last.name, 'Living room');
  });

  test('clearing the name puts the Android model back', () async {
    final _CastHarness harness = await _CastHarness.start();

    await harness.controller.renameDevice('Living room');
    await harness.controller.renameDevice('   ');
    await pumpEventQueue();

    expect(harness.controller.state.deviceName, 'Pixel Tablet');
    expect(harness.gateway.registrations.last.name, 'Pixel Tablet');
  });

  group('Handoff', () {
    test('starting a cast asks the Receiver to load the video and leaves local '
        'playback alone', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(harness.gateway.starts, hasLength(1));
      expect(harness.gateway.starts.single.receiverDeviceId, 'tv-2');
      expect(harness.gateway.starts.single.videoId, 42);

      expect(harness.controller.state.isPreparingHandoff, isTrue);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.controller.state.isRemoteControlMode, isFalse);

      // Nothing has been committed and nothing has been given up: the phone is still playing.
      expect(harness.gateway.commits, isEmpty);
      expect(harness.playbackEndpoint.isReleased, isFalse);
    });

    test('commit carries where the viewer got to while the television was '
        'preparing', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      // The Receiver took a while, and the phone kept playing meanwhile.
      harness.playbackEndpoint.playback = const CastLocalPlayback(
        videoId: 42,
        position: Duration(seconds: 30),
        isPlaying: true,
      );
      harness.gateway.emitReceiverPrepared();
      await pumpEventQueue();

      expect(harness.gateway.commits, hasLength(1));
      expect(harness.gateway.commits.single.position, const Duration(seconds: 30));
      expect(harness.gateway.commits.single.isPlaying, isTrue);
    });

    test('a paused phone hands over a paused intent', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
        isPlaying: false,
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      harness.gateway.emitReceiverPrepared();
      await pumpEventQueue();

      expect(harness.gateway.commits.single.isPlaying, isFalse);
    });

    test('the local player is released only once the Receiver confirms its '
        'state', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      harness.gateway.emitReceiverPrepared();
      await pumpEventQueue();

      // Committed, but the Receiver has not said what it reached, so the phone still plays.
      expect(harness.playbackEndpoint.releaseCount, 0);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.controller.state.isRemoteControlMode, isFalse);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(seconds: 30),
        isPlaying: true,
      );
      await pumpEventQueue();

      expect(harness.playbackEndpoint.releaseCount, 1);
      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(harness.controller.state.ownsLocalPlayer, isFalse);
    });

    test('Remote Control Mode says where playback is and how it can be reached',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      expect(harness.controller.state.castReceiverName, 'Living room');
      expect(harness.controller.state.castVideoId, 42);
      expect(
        harness.controller.state.connectionState,
        SyncConnectionState.connected,
      );

      harness.gateway.emitConnectionState(SyncConnectionState.reconnecting);
      await pumpEventQueue();

      expect(
        harness.controller.state.connectionState,
        SyncConnectionState.reconnecting,
      );
      // Losing the connection does not end the session, so the phone still owns no player.
      expect(harness.controller.state.isRemoteControlMode, isTrue);
    });

    test('a Handoff is committed once however often the Receiver repeats that '
        'it is prepared', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      harness.gateway.emitReceiverPrepared();
      harness.gateway.emitReceiverPrepared();
      await pumpEventQueue();

      expect(harness.gateway.commits, hasLength(1));
    });

    test('a second cast cannot be started while one is in flight', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      await harness.controller.startCast(videoId: 42);
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(harness.gateway.starts, hasLength(1));
    });

    test('casting needs a Receiver to cast to', () async {
      final _CastHarness harness = await _CastHarness.start();

      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(harness.gateway.starts, isEmpty);
      expect(harness.controller.state.isPreparingHandoff, isFalse);
    });

    test('a refused cast leaves the phone exactly where it was', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      harness.gateway.startFailure = Exception(
        "An unexpected error occurred invoking 'StartCastSession' on the "
        'server. HubException: sessionAlreadyActive',
      );

      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(
        harness.controller.state.castFailureReason,
        CastErrorReason.sessionAlreadyActive,
      );
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
    });

    test('a refusal this version does not know is still a refusal', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      harness.gateway.startFailure = Exception('HubException: somethingNewer');

      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(
        harness.controller.state.castFailureReason,
        CastErrorReason.unrecognised,
      );
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
    });

    test('a session that ends puts the phone back on local playback', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitSessionEnded();
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.controller.state.sessionId, isNull);
      expect(harness.controller.state.castReceiverName, isNull);
    });

    test('a lifecycle state this version does not know leaves Remote Control '
        'Mode rather than wedging it', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      expect(harness.controller.state.isRemoteControlMode, isTrue);

      harness.gateway.emitUnknownSessionStatus();
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
    });

    test('a new cast can be started once the previous session ended', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      harness.gateway.emitSessionEnded();
      await pumpEventQueue();

      harness.playbackEndpoint.playback = const CastLocalPlayback(
        videoId: 42,
        position: Duration(seconds: 30),
        isPlaying: true,
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(harness.gateway.starts, hasLength(2));
      expect(harness.controller.state.isPreparingHandoff, isTrue);
    });
  });

  group('Commanding the Receiver', () {
    test('play, pause, seek and volume are sent to the Receiver', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      await harness.controller.setReceiverPlaying(false);
      await harness.controller.setReceiverPlaying(true);
      await harness.controller.seekReceiver(const Duration(minutes: 5));
      await harness.controller.setReceiverVolume(0.25);
      await pumpEventQueue();

      expect(harness.gateway.commands, hasLength(4));
      expect(
        harness.gateway.commands
            .map((FakeCastCommand command) => command.type)
            .toList(),
        <CastCommandType>[
          CastCommandType.setPlaying,
          CastCommandType.setPlaying,
          CastCommandType.seekTo,
          CastCommandType.setVolume,
        ],
      );
      expect(harness.gateway.commands[0].isPlaying, isFalse);
      expect(harness.gateway.commands[1].isPlaying, isTrue);
      expect(harness.gateway.commands[2].position, const Duration(minutes: 5));
      expect(harness.gateway.commands[3].volume, 0.25);
      expect(
        harness.gateway.commands.every(
          (FakeCastCommand command) => command.sessionId == 'session-1',
        ),
        isTrue,
      );
    });

    test('a timestamp is sent as the absolute position it stands for', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      await harness.controller.seekReceiver(const Duration(minutes: 12));
      await pumpEventQueue();

      expect(harness.gateway.commands.single.type, CastCommandType.seekTo);
      expect(
        harness.gateway.commands.single.position,
        const Duration(minutes: 12),
      );
    });

    test('nothing is commanded while this phone is the one playing', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      // Before any Handoff at all.
      await harness.controller.setReceiverPlaying(false);
      await harness.controller.seekReceiver(const Duration(minutes: 1));

      // And while a Handoff is still being prepared: the phone's own player is what the viewer is
      // using, so a remote control has nothing to act on.
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      await harness.controller.setReceiverVolume(0.5);
      await pumpEventQueue();

      expect(harness.gateway.commands, isEmpty);
    });

    test('a command changes nothing here, however it turns out', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      await harness.controller.setReceiverPlaying(false);
      await pumpEventQueue();

      // Nothing is applied optimistically: what the Receiver is doing is what it reports, and
      // this phone is still holding no player of its own either way.
      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(harness.controller.state.ownsLocalPlayer, isFalse);
      expect(harness.controller.state.castFailureReason, isNull);
    });

    test('a refused command leaves Remote Control Mode exactly as it was',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.commandFailure = Exception(
        "An unexpected error occurred invoking 'SendCastCommand' on the "
        'server. HubException: sessionNotActive',
      );

      await harness.controller.setReceiverPlaying(false);
      await pumpEventQueue();

      // The Receiver is still playing, so dragging playback back to the phone because one
      // command did not land would be worse than the command not landing.
      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(harness.controller.state.sessionId, 'session-1');
      expect(
        harness.controller.state.castFailureReason,
        CastErrorReason.sessionNotActive,
      );
    });

    test('a command refused because the session is gone ends Remote Control '
        'Mode', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      // What an API that was restarted answers: there is no Receiver to command any more.
      harness.gateway.commandFailure = Exception(
        "An unexpected error occurred invoking 'SendCastCommand' on the "
        'server. HubException: sessionNotFound',
      );

      await harness.controller.seekReceiver(const Duration(minutes: 1));
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.controller.state.sessionId, isNull);
      expect(
        harness.controller.state.castFailureReason,
        CastErrorReason.sessionNotFound,
      );
      // There is no Receiver to command any more, so the phone continues from the last state it
      // was told about rather than simply stopping.
      expect(
        harness.playbackEndpoint.resumes.single.position,
        const Duration(seconds: 30),
      );
    });

    test('a command that lands clears an earlier failure', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.commandFailure = Exception('HubException: somethingNewer');
      await harness.controller.setReceiverPlaying(false);
      await pumpEventQueue();
      expect(harness.controller.state.castFailureReason, isNotNull);

      harness.gateway.commandFailure = null;
      await harness.controller.setReceiverPlaying(true);
      await pumpEventQueue();

      expect(harness.controller.state.castFailureReason, isNull);
    });

    test('a Handoff never sends this phone player volume to the Receiver',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      // This phone is playing loud, and the Receiver stands in a room with different acoustics
      // and is quiet. The two values are deliberately different, so a Handoff that copied one
      // onto the other would be visible here.
      harness.playbackEndpoint.playback = const CastLocalPlayback(
        videoId: 42,
        position: Duration(seconds: 12),
        isPlaying: true,
        volume: 0.9,
      );

      await _castThrough(harness);
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(seconds: 30),
        isPlaying: true,
        volume: 0.3,
      );
      await pumpEventQueue();

      // The Handoff carried the position and the playing intent. A volume command is the one way
      // this phone can write the Receiver's player volume at all, and a Handoff sends none.
      expect(harness.gateway.commits, hasLength(1));
      expect(
        harness.gateway.commands.where(
          (FakeCastCommand command) =>
              command.type == CastCommandType.setVolume,
        ),
        isEmpty,
      );
      // So the Receiver is still at its own volume, and that - not this phone's - is what the
      // phone shows.
      expect(harness.controller.state.confirmedState?.volume, 0.3);
    });
  });

  // --- Playback Authority ---------------------------------------------------------------
  // The Receiver is the only device playing, so what it reports is the only thing this phone may
  // render. There is deliberately no optimistic seek and no optimistic volume: the phone is allowed
  // to lag by the reporting interval rather than show a command that failed to apply.

  group('Playback Authority', () {
    test('the phone renders the whole state the Receiver confirms', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 3),
        isPlaying: false,
        duration: const Duration(minutes: 45),
        isBuffering: true,
        volume: 0.3,
        lastAppliedSeq: 4,
      );
      await pumpEventQueue();

      final CastPlaybackState state = harness.controller.state.confirmedState!;
      expect(state.videoId, 42);
      expect(state.position, const Duration(minutes: 3));
      expect(state.duration, const Duration(minutes: 45));
      expect(state.isPlaying, isFalse);
      expect(state.isBuffering, isTrue);
      expect(state.isCompleted, isFalse);
      expect(state.volume, 0.3);
      expect(state.lastAppliedSeq, 4);
    });

    test('Remote Control Mode begins with the state the Receiver confirmed',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      expect(harness.controller.state.confirmedState, isNull);
      await _castThrough(harness);

      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(
        harness.controller.state.confirmedState?.position,
        const Duration(seconds: 30),
      );
    });

    test('a seek does not move the phone until the Receiver confirms it',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      final CastPlaybackState? before = harness.controller.state.confirmedState;

      await harness.controller.seekReceiver(const Duration(minutes: 12));
      await pumpEventQueue();

      // The command went out, and the phone still shows where the Receiver actually is.
      expect(
        harness.gateway.commands.single.position,
        const Duration(minutes: 12),
      );
      expect(harness.controller.state.confirmedState, before);
      expect(
        harness.controller.state.confirmedState?.position,
        const Duration(seconds: 30),
      );

      // It moves when the Receiver says it has, and not before.
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 12),
        lastAppliedSeq: 1,
      );
      await pumpEventQueue();

      expect(
        harness.controller.state.confirmedState?.position,
        const Duration(minutes: 12),
      );
      expect(harness.controller.state.confirmedState?.lastAppliedSeq, 1);
    });

    test('a volume change does not move the phone until the Receiver confirms it',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      await harness.controller.setReceiverVolume(0.1);
      await pumpEventQueue();

      expect(harness.gateway.commands.single.volume, 0.1);
      expect(harness.controller.state.confirmedState?.volume, 1.0);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(seconds: 30),
        volume: 0.1,
        lastAppliedSeq: 1,
      );
      await pumpEventQueue();

      expect(harness.controller.state.confirmedState?.volume, 0.1);
    });

    test('a pause does not move the phone until the Receiver confirms it',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      await harness.controller.setReceiverPlaying(false);
      await pumpEventQueue();

      expect(harness.controller.state.confirmedState?.isPlaying, isTrue);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(seconds: 30),
        isPlaying: false,
        lastAppliedSeq: 1,
      );
      await pumpEventQueue();

      expect(harness.controller.state.confirmedState?.isPlaying, isFalse);
    });

    test('a refused command leaves the confirmed state where it was', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      final CastPlaybackState? before = harness.controller.state.confirmedState;

      harness.gateway.commandFailure =
          Exception('HubException: notSessionController');
      await harness.controller.seekReceiver(const Duration(minutes: 40));
      await harness.controller.setReceiverVolume(0);
      await pumpEventQueue();

      // A command that never happened must not show up as having happened.
      expect(harness.controller.state.confirmedState, before);
      expect(harness.controller.state.castFailureReason, isNotNull);
    });

    test('a change made at the television reaches the phone with no command behind it',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      // Somebody in the room used the Receiver's own remote.
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 8),
        isPlaying: false,
        volume: 0.2,
      );
      await pumpEventQueue();

      expect(
        harness.controller.state.confirmedState?.position,
        const Duration(minutes: 8),
      );
      expect(harness.controller.state.confirmedState?.isPlaying, isFalse);
      expect(harness.controller.state.confirmedState?.volume, 0.2);
      expect(harness.controller.state.confirmedState?.lastAppliedSeq, 0);
      expect(harness.gateway.commands, isEmpty);
    });

    test('a completed video is shown as completed without leaving cast state',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 30),
        isPlaying: false,
        duration: const Duration(minutes: 30),
        isCompleted: true,
      );
      await pumpEventQueue();

      expect(harness.controller.state.confirmedState?.isCompleted, isTrue);
      expect(harness.controller.state.isRemoteControlMode, isTrue);
    });

    test('the confirmed state goes when the Cast Session does', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      expect(harness.controller.state.confirmedState, isNotNull);

      harness.gateway.emitSessionEnded();
      await pumpEventQueue();

      expect(harness.controller.state.confirmedState, isNull);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
    });
  });

  group('Backing out of a Handoff', () {
    test('the preparing state keeps local playback and can be backed out of',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      expect(harness.controller.state.isPreparingHandoff, isTrue);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);

      await harness.controller.cancelCast();
      await pumpEventQueue();

      expect(harness.gateway.cancels, <String>['session-1']);
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.sessionId, isNull);
      // Backing out is not a failure: the viewer got what they asked for.
      expect(harness.controller.state.castFailureReason, isNull);

      // Nothing had been taken away from the phone, so there is nothing to give back.
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
      expect(harness.playbackEndpoint.playback, isNotNull);
      expect(harness.gateway.commits, isEmpty);
    });

    test('a Handoff that was backed out of is never committed, however late '
        'the television finishes preparing', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      await harness.controller.cancelCast();
      await pumpEventQueue();

      // The Receiver says it is ready, in a push that was already on its way.
      harness.gateway.emitSession(
        castSession(sessionId: 'session-1', isReceiverPrepared: true),
      );
      await pumpEventQueue();

      expect(harness.gateway.commits, isEmpty);
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
    });

    // The minute itself is the API's and is pinned there, by
    // `Preparation_that_does_not_finish_within_a_minute_expires` in
    // `src/Api.IntegrationTests/CastSessionTests.cs`, against an injected clock. This phone owns
    // no such clock: what reaches it is the API saying the Handoff expired, and what it has to do
    // with that is all this can pin.
    test('a Handoff the API reports as expired leaves the phone on local '
        'playback', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      expect(harness.controller.state.isPreparingHandoff, isTrue);

      harness.gateway.emitSessionEnded(reason: CastEndReason.handoffExpired);
      await pumpEventQueue();

      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.sessionId, isNull);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
      expect(harness.playbackEndpoint.playback, isNotNull);
      expect(harness.gateway.commits, isEmpty);
    });

    test('backing out before the API has answered the start still ends the '
        'session it hands back', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      // Both calls are made before anything is awaited, so the cancel happens while the start is
      // still in flight and there is no session to name yet.
      final Future<void> starting = harness.controller.startCast(videoId: 42);
      final Future<void> backingOut = harness.controller.cancelCast();
      await starting;
      await backingOut;
      await pumpEventQueue();

      expect(harness.gateway.starts, hasLength(1));
      expect(harness.gateway.cancels, <String>['session-1']);
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
      expect(harness.gateway.commits, isEmpty);
    });

    test('a cast can be started again straight after backing out of one',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      await harness.controller.cancelCast();
      await pumpEventQueue();

      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(harness.gateway.starts, hasLength(2));
      expect(harness.controller.state.isPreparingHandoff, isTrue);
      expect(harness.controller.state.sessionId, 'session-2');
    });

    test('news about the Handoff left behind cannot end the next one',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      await harness.controller.cancelCast();
      await pumpEventQueue();
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      expect(harness.controller.state.sessionId, 'session-2');

      // The API's word that the first Handoff is over, arriving late.
      harness.gateway.emitSession(
        castSession(
          sessionId: 'session-1',
          status: CastSessionStatus.ended,
          endReason: CastEndReason.handoffExpired,
        ),
      );
      await pumpEventQueue();

      expect(harness.controller.state.isPreparingHandoff, isTrue);
      expect(harness.controller.state.sessionId, 'session-2');
    });

    test('a Handoff that reached the television is not backed out of',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      expect(harness.controller.state.isRemoteControlMode, isTrue);

      await harness.controller.cancelCast();
      await pumpEventQueue();

      // Stopping a Receiver that is playing is Return Handoff, not a cancel.
      expect(harness.gateway.cancels, isEmpty);
      expect(harness.controller.state.isRemoteControlMode, isTrue);
    });

    test('a cancel the API refuses still leaves the phone on local playback',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      // What the API answers when the Handoff had already run out of time.
      harness.gateway.cancelFailure = Exception(
        "An unexpected error occurred invoking 'CancelCastSession' on the "
        'server. HubException: sessionNotFound',
      );

      await harness.controller.cancelCast();
      await pumpEventQueue();

      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
      // The viewer asked to stop casting and did; there is nothing to report as a failure.
      expect(harness.controller.state.castFailureReason, isNull);
    });
  });

  // --- Return Handoff -------------------------------------------------------------------------
  // Playback comes home the same way it left. The Receiver stops, the session ends, and this
  // phone continues from the last position the Receiver confirmed - the only position the two
  // devices ever agreed on.

  group('Return Handoff', () {
    test('playback comes back to the phone at the last confirmed position',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      // The video has moved on at the Receiver since the Handoff committed.
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 10, seconds: 15),
        duration: const Duration(minutes: 45),
      );
      await pumpEventQueue();

      await harness.controller.returnHandoff();
      await pumpEventQueue();

      expect(harness.gateway.returns, <String>['session-1']);
      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.controller.state.sessionId, isNull);
      expect(harness.controller.state.confirmedState, isNull);
      expect(harness.controller.state.castFailureReason, isNull);

      final FakeCastResume resumed = harness.playbackEndpoint.resumes.single;
      expect(resumed.videoId, 42);
      expect(resumed.position, const Duration(minutes: 10, seconds: 15));
      expect(resumed.isPlaying, isTrue);
    });

    test('a video that had reached its end is not started again', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 30),
        isPlaying: false,
        duration: const Duration(minutes: 30),
        isCompleted: true,
      );
      await pumpEventQueue();

      await harness.controller.returnHandoff();
      await pumpEventQueue();

      // Completed media stays completed: the phone picks the video up where it finished rather
      // than starting it again.
      final FakeCastResume resumed = harness.playbackEndpoint.resumes.single;
      expect(resumed.position, const Duration(minutes: 30));
      expect(resumed.isPlaying, isFalse);
    });

    test('there is nothing to bring back before the television is playing',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      await harness.controller.returnHandoff();
      await pumpEventQueue();

      // Nothing was ever taken away from this phone, so dropping this Handoff is a cancel.
      expect(harness.gateway.returns, isEmpty);
      expect(harness.playbackEndpoint.resumes, isEmpty);
      expect(harness.controller.state.isPreparingHandoff, isTrue);
    });

    test('a Return Handoff the API refuses still brings playback back here',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      // What the API answers when the session had already ended for another reason.
      harness.gateway.returnHandoffFailure = Exception(
        "An unexpected error occurred invoking 'ReturnCastHandoff' on the "
        'server. HubException: sessionNotFound',
      );

      await harness.controller.returnHandoff();
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(
        harness.playbackEndpoint.resumes.single.position,
        const Duration(seconds: 30),
      );
      // The viewer asked to watch here and is; there is nothing to report as a failure.
      expect(harness.controller.state.castFailureReason, isNull);
    });

    test('a cast can be started again straight after a Return Handoff',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      await harness.controller.returnHandoff();
      await pumpEventQueue();
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      expect(harness.gateway.starts, hasLength(2));
      expect(harness.controller.state.isPreparingHandoff, isTrue);
      expect(harness.controller.state.sessionId, 'session-2');
    });
  });

  group('Reconnect window', () {
    test('a television inside its minute keeps Remote Control Mode and says so',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      expect(harness.controller.state.isSessionReconnecting, isFalse);

      harness.gateway.emitParticipantReconnecting();
      await pumpEventQueue();

      // Nothing is taken away for a minute of waiting: the session is still this phone's, and what
      // the Receiver last confirmed is still the truth about the video.
      expect(harness.controller.state.isSessionReconnecting, isTrue);
      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(harness.controller.state.ownsLocalPlayer, isFalse);
      expect(harness.controller.state.sessionId, 'session-1');
      expect(
        harness.controller.state.confirmedState?.position,
        const Duration(seconds: 30),
      );
      expect(harness.playbackEndpoint.resumes, isEmpty);
    });

    test('a television that comes back is ordinary Remote Control Mode again',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitParticipantReconnecting();
      await pumpEventQueue();
      expect(harness.controller.state.isSessionReconnecting, isTrue);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(seconds: 45),
        isPlaying: true,
      );
      await pumpEventQueue();

      expect(harness.controller.state.isSessionReconnecting, isFalse);
      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(
        harness.controller.state.confirmedState?.position,
        const Duration(seconds: 45),
      );
    });

    test('the viewer can stop waiting and bring playback back here', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 4),
        duration: const Duration(minutes: 45),
      );
      await pumpEventQueue();
      harness.gateway.emitParticipantReconnecting();
      await pumpEventQueue();

      await harness.controller.returnHandoff();
      await pumpEventQueue();

      // The same request as always, answered the same way: the Receiver stops and playback
      // continues here from the last position both devices agreed on.
      expect(harness.gateway.returns, <String>['session-1']);
      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.isSessionReconnecting, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(
        harness.playbackEndpoint.resumes.single.position,
        const Duration(minutes: 4),
      );
    });

    test('a television that drops off mid-Handoff does not take the local '
        'player away', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      // The Receiver's connection drops before it ever confirmed a state. Remote Control Mode is
      // reached by that confirmation and by nothing else, so the viewer keeps watching here.
      harness.gateway.emitParticipantReconnecting();
      await pumpEventQueue();

      expect(harness.controller.state.isPreparingHandoff, isTrue);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
      expect(harness.gateway.commits, isEmpty);
    });

    test('a participant that never came back puts the phone back on local '
        'playback', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      harness.gateway.emitParticipantReconnecting();
      await pumpEventQueue();

      harness.gateway.emitSessionEnded(
        reason: CastEndReason.participantTimeout,
      );
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.isSessionReconnecting, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.controller.state.sessionId, isNull);
    });

    test('a television lost for the whole minute resumes the phone where it '
        'left off', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      // The Receiver got a good way into the video before its connection went.
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 9),
        isPlaying: true,
      );
      await pumpEventQueue();
      harness.gateway.emitParticipantReconnecting();
      await pumpEventQueue();
      harness.gateway.emitSessionEnded(
        reason: CastEndReason.participantTimeout,
      );
      await pumpEventQueue();

      expect(harness.playbackEndpoint.resumes, hasLength(1));
      expect(harness.playbackEndpoint.resumes.single.videoId, 42);
      expect(
        harness.playbackEndpoint.resumes.single.position,
        const Duration(minutes: 9),
      );
      expect(harness.playbackEndpoint.resumes.single.isPlaying, isTrue);
    });
  });

  // Leaving Remote Control Mode is leaving it at a position, so the phone picks playback back up
  // from the last state the Receiver confirmed. The end reason changes almost nothing about that:
  // the Receiver has stopped, and this phone is the only device left that can show the video.
  group('Every way a Cast Session ends', () {
    test('the television leaving the cast video brings playback back here',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 3),
        isPlaying: true,
      );
      await pumpEventQueue();

      harness.gateway.emitSessionEnded(
        reason: CastEndReason.receiverNavigatedAway,
      );
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(
        harness.playbackEndpoint.resumes.single.position,
        const Duration(minutes: 3),
      );
      expect(harness.playbackEndpoint.resumes.single.isPlaying, isTrue);
    });

    test('a video watched to the end is not started again here', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 30),
        isPlaying: false,
        duration: const Duration(minutes: 30),
        isCompleted: true,
      );
      await pumpEventQueue();

      harness.gateway.emitSessionEnded(
        reason: CastEndReason.playbackCompleted,
      );
      await pumpEventQueue();

      // Completed media stays completed. The phone owns its player again, at the end of the video,
      // paused.
      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.playbackEndpoint.resumes.single.isPlaying, isFalse);
      expect(
        harness.playbackEndpoint.resumes.single.position,
        const Duration(minutes: 30),
      );
    });

    test('signing out leaves playback alone', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitSessionEnded(
        reason: CastEndReason.participantSignedOut,
      );
      await pumpEventQueue();

      // The account is being put down on a device rather than playback being handed back to one,
      // so there is nothing here to pick up.
      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.resumes, isEmpty);
    });

    test('a reason this version does not know still brings playback back here',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitSessionEnded(reason: CastEndReason.unknown);
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.playbackEndpoint.resumes, hasLength(1));
    });

    test('a Handoff that ended before it committed has nothing to bring back',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      harness.gateway.emitSessionEnded(reason: CastEndReason.handoffExpired);
      await pumpEventQueue();

      // Local playback was never given up, so the viewer has been watching here all along.
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.resumes, isEmpty);
      expect(harness.playbackEndpoint.isReleased, isFalse);
    });

    test('a late word that the television is ready cannot re-commit a Handoff '
        'the API dropped', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      harness.gateway.emitSessionEnded(reason: CastEndReason.handoffExpired);
      await pumpEventQueue();
      expect(harness.controller.state.isPreparingHandoff, isFalse);

      // The Receiver saying it had finished loading, already on its way when the API gave up on
      // the Handoff. Leaving a session is leaving it however it ended, so this is ignored for the
      // same reason a backed-out Handoff's late news is: acting on it would put the phone back
      // through preparing only to have the commit refused for a session nobody has.
      harness.gateway.emitSession(
        castSession(sessionId: 'session-1', isReceiverPrepared: true),
      );
      await pumpEventQueue();

      expect(harness.gateway.commits, isEmpty);
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.sessionId, isNull);
      expect(harness.controller.state.ownsLocalPlayer, isTrue);
      expect(harness.playbackEndpoint.isReleased, isFalse);
    });

    test('a late report from a television the phone has stopped waiting for '
        'cannot take the local player away again', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitSessionEnded(
        reason: CastEndReason.participantTimeout,
      );
      await pumpEventQueue();
      expect(harness.controller.state.isRemoteControlMode, isFalse);

      // The Receiver's reporting cadence, arriving after the phone had already picked playback
      // back up here.
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 6),
        isPlaying: true,
      );
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.sessionId, isNull);
      expect(harness.controller.state.confirmedState, isNull);
      // The player the phone picked back up stays its own, and so does its watch history.
      expect(harness.playbackEndpoint.releaseCount, 1);
      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);
    });
  });

  // Cast Sessions live only in the API's memory, so a restarted API has none of them while this
  // phone is still holding a remote. Nothing arrives to say so - a phone in Remote Control Mode is
  // waiting to be told things rather than asking - so the session it believes in is checked each
  // time the connection comes back.
  group('A restarted API', () {
    test('a session the API no longer has ends Remote Control Mode', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      harness.gateway.emitReceiverConfirmed(
        position: const Duration(minutes: 7),
        isPlaying: true,
      );
      await pumpEventQueue();

      await _reconnect(harness);

      expect(harness.gateway.resolves, <String>['session-1']);
      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.sessionId, isNull);
      expect(
        harness.playbackEndpoint.resumes.single.position,
        const Duration(minutes: 7),
      );
    });

    test('a session the API still has keeps Remote Control Mode', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.resolvedSession = castSession(
        status: CastSessionStatus.active,
        isReceiverPrepared: true,
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(minutes: 2),
          isPlaying: true,
        ),
      );
      await _reconnect(harness);

      expect(harness.gateway.resolves, <String>['session-1']);
      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(
        harness.controller.state.confirmedState?.position,
        const Duration(minutes: 2),
      );
      expect(harness.playbackEndpoint.resumes, isEmpty);
    });

    test('a question that could not be asked keeps the remote', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.resolveFailure = StateError('the connection is down');
      await _reconnect(harness);

      // Dropping the remote over a failed call would be ending sessions because of a bad
      // connection. It is asked again the next time the connection comes back.
      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(harness.playbackEndpoint.resumes, isEmpty);

      harness.gateway.resolveFailure = null;
      await _reconnect(harness);

      expect(harness.gateway.resolves, hasLength(2));
      expect(harness.controller.state.isRemoteControlMode, isFalse);
    });

    test('a phone in no Cast Session has nothing to ask about', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      await _reconnect(harness);

      expect(harness.gateway.resolves, isEmpty);
    });

    test('a session this device is only the Receiver of is not a remote to '
        'hold', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      // Both halves of a Cast Session hear the same messages. This one is being played here and
      // controlled from somewhere else, so it is not this device's Remote Control Mode - and
      // reading it as one would give up the very player it is about.
      harness.gateway.emitSession(
        castSession(
          status: CastSessionStatus.active,
          controllerDeviceId: 'some-other-phone',
          receiverDeviceId: 'device-1',
          isReceiverPrepared: true,
          confirmedState: const CastPlaybackState(
            videoId: 42,
            position: Duration(minutes: 5),
            isPlaying: true,
          ),
        ),
      );
      await pumpEventQueue();

      expect(harness.controller.state.isRemoteControlMode, isFalse);
      expect(harness.controller.state.isPreparingHandoff, isFalse);
      expect(harness.controller.state.sessionId, isNull);
      expect(harness.playbackEndpoint.isReleased, isFalse);
      expect(harness.gateway.commits, isEmpty);
    });
  });

  // Watch history follows the device that is actually playing. The Receiver plays the cast video
  // through the ordinary player, so its progress travels the app's ordinary playback-progress path
  // without anything here having to send it; what this phone does is stop writing its own for
  // exactly as long as that is true, and start again the moment it stops being true.
  group('Progress-write ownership', () {
    test('the phone writes its own progress while it is the device playing',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);

      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();
      harness.gateway.emitReceiverPrepared();
      await pumpEventQueue();

      // A Handoff being prepared changes nothing about local playback, so the viewer is still
      // watching here and this is still the device whose progress counts.
      expect(harness.controller.state.isPreparingHandoff, isTrue);
      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);
      expect(harness.progressWriteOwnership.handovers, isEmpty);
    });

    test('the phone writes no progress once the Receiver is playing', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      expect(harness.controller.state.isRemoteControlMode, isTrue);
      expect(harness.progressWriteOwnership.isReceiverOwned, isTrue);
    });

    test('progress writing is given to the Receiver before the phone gives up '
        'its player', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      // Giving up the local player saves a position. Handing progress writing over afterwards would
      // let that stale position through, which is the very thing this exists to prevent.
      expect(
        harness.journal,
        <String>['progress-writes:receiver', 'release'],
      );
    });

    test('a Return Handoff brings progress writing back to the phone',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      await harness.controller.returnHandoff();
      await pumpEventQueue();

      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);
      // Back before playback picks up here, so the first position the returning player writes is
      // kept rather than dropped.
      expect(
        harness.journal,
        <String>[
          'progress-writes:receiver',
          'release',
          'progress-writes:phone',
          'resume:42',
        ],
      );
    });

    test('a television lost for the whole minute brings progress writing back '
        'to the phone', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);

      harness.gateway.emitParticipantReconnecting();
      await pumpEventQueue();

      // Inside its minute the Receiver is still the device playing, so it is still the device
      // whose progress counts.
      expect(harness.progressWriteOwnership.isReceiverOwned, isTrue);

      harness.gateway.emitSessionEnded(
        reason: CastEndReason.participantTimeout,
      );
      await pumpEventQueue();

      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);
      expect(harness.playbackEndpoint.resumes, hasLength(1));
    });

    test('every way a Cast Session ends brings progress writing back to the '
        'phone', () async {
      for (final CastEndReason reason in <CastEndReason>[
        CastEndReason.returnHandoff,
        CastEndReason.receiverNavigatedAway,
        CastEndReason.playbackCompleted,
        CastEndReason.participantTimeout,
        CastEndReason.participantSignedOut,
        CastEndReason.sessionMissing,
        CastEndReason.unknown,
      ]) {
        final _CastHarness harness = await _startWithSelectedReceiver(
          playing: const Duration(seconds: 12),
        );
        await _castThrough(harness);
        expect(
          harness.progressWriteOwnership.isReceiverOwned,
          isTrue,
          reason: 'before an end for $reason',
        );

        harness.gateway.emitSessionEnded(reason: reason);
        await pumpEventQueue();

        // Signing out is the one end that does not continue playback here, and even it gives
        // progress writing back: a device that goes on running must not be left silently keeping
        // no watch history at all.
        expect(
          harness.progressWriteOwnership.isReceiverOwned,
          isFalse,
          reason: 'after an end for $reason',
        );
      }
    });

    test('a Handoff that was backed out of never took progress writing away',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await harness.controller.startCast(videoId: 42);
      await pumpEventQueue();

      await harness.controller.cancelCast();
      await pumpEventQueue();

      // The Receiver never played anything, so the viewer has been watching here throughout.
      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);
      expect(harness.journal, isNot(contains('progress-writes:receiver')));
    });

    test('a Cast Controller that is disposed leaves progress writing with the '
        'phone', () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );
      await _castThrough(harness);
      expect(harness.progressWriteOwnership.isReceiverOwned, isTrue);

      await harness.dispose();

      // Nothing is left that could end the Cast Session, so nothing would be left to bring progress
      // writing back either.
      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);
    });

    test('a television being cast to goes on writing its own progress',
        () async {
      final _CastHarness harness = await _startWithSelectedReceiver(
        playing: const Duration(seconds: 12),
      );

      // Both halves of a Cast Session hear the same messages. This one is being played here and
      // controlled from somewhere else: this device is the Receiver, and the Receiver is exactly
      // the device whose progress the session keeps.
      harness.gateway.emitSession(
        castSession(
          status: CastSessionStatus.active,
          controllerDeviceId: 'some-other-phone',
          receiverDeviceId: 'device-1',
          isReceiverPrepared: true,
          confirmedState: const CastPlaybackState(
            videoId: 42,
            position: Duration(minutes: 5),
            isPlaying: true,
          ),
        ),
      );
      await pumpEventQueue();

      expect(harness.progressWriteOwnership.isReceiverOwned, isFalse);
      expect(harness.progressWriteOwnership.handovers, isEmpty);
    });
  });
}

/// A connection that came back, and the account's device list arriving with it.
///
/// The list is what the API answers a registration with, so hearing one is the first moment a phone
/// is allowed to ask about a session: that is the order the real gateway produces and the order the
/// phone relies on.
Future<void> _reconnect(_CastHarness harness) async {
  harness.gateway.emitConnectionState(SyncConnectionState.reconnecting);
  await pumpEventQueue();
  harness.gateway.emitConnectionState(SyncConnectionState.connected);
  await pumpEventQueue();
  harness.gateway.emitDevices(<CastDevice>[
    castDevice(deviceId: 'tv-2', name: 'Living room'),
  ]);
  await pumpEventQueue();
}

/// A harness with one online Receiver picked and something playing locally, which is the state a
/// viewer is in when they press cast.
Future<_CastHarness> _startWithSelectedReceiver({
  required Duration playing,
  bool isPlaying = true,
}) async {
  final _CastHarness harness = await _CastHarness.start(
    playback: CastLocalPlayback(
      videoId: 42,
      position: playing,
      isPlaying: isPlaying,
    ),
  );

  harness.gateway.emitDevices(<CastDevice>[
    castDevice(deviceId: 'tv-2', name: 'Living room'),
  ]);
  harness.gateway.emitConnectionState(SyncConnectionState.connected);
  await pumpEventQueue();
  await harness.controller.selectReceiver('tv-2');

  return harness;
}

/// A whole Handoff: start, the Receiver loads, the phone commits, the Receiver confirms.
Future<void> _castThrough(_CastHarness harness) async {
  await harness.controller.startCast(videoId: 42);
  await pumpEventQueue();
  harness.gateway.emitReceiverPrepared();
  await pumpEventQueue();
  harness.gateway.emitReceiverConfirmed(
    position: const Duration(seconds: 30),
    isPlaying: true,
  );
  await pumpEventQueue();
}

/// A Cast Controller over a fake API connection, in-memory settings and the real registration
/// service, so a test drives exactly what the phone drives.
class _CastHarness {
  _CastHarness({
    required this.gateway,
    required this.settingsRepository,
    required this.registrationService,
    required this.playbackEndpoint,
    required this.progressWriteOwnership,
    required this.journal,
    required this.controller,
  });

  static Future<_CastHarness> start({
    CastSettings settings = CastSettings.defaults,
    String model = 'Pixel Tablet',
    String deviceId = 'device-1',
    CastLocalPlayback? playback,
  }) async {
    final FakeCastGateway gateway = FakeCastGateway();
    final InMemoryCastSettingsRepository settingsRepository =
        InMemoryCastSettingsRepository(settings);
    final CastRegistrationService registrationService =
        CastRegistrationService(
      gateway: gateway,
      identityService: CastDeviceIdentityService(
        identityRepository: FixedCastDeviceIdentityRepository(deviceId),
        deviceModelSource: FakeDeviceModelSource(model),
      ),
      settingsRepository: settingsRepository,
      logService: NoopLogService(),
    );
    await registrationService.initialize();

    // One journal for both, so the order between giving progress writing to the Receiver and giving
    // up the local player is a thing a test can read.
    final List<String> journal = <String>[];
    final FakeCastPlaybackEndpoint playbackEndpoint =
        FakeCastPlaybackEndpoint(playback: playback, journal: journal);
    final RecordingCastProgressWriteOwnership progressWriteOwnership =
        RecordingCastProgressWriteOwnership(journal: journal);
    final CastController controller = CastController(
      gateway: gateway,
      settingsRepository: settingsRepository,
      registrationService: registrationService,
      playbackEndpoint: playbackEndpoint,
      progressWriteOwnership: progressWriteOwnership,
      logService: NoopLogService(),
    );
    await controller.initialized;

    final _CastHarness harness = _CastHarness(
      gateway: gateway,
      settingsRepository: settingsRepository,
      registrationService: registrationService,
      playbackEndpoint: playbackEndpoint,
      progressWriteOwnership: progressWriteOwnership,
      journal: journal,
      controller: controller,
    );
    addTearDown(harness.dispose);
    return harness;
  }

  final FakeCastGateway gateway;
  final InMemoryCastSettingsRepository settingsRepository;
  final CastRegistrationService registrationService;
  final FakeCastPlaybackEndpoint playbackEndpoint;
  final RecordingCastProgressWriteOwnership progressWriteOwnership;

  /// What the phone did to local playback and to progress-write ownership, in order.
  final List<String> journal;
  final CastController controller;

  bool _isDisposed = false;

  /// Ends this harness. A test that wants to see what disposing the Cast Controller does calls it
  /// itself; the tear-down then finds it already done rather than disposing twice.
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    controller.dispose();
    await registrationService.dispose();
    await gateway.close();
  }
}
