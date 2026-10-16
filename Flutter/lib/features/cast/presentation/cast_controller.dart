import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../core/logging/log_service.dart';
import '../../sync/domain/sync_models.dart';
import '../data/cast_playback_binding.dart';
import '../data/cast_settings_repository.dart';
import '../domain/cast_device_identity_service.dart';
import '../domain/cast_device_labels.dart';
import '../domain/cast_gateway.dart';
import '../domain/cast_models.dart';
import '../domain/cast_playback_endpoint.dart';
import '../domain/cast_progress_write_ownership.dart';
import '../domain/cast_registration_service.dart';
import '../domain/cast_session_models.dart';
import '../domain/cast_settings.dart';

/// What this phone is doing about casting, as a surface shows it.
///
/// [remoteControl] is Remote Control Mode: a dedicated presentation state that owns no local video
/// player. It is reached only once the Receiver has confirmed the state it reached, which is what
/// keeps playback from disappearing from the phone before the Receiver is ready.
enum CastPhase {
  /// Nothing is being cast. The phone plays locally.
  idle,

  /// Handoff has started and the Receiver is loading. The phone is still playing.
  preparing,

  /// Remote Control Mode. Playback lives on the Receiver and this device owns no player.
  remoteControl,
}

/// What the Cast surfaces show: who this installation is, who it could cast to, which of them is
/// currently picked, and what the Cast Session it takes part in is doing.
class CastUiState {
  const CastUiState({
    required this.isReceiverMode,
    required this.deviceName,
    required this.deviceModel,
    required this.receivers,
    required this.selectedReceiverDeviceId,
    required this.connectionState,
    this.phase = CastPhase.idle,
    this.sessionId,
    this.castVideoId,
    this.castReceiverName,
    this.confirmedState,
    this.castFailureReason,
    this.isSessionReconnecting = false,
  });

  static const CastUiState initial = CastUiState(
    isReceiverMode: false,
    deviceName: '',
    deviceModel: '',
    receivers: <CastDeviceLabel>[],
    selectedReceiverDeviceId: null,
    connectionState: SyncConnectionState.disconnected,
  );

  /// Whether this installation offers itself as a Receiver.
  final bool isReceiverMode;

  /// The name this installation registers under: what the person chose, or the Android model while
  /// they have not chosen anything.
  final String deviceName;

  /// Android `Build.MODEL`, empty where the platform has none.
  final String deviceModel;

  /// The account's currently online Receivers, labelled so no two of them read the same, and
  /// without this installation itself - a device cannot cast to where it already is.
  final List<CastDeviceLabel> receivers;

  /// The picked Receiver, or `null` when none is picked. A remembered Receiver that is not online
  /// right now is not picked: it comes back by itself when it appears in a snapshot again.
  final String? selectedReceiverDeviceId;

  final SyncConnectionState connectionState;

  /// What this phone is doing about casting.
  final CastPhase phase;

  /// The Cast Session this phone takes part in, or `null` when it takes part in none.
  final String? sessionId;

  /// The video the Cast Session is about.
  final int? castVideoId;

  /// The Receiver's name, so Remote Control Mode can say where playback is even if that device has
  /// meanwhile dropped out of the list.
  final String? castReceiverName;

  /// What the Receiver says it is playing: Playback Authority, and the only thing Remote Control
  /// Mode may render. `null` until the Receiver has confirmed a state, and again once the session is
  /// over.
  ///
  /// It moves on the Receiver's word and on nothing else. Sending a command does not touch it, so a
  /// command the Receiver never applied never shows up as having happened: the phone is allowed to
  /// lag by the reporting interval rather than display something that did not occur.
  final CastPlaybackState? confirmedState;

  /// Why the last cast attempt did not happen, as one of the [CastErrorReason] values, or
  /// [CastErrorReason.unrecognised] for a refusal this version does not know. `null` when the last
  /// attempt did not fail.
  final String? castFailureReason;

  /// Whether a participant is inside its one-minute reconnect window.
  ///
  /// The session is still this device's and Remote Control Mode stays: the last state the Receiver
  /// confirmed is still the truth about the video, and the viewer who would rather not wait can ask
  /// for playback back here and now. It is the API that says so, like everything else about a
  /// session; this phone never infers it from its own connection.
  final bool isSessionReconnecting;

  bool get hasReceivers => receivers.isNotEmpty;

  /// Whether a Handoff is in flight. Local playback continues throughout.
  bool get isPreparingHandoff => phase == CastPhase.preparing;

  /// Remote Control Mode: playback is on the Receiver.
  bool get isRemoteControlMode => phase == CastPhase.remoteControl;

  /// Whether this device still owns a local video player. False exactly in Remote Control Mode.
  bool get ownsLocalPlayer => phase != CastPhase.remoteControl;

  /// Whether a cast can be started right now: something to cast to, and nothing in flight.
  bool get canStartCast =>
      phase == CastPhase.idle && selectedReceiver != null;

  CastDeviceLabel? get selectedReceiver {
    final String? deviceId = selectedReceiverDeviceId;
    if (deviceId == null) {
      return null;
    }
    for (final CastDeviceLabel receiver in receivers) {
      if (receiver.deviceId == deviceId) {
        return receiver;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! CastUiState ||
        other.isReceiverMode != isReceiverMode ||
        other.deviceName != deviceName ||
        other.deviceModel != deviceModel ||
        other.selectedReceiverDeviceId != selectedReceiverDeviceId ||
        other.connectionState != connectionState ||
        other.phase != phase ||
        other.sessionId != sessionId ||
        other.castVideoId != castVideoId ||
        other.castReceiverName != castReceiverName ||
        other.confirmedState != confirmedState ||
        other.castFailureReason != castFailureReason ||
        other.isSessionReconnecting != isSessionReconnecting ||
        other.receivers.length != receivers.length) {
      return false;
    }
    for (int index = 0; index < receivers.length; index++) {
      if (other.receivers[index] != receivers[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        isReceiverMode,
        deviceName,
        deviceModel,
        selectedReceiverDeviceId,
        connectionState,
        phase,
        sessionId,
        castVideoId,
        castReceiverName,
        confirmedState,
        castFailureReason,
        isSessionReconnecting,
        Object.hashAll(receivers),
      );
}

/// The Cast Session's public surface on the phone.
///
/// It owns the persisted choices - Receiver Mode, this installation's name and the last selected
/// Receiver - turns the API's authoritative snapshots into the list a viewer picks from, and runs
/// Handoff.
///
/// Handoff has two phases and this is where the order between them is kept. Starting a cast asks
/// the Receiver to load the video and changes nothing about local playback, so the phone keeps
/// playing. Only when the Receiver says it is loaded does the phone read where it has got to by now
/// and commit that position, so a slow Receiver cannot send the viewer backwards. Only when the
/// Receiver confirms the state it actually reached does the phone release its local player and
/// enter Remote Control Mode.
///
/// A Handoff that is taking too long can be backed out of, and the API drops one that has not
/// finished within a minute. Both are cheap precisely because of that order: nothing had been taken
/// away from the phone yet, so the viewer simply carries on watching where they were.
///
/// Playback comes home the same way it left. A Return Handoff stops the Receiver and continues
/// here from the Receiver's last confirmed position, which is the only position the two devices
/// ever agreed on.
///
/// A connection that drops does not end any of this. Either device has a minute to come back, and
/// the API says so by reporting the session as reconnecting: Remote Control Mode stays, the last
/// confirmed state stays, and a viewer who would rather not wait the minute out asks for playback
/// back exactly as they always would. Coming back is the registration this installation sends on
/// every connect, under the stable identity it has always had, so nothing here has to ask for its
/// session again.
///
/// A session that ends, for any reason including one this version does not recognise, puts the
/// phone back on local playback. There is no state in which it is stuck holding a remote for a
/// Receiver that is no longer playing.
///
/// Watch history follows the device that is actually playing, so it follows the Receiver too.
/// While the Receiver is playing it is the device whose progress is kept, and this phone writes
/// none: the only position it has is where the viewer was when the Receiver took over, and
/// writing that would overwrite the Receiver's with something staler. It writes its own progress
/// again from the moment the Cast Session ends, whatever ended it.
///
/// Leaving Remote Control Mode is also leaving it at a position, so playback is picked back up here
/// from the last state the Receiver confirmed - the only place either device ever agreed playback
/// was. That is the same thing whether the viewer asked for it back, the Receiver was lost for a
/// whole minute, somebody at the Receiver left the video, or the API forgot the session
/// altogether. A video that had reached its end is the one thing that is not started again, and
/// signing out is the one end that is not a request to go on watching here.
///
/// Sessions live only in the API's memory, so a restarted API has none of them while this phone is
/// still holding a remote. Nothing would arrive to say so, which is why the session this phone
/// believes in is checked against the API each time the connection comes back.
class CastController extends StateNotifier<CastUiState> {
  CastController({
    required CastGateway gateway,
    required CastSettingsRepository settingsRepository,
    required CastRegistrationService registrationService,
    required CastPlaybackEndpoint playbackEndpoint,
    required CastProgressWriteOwnership progressWriteOwnership,
    required LogService logService,
  })  : _gateway = gateway,
        _settingsRepository = settingsRepository,
        _registrationService = registrationService,
        _playbackEndpoint = playbackEndpoint,
        _progressWriteOwnership = progressWriteOwnership,
        _logService = logService,
        super(CastUiState.initial) {
    _devicesSubscription = _gateway.watchDevices().listen(_onDevices);
    _connectionSubscription =
        _gateway.watchConnectionState().listen(_onConnectionState);
    _registrationSubscription =
        _registrationService.watchRegistration().listen(_onRegistration);
    _sessionSubscription = _gateway.watchSession().listen(_onSession);
    _initialized = _initialize();
  }

  final CastGateway _gateway;
  final CastSettingsRepository _settingsRepository;
  final CastRegistrationService _registrationService;
  final CastPlaybackEndpoint _playbackEndpoint;
  final CastProgressWriteOwnership _progressWriteOwnership;
  final LogService _logService;

  StreamSubscription<CastDevicesSnapshot>? _devicesSubscription;
  StreamSubscription<SyncConnectionState>? _connectionSubscription;
  StreamSubscription<CastDeviceRegistration>? _registrationSubscription;
  StreamSubscription<CastSession>? _sessionSubscription;

  late final Future<void> _initialized;

  CastDevicesSnapshot _snapshot = CastDevicesSnapshot.empty;
  SyncConnectionState _connectionState = SyncConnectionState.disconnected;
  String _ownDeviceId = '';
  String _deviceModel = '';
  String _preferredName = '';
  String _deviceName = '';
  bool _isReceiverMode = false;
  String? _rememberedReceiverDeviceId;
  bool _hasRegistration = false;

  CastPhase _phase = CastPhase.idle;
  String? _sessionId;
  int? _castVideoId;
  String? _castReceiverName;

  /// Whether the API says a participant is inside its reconnect window. Read from the session and
  /// from nowhere else, exactly like the confirmed state.
  bool _isSessionReconnecting = false;

  /// The Receiver's last confirmed playback state. It is written from the sessions the API reports
  /// and from nowhere else - in particular, never from a command this phone sent.
  CastPlaybackState? _confirmedState;
  String? _castFailureReason;

  /// The session whose commit has already been sent. A Handoff is committed once, however many
  /// times the API repeats that the Receiver is prepared.
  String? _committedSessionId;

  /// The Cast Session this phone has left. Anything the API still says about it was already on its
  /// way when the phone left, so it is ignored rather than allowed to put the phone back into
  /// preparing, commit a Handoff that is over, or take the local player away a second time.
  ///
  /// Every way of leaving records it, not only backing out of a Handoff. A Handoff the API dropped
  /// for taking too long, a participant that never came back, a Return Handoff and a session a
  /// restarted API no longer has all leave the same window open for a push that was already in
  /// flight, and a phone that acted on one would go back through preparing only to have the commit
  /// refused for a session nobody has.
  String? _leftSessionId;

  /// Set when the viewer backed out before the API had even answered the start, so there was no
  /// session to name yet. The one the answer carries is cancelled the moment it arrives.
  bool _cancelWhenStartIsAnswered = false;

  /// Whether a session this phone still believes in has yet to be checked against the API since
  /// the connection last came back.
  bool _shouldResolveSession = false;

  /// Completes once the persisted settings have been applied. The UI does not have to wait for it;
  /// a test that asserts on the first state does.
  Future<void> get initialized => _initialized;

  /// Turns Receiver Mode on or off on this installation and registers again, so the account's other
  /// devices see the new role without reconnecting.
  ///
  /// This is the only thing that decides the role. It is never inferred from the device.
  Future<void> setReceiverMode(bool isReceiverMode) async {
    final CastSettings settings =
        await _settingsRepository.setReceiverMode(isReceiverMode);
    if (!mounted) {
      return;
    }
    _isReceiverMode = settings.isReceiverMode;
    _rebuild();
    await _registrationService.refresh();
  }

  /// Renames this installation. A blank name puts the Android device model back in its place.
  Future<void> renameDevice(String name) async {
    final CastSettings settings =
        await _settingsRepository.setDeviceName(name);
    if (!mounted) {
      return;
    }
    _preferredName = settings.deviceName;
    _applyEffectiveName();
    _rebuild();
    await _registrationService.refresh();
  }

  /// Remembers the Receiver the person picked, or forgets it when given `null`.
  ///
  /// Picking never starts a cast: Handoff is a separate, explicit action.
  Future<void> selectReceiver(String? deviceId) async {
    final String trimmed = deviceId?.trim() ?? '';
    _rememberedReceiverDeviceId = trimmed.isEmpty ? null : trimmed;
    _rebuild();
    await _settingsRepository.setLastSelectedReceiver(
      _rememberedReceiverDeviceId,
    );
  }

  /// Starts Handoff of [videoId] to the picked Receiver: phase one.
  ///
  /// The Receiver is asked to load the video and nothing else happens. Local playback carries on
  /// untouched, which is the whole point of preparing before committing.
  ///
  /// Does nothing when no Receiver is picked or a cast is already under way. A refusal from the API
  /// leaves the phone exactly where it was, with [CastUiState.castFailureReason] saying why.
  Future<void> startCast({required int videoId}) async {
    if (_phase != CastPhase.idle || videoId <= 0) {
      return;
    }
    final CastDeviceLabel? receiver = state.selectedReceiver;
    if (receiver == null) {
      return;
    }

    _castFailureReason = null;
    _leftSessionId = null;
    _cancelWhenStartIsAnswered = false;
    _phase = CastPhase.preparing;
    _castVideoId = videoId;
    _castReceiverName = receiver.name;
    _rebuild();

    try {
      final CastSession session = await _gateway.startSession(
        receiverDeviceId: receiver.deviceId,
        videoId: videoId,
      );
      if (!mounted) {
        return;
      }
      if (_cancelWhenStartIsAnswered) {
        // The viewer backed out while this was in flight. The session exists on the server now, so
        // it is ended rather than left to hold the account for its whole minute.
        _cancelWhenStartIsAnswered = false;
        _leftSessionId = session.sessionId;
        await _cancelOnApi(session.sessionId);
        return;
      }
      await _applySession(session);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      if (_cancelWhenStartIsAnswered) {
        // The viewer had already backed out, so a start that also failed is not something they need
        // to be told about: they are exactly where they wanted to be.
        _cancelWhenStartIsAnswered = false;
        _logService.error(
          'CastController failed starting a Cast Session the viewer had backed out of',
          error,
          stackTrace,
        );
        return;
      }
      _failCast('starting a Cast Session', error, stackTrace);
    }
  }

  /// Backs out of a Handoff that is taking too long, leaving the viewer watching on the phone.
  ///
  /// Local playback was never given up, so there is nothing to restore and nothing to wait for: the
  /// phone leaves cast state at once and tells the API afterwards. Whatever the API answers - it may
  /// have run out of time by itself a moment earlier - the viewer keeps watching here.
  ///
  /// Does nothing once the Receiver is playing. Stopping that is Return Handoff, which brings
  /// playback back rather than dropping a Handoff that never happened.
  Future<void> cancelCast() async {
    if (_phase != CastPhase.preparing) {
      return;
    }

    final String? sessionId = _sessionId;
    // Leaving is what records the session as left behind, here exactly as everywhere else.
    _leaveCastState();

    if (sessionId == null) {
      // The API has not answered the start yet, so there is nothing to name. The session it is
      // about to hand back is cancelled as soon as it arrives.
      _cancelWhenStartIsAnswered = true;
      return;
    }

    await _cancelOnApi(sessionId);
  }

  /// Brings playback back to this phone: Return Handoff.
  ///
  /// The Receiver stops and this device continues from its last confirmed position -
  /// the only place either device ever agreed playback was. A video that had reached its end is not
  /// started again, because completed media stays completed.
  ///
  /// The phone leaves Remote Control Mode whatever the API answers. It is the viewer asking to
  /// watch here, and a session the server no longer has is exactly the outcome that was asked for,
  /// so a refusal is logged rather than shown as a failure.
  ///
  /// Does nothing outside Remote Control Mode. Dropping a Handoff the Receiver never took over is
  /// [cancelCast], which has nothing to bring back.
  Future<void> returnHandoff() async {
    final String? sessionId = _sessionId;
    if (_phase != CastPhase.remoteControl || sessionId == null) {
      return;
    }

    try {
      await _gateway.returnHandoff(sessionId: sessionId);
    } catch (error, stackTrace) {
      _logService.error(
        'CastController failed returning a Handoff',
        error,
        stackTrace,
      );
    }
    if (!mounted) {
      return;
    }

    await _endSession(CastEndReason.returnHandoff);
  }

  /// The one place the phone leaves a Cast Session that is over, whoever or whatever ended it.
  ///
  /// Leaving Remote Control Mode is leaving it at a position, so playback is picked back up here
  /// from the last state the Receiver confirmed. Every end reason means that: the viewer asked for
  /// playback back, the Receiver was lost for a whole minute, somebody at the Receiver left the
  /// video or watched it to the end, the API no longer has the session, or this version has never
  /// heard of the reason at all. In every one of them the Receiver has stopped and this phone is
  /// the only device left that can show the video.
  ///
  /// There are two exceptions, and both are about there being nothing to pick up. A Handoff that
  /// ended before it committed never took the local player away, so the viewer has been watching
  /// here all along. And signing out is the account being put down on this device rather than a
  /// request to go on watching: [CastPlaybackEndpoint.resume] would leave an intent behind for a
  /// player nobody is going to open.
  Future<void> _endSession(CastEndReason? reason) async {
    // Read before the session is left behind: leaving cast state forgets the confirmed state, and
    // that is the position playback continues from.
    final bool wasRemoteControl = _phase == CastPhase.remoteControl;
    final CastPlaybackState? confirmed = _confirmedState;
    _leaveCastState();

    if (!wasRemoteControl || reason == CastEndReason.participantSignedOut) {
      return;
    }
    await _resumeLocally(confirmed);
  }

  /// Continues here from [confirmed], the last thing the Receiver said about the video.
  ///
  /// A Receiver that never confirmed anything leaves nothing to continue from, and the phone simply
  /// owns its player again where it always would have.
  Future<void> _resumeLocally(CastPlaybackState? confirmed) async {
    if (confirmed == null || confirmed.videoId <= 0) {
      return;
    }

    try {
      await _playbackEndpoint.resume(
        videoId: confirmed.videoId,
        position: confirmed.position,
        // Moving away from the Receiver is meant to be seamless, so playback continues here. A
        // video that had run to its end is the one thing that does not start again: completed
        // media stays completed, which is what makes natural completion a different end from every
        // other one even though the phone does the same thing with it.
        isPlaying: !confirmed.isCompleted,
      );
    } catch (error, stackTrace) {
      // The Cast Session is over either way. A phone that could not pick playback back up is worth
      // a log, not a reason to leave the viewer holding a remote for a Receiver that has stopped.
      _logService.error(
        'CastController could not continue local playback after a Cast Session',
        error,
        stackTrace,
      );
    }
  }

  /// Tells the Receiver to play or to pause.
  ///
  /// Absolute on purpose: the phone says what the Receiver is to be doing rather than asking it
  /// to invert whatever it is doing now, so a command that was lost cannot leave the two devices
  /// disagreeing.
  ///
  /// Does nothing outside Remote Control Mode - while this phone is playing locally, its own player
  /// is what the viewer is using.
  Future<void> setReceiverPlaying(bool isPlaying) {
    return _command(
      'setting the Receiver playing state',
      (String sessionId) => _gateway.setReceiverPlaying(
        sessionId: sessionId,
        isPlaying: isPlaying,
      ),
    );
  }

  /// Tells the Receiver to go to an absolute position. Timestamp selection travels as one of these.
  Future<void> seekReceiver(Duration position) {
    return _command(
      'seeking the Receiver',
      (String sessionId) => _gateway.seekReceiver(
        sessionId: sessionId,
        position: position.isNegative ? Duration.zero : position,
      ),
    );
  }

  /// Tells the Receiver to set the LocalTube player's volume, from 0 (silent) to 1 (loudest).
  ///
  /// It is the Receiver's player volume, not its system volume, and it is the Receiver's to
  /// keep: this phone neither sends its own volume during Handoff nor reads the Receiver's back
  /// as its own.
  Future<void> setReceiverVolume(double volume) {
    return _command(
      'setting the Receiver volume',
      (String sessionId) => _gateway.setReceiverVolume(
        sessionId: sessionId,
        volume: volume,
      ),
    );
  }

  /// Sends one command and does nothing else.
  ///
  /// Nothing here is applied optimistically, and [CastUiState.confirmedState] is deliberately not
  /// touched: the phone renders what the Receiver reports, so a command it never applied
  /// never shows up as having happened and there is nothing to undo. Even the answer the API gives
  /// back is ignored - a command does not change the session, and the only thing that moves the
  /// confirmed state is the Receiver saying what it is doing. The one refusal that means more than
  /// that is a session the server does not have, which is what an API restart looks like: there is
  /// no Receiver to command any more, so the phone leaves cast state rather than holding a remote
  /// for nothing.
  Future<void> _command(
    String what,
    Future<CastSession> Function(String sessionId) send,
  ) async {
    final String? sessionId = _sessionId;
    if (_phase != CastPhase.remoteControl || sessionId == null) {
      return;
    }

    try {
      await send(sessionId);
      if (!mounted || _castFailureReason == null) {
        return;
      }
      _castFailureReason = null;
      _rebuild();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      _logService.error('CastController failed $what', error, stackTrace);
      _castFailureReason =
          CastErrorReason.tryParse(error) ?? CastErrorReason.unrecognised;
      if (_castFailureReason == CastErrorReason.sessionNotFound) {
        // The API has no such session, which is what a restarted API looks like. There is no
        // Receiver to command any more, so the phone goes back to its own player and continues
        // from the last state it was told about.
        await _endSession(CastEndReason.sessionMissing);
        return;
      }
      _rebuild();
    }
  }

  Future<void> _cancelOnApi(String sessionId) async {
    try {
      await _gateway.cancelSession(sessionId: sessionId);
    } catch (error, stackTrace) {
      // A refused cancel changes nothing here. The phone is already back on local playback, and a
      // session the API no longer has is exactly what was being asked for.
      _logService.error(
        'CastController failed cancelling a Handoff',
        error,
        stackTrace,
      );
    }
  }

  @override
  void dispose() {
    // A Cast Controller that is gone can no longer end its session, so progress writing it had
    // handed to a Receiver would have nothing left able to bring it back.
    _progressWriteOwnership.takeBack();
    unawaited(_devicesSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_registrationSubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _initialize() async {
    final CastDeviceRegistration? registration =
        _registrationService.currentRegistration;
    if (registration != null) {
      _applyRegistration(registration);
    }
    _snapshot = _gateway.devices;
    _connectionState = _gateway.connectionState;

    final CastSettings settings = await _settingsRepository.read();
    if (!mounted) {
      return;
    }
    _isReceiverMode = settings.isReceiverMode;
    _preferredName = settings.deviceName;
    _rememberedReceiverDeviceId = settings.lastSelectedReceiverDeviceId;
    if (!_hasRegistration) {
      // Until this device has described itself the model is unknown, so the name shown is the
      // chosen one or the generic fallback. A registration replaces it moments later.
      _applyEffectiveName();
    }
    _rebuild();
  }

  void _onDevices(CastDevicesSnapshot snapshot) {
    if (!mounted) {
      return;
    }
    _snapshot = snapshot;
    _rebuild();
    _resolveSessionIfDue();
  }

  void _onConnectionState(SyncConnectionState connectionState) {
    if (!mounted) {
      return;
    }
    _connectionState = connectionState;
    if (connectionState == SyncConnectionState.connected) {
      _shouldResolveSession = true;
    }
    _rebuild();
  }

  /// Checks a session this phone still believes in against the API, once per reconnection.
  ///
  /// It hangs off the device list rather than off the connection because a device may only ask
  /// about a session after it has said who it is, and the account's device list is the answer to
  /// saying so: hearing one is the first moment this phone is allowed to ask.
  ///
  /// What it is for is the API having restarted. Sessions live only in its memory, so it then has
  /// none of them while this phone is still holding a remote - and nothing would ever arrive to say
  /// so, because a phone in Remote Control Mode is waiting to be told things rather than asking.
  void _resolveSessionIfDue() {
    if (!_shouldResolveSession) {
      return;
    }
    final String? sessionId = _sessionId;
    if (sessionId == null) {
      // Nothing to check. A phone that is not in a Cast Session cannot be in a false Remote
      // Control Mode.
      _shouldResolveSession = false;
      return;
    }

    _shouldResolveSession = false;
    unawaited(_resolveSession(sessionId));
  }

  Future<void> _resolveSession(String sessionId) async {
    final CastSession session;
    try {
      session = await _gateway.resolveSession(sessionId: sessionId);
    } catch (error, stackTrace) {
      // Nothing is concluded from a question that could not be asked: a phone that dropped its
      // remote over a failed call would be ending sessions over a bad connection. It asks again
      // the next time the connection comes back.
      _logService.error(
        'CastController could not resolve its Cast Session',
        error,
        stackTrace,
      );
      if (mounted) {
        _shouldResolveSession = true;
      }
      return;
    }

    if (!mounted || session.sessionId != _sessionId) {
      // The answer is about a session this phone has meanwhile left behind.
      return;
    }
    await _applySession(session);
  }

  void _onRegistration(CastDeviceRegistration registration) {
    if (!mounted) {
      return;
    }
    _applyRegistration(registration);
    _rebuild();
  }

  void _onSession(CastSession session) {
    unawaited(_applySession(session));
  }

  /// The one place a session's state turns into what this phone does about it.
  Future<void> _applySession(CastSession session) async {
    if (!mounted) {
      return;
    }

    if (session.sessionId == _leftSessionId) {
      // Whatever the API is still saying about this session was already on its way when the phone
      // left it. It cannot put the phone back into preparing, it cannot make it commit a Handoff
      // that is over, and it cannot take the local player away again over a Receiver that has
      // stopped.
      return;
    }

    if (session.isLive &&
        _ownDeviceId.isNotEmpty &&
        session.controllerDeviceId.isNotEmpty &&
        session.controllerDeviceId != _ownDeviceId) {
      // A live session this device is not the Controller of is a session this device is playing.
      // Both halves of a Cast Session hear the same messages, and Remote Control Mode belongs to
      // the phone that started one: a Receiver reading its own session as a remote to hold would
      // give up the very player the session is about.
      //
      // A session the API does not have names no devices at all, so that answer still reaches the
      // end below and still takes a device out of cast state.
      return;
    }

    if (!session.isLive) {
      // Ended - or a status this version does not know, which is treated the same way on purpose.
      // Either way the phone goes back to owning its own playback rather than holding a remote for
      // a Receiver that may no longer be playing.
      //
      // News about a Handoff this phone has already left behind is not news about the one it is in
      // now, so a late word that the previous session is over cannot end the next one.
      final String? current = _sessionId;
      if (current == null || session.sessionId == current) {
        await _endSession(session.endReason);
      }
      return;
    }

    _sessionId = session.sessionId;
    _castVideoId = session.videoId;
    if (session.receiverName.isNotEmpty) {
      _castReceiverName = session.receiverName;
    }
    // Playback Authority, exactly as the Receiver reported it. The API sends the whole session
    // every time, so this is the latest word rather than a patch on an older one.
    _confirmedState = session.confirmedState;

    // A participant is inside its minute. The session is still this device's, so nothing about what
    // the phone is doing changes; the surface says so, and the viewer may ask for playback back
    // rather than waiting the minute out.
    _isSessionReconnecting = session.status == CastSessionStatus.reconnecting;

    if (session.confirmedState == null) {
      // The Receiver has confirmed nothing, so this phone is still the device playing. That is true
      // of a Handoff being prepared and equally of one whose Receiver dropped off while preparing
      // it: Remote Control Mode is reached by the Receiver's confirmation and by nothing else, so a
      // Receiver that never started playing can never take the player away from here.
      _phase = CastPhase.preparing;
      _rebuild();
      if (session.status == CastSessionStatus.preparing &&
          session.isReceiverPrepared &&
          _committedSessionId != session.sessionId) {
        _committedSessionId = session.sessionId;
        await _commit(session);
      }
      return;
    }

    // The Receiver has confirmed a state and is Playback Authority, whether or not somebody is
    // reconnecting. Only now does the phone give up its own player.
    if (_phase != CastPhase.remoteControl) {
      // Recorded before the release is awaited, so a second report arriving meanwhile does not
      // release a player that is already being given up.
      _phase = CastPhase.remoteControl;
      // The Receiver is playing, so it is also the device whose progress is kept. Handed over
      // before the local player is let go of, because letting go of it saves a position: a phone
      // writing where it had got to would overwrite what the Receiver is already reporting.
      _progressWriteOwnership.giveToReceiver();
      try {
        await _playbackEndpoint.release();
      } catch (error, stackTrace) {
        // The Receiver is already playing. A phone that could not let go of its own player is
        // worth a log, not a reason to drag playback back off the Receiver.
        _logService.error(
          'CastController could not release local playback',
          error,
          stackTrace,
        );
      }
      if (!mounted) {
        return;
      }
    }
    _rebuild();
  }

  /// Phase two: hand over where the viewer has got to by now, and what they were doing.
  Future<void> _commit(CastSession session) async {
    try {
      final CastLocalPlayback? playback = _playbackEndpoint.readPlayback();
      await _gateway.commitSession(
        sessionId: session.sessionId,
        position: playback?.position ?? Duration.zero,
        isPlaying: playback?.isPlaying ?? false,
      );
    } catch (error, stackTrace) {
      if (mounted) {
        _failCast('committing a Handoff', error, stackTrace);
      }
    }
  }

  /// A refused cast is simply a cast that did not happen: local playback was never touched, so
  /// there is nothing to undo and the viewer keeps watching.
  void _failCast(String what, Object error, StackTrace stackTrace) {
    _logService.error('CastController failed $what', error, stackTrace);
    _castFailureReason =
        CastErrorReason.tryParse(error) ?? CastErrorReason.unrecognised;
    _leaveCastState();
  }

  void _leaveCastState() {
    // The session being left is remembered first, because everything below forgets which one it
    // was. Leaving with none to name - a start the API never answered - leaves the last one
    // remembered, and starting the next cast is what forgets it.
    final String? left = _sessionId;
    if (left != null) {
      _leftSessionId = left;
    }
    _phase = CastPhase.idle;
    _sessionId = null;
    _castVideoId = null;
    _castReceiverName = null;
    _confirmedState = null;
    _committedSessionId = null;
    _isSessionReconnecting = false;
    // Progress writing comes home with playback. This is the one place the phone leaves a Cast
    // Session - a Return Handoff, a Receiver lost for its whole minute, a video watched to its
    // end, somebody at the Receiver leaving it, a sign-out, a session a restarted API no longer
    // has, a reason this version has never heard of and a Handoff that was backed out of all arrive
    // here - so there is no end after which this phone is left silently writing no watch history.
    _progressWriteOwnership.takeBack();
    _rebuild();
  }

  void _applyRegistration(CastDeviceRegistration registration) {
    _hasRegistration = true;
    _ownDeviceId = registration.deviceId;
    _deviceModel = registration.model;
    _deviceName = registration.name;
    _isReceiverMode = registration.role == CastDeviceRole.receiver;
  }

  void _applyEffectiveName() {
    _deviceName = CastDeviceIdentityService.resolveName(
      preferredName: _preferredName,
      model: _deviceModel,
    );
  }

  void _rebuild() {
    final List<CastDevice> onlineReceivers = _snapshot.receivers
        .where((CastDevice device) => device.deviceId != _ownDeviceId)
        .toList(growable: false);
    final List<CastDeviceLabel> receivers = labelCastDevices(onlineReceivers);

    final String? remembered = _rememberedReceiverDeviceId;
    final bool isOnline = remembered != null &&
        receivers.any(
          (CastDeviceLabel receiver) => receiver.deviceId == remembered,
        );

    state = CastUiState(
      isReceiverMode: _isReceiverMode,
      deviceName: _deviceName,
      deviceModel: _deviceModel,
      receivers: receivers,
      selectedReceiverDeviceId: isOnline ? remembered : null,
      connectionState: _connectionState,
      phase: _phase,
      sessionId: _sessionId,
      castVideoId: _castVideoId,
      castReceiverName: _castReceiverName,
      confirmedState: _confirmedState,
      castFailureReason: _castFailureReason,
      isSessionReconnecting: _isSessionReconnecting,
    );
  }
}

/// Deliberately not auto-disposed: a Cast Session outlives the screen that started it, and the
/// device list should not be rebuilt every time the player page is opened.
final StateNotifierProvider<CastController, CastUiState> castControllerProvider =
    StateNotifierProvider<CastController, CastUiState>(
  (Ref ref) => CastController(
    gateway: ref.watch(castGatewayProvider),
    settingsRepository: ref.watch(castSettingsRepositoryProvider),
    registrationService: ref.watch(castRegistrationServiceProvider),
    playbackEndpoint: ref.watch(castPlaybackBindingProvider),
    progressWriteOwnership: ref.watch(castProgressWriteOwnershipProvider),
    logService: ref.watch(logServiceProvider),
  ),
);
