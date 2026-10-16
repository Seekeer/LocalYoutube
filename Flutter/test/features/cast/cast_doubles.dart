import 'dart:async';

import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/cast/data/cast_device_identity_repository.dart';
import 'package:localtube_flutter/features/cast/data/cast_settings_repository.dart';
import 'package:localtube_flutter/features/cast/data/device_model_source.dart';
import 'package:localtube_flutter/features/cast/domain/cast_clock.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_identity_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_gateway.dart';
import 'package:localtube_flutter/features/cast/domain/cast_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_playback_endpoint.dart';
import 'package:localtube_flutter/features/cast/domain/cast_playback_progress_writer.dart';
import 'package:localtube_flutter/features/cast/domain/cast_progress_write_ownership.dart';
import 'package:localtube_flutter/features/cast/domain/cast_receiver_playback.dart';
import 'package:localtube_flutter/features/cast/domain/cast_registration_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_session_models.dart';
import 'package:localtube_flutter/features/cast/domain/cast_settings.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_controller.dart';
import 'package:localtube_flutter/features/sync/domain/sync_models.dart';

/// The API connection, without an API: connection state and snapshots are pushed by the test, and
/// every registration the code under test sends is recorded instead of leaving the process.
class FakeCastGateway implements CastGateway {
  FakeCastGateway({
    SyncConnectionState connectionState = SyncConnectionState.connected,
  }) : _connectionState = connectionState;

  final StreamController<CastDevicesSnapshot> _devicesController =
      StreamController<CastDevicesSnapshot>.broadcast();
  final StreamController<SyncConnectionState> _connectionController =
      StreamController<SyncConnectionState>.broadcast();
  final StreamController<CastSession> _sessionController =
      StreamController<CastSession>.broadcast();
  final StreamController<CastPrepareCommand> _prepareController =
      StreamController<CastPrepareCommand>.broadcast();
  final StreamController<CastCommitCommand> _commitController =
      StreamController<CastCommitCommand>.broadcast();
  final StreamController<CastCommand> _commandController =
      StreamController<CastCommand>.broadcast();

  /// Every registration this installation sent, oldest first.
  final List<CastDeviceRegistration> registrations = <CastDeviceRegistration>[];

  /// Every Handoff this installation started, oldest first.
  final List<FakeCastStart> starts = <FakeCastStart>[];

  /// Every commit this installation sent, oldest first.
  final List<FakeCastCommit> commits = <FakeCastCommit>[];

  /// Every Handoff this installation backed out of, oldest first.
  final List<String> cancels = <String>[];

  /// Every Handoff this installation asked to have back, oldest first.
  final List<String> returns = <String>[];

  /// Every session this installation ended itself, oldest first, with the reason it named.
  final List<FakeCastEnd> ends = <FakeCastEnd>[];

  /// Every session this installation asked the API about, oldest first.
  final List<String> resolves = <String>[];

  /// Every Handoff this installation answered as a prepared Receiver, oldest first.
  final List<String> preparedConfirmations = <String>[];

  /// Every playback state this installation reported as a Receiver, oldest first.
  final List<FakeCastReport> reports = <FakeCastReport>[];

  /// Every command this installation sent as a Controller, oldest first.
  ///
  /// They carry no sequence number: numbering is the API's, and a phone never names one.
  final List<FakeCastCommand> commands = <FakeCastCommand>[];

  /// Thrown by the next registration when set, so a failing hub can be exercised.
  Object? registrationFailure;

  /// Thrown by the next start, standing in for a hub refusal such as sessionAlreadyActive.
  Object? startFailure;

  /// Thrown by the next commit.
  Object? commitFailure;

  /// Thrown by the next cancel, standing in for a hub refusal such as sessionNotFound when the
  /// Handoff had already run out of time.
  Object? cancelFailure;

  /// Thrown by the next Return Handoff, standing in for a hub refusal such as sessionNotFound when
  /// the session had already ended for another reason.
  Object? returnHandoffFailure;

  /// Thrown by the next prepared confirmation.
  Object? confirmPreparedFailure;

  /// Thrown by the next playback report, standing in for a hub refusal such as videoMismatch.
  Object? reportFailure;

  /// Thrown by the next command, standing in for a hub refusal such as notSessionController.
  Object? commandFailure;

  /// Thrown by the next end, standing in for a hub refusal such as notSessionReceiver.
  Object? endFailure;

  /// Thrown by the next resolve, standing in for a connection that could not carry the question.
  Object? resolveFailure;

  /// What the API says it has for a session it is asked to resolve.
  ///
  /// `null` - the default - means the API no longer has the session, which is what a restarted API
  /// looks like: the answer is an ended session carrying [CastEndReason.sessionMissing]. Set it to
  /// a session to stand for an API that still has one.
  CastSession? resolvedSession;

  SyncConnectionState _connectionState;
  CastDevicesSnapshot _devices = CastDevicesSnapshot.empty;
  CastSession? _session;
  int _nextSessionNumber = 1;

  @override
  SyncConnectionState get connectionState => _connectionState;

  @override
  Stream<SyncConnectionState> watchConnectionState() =>
      _connectionController.stream;

  @override
  CastDevicesSnapshot get devices => _devices;

  @override
  Stream<CastDevicesSnapshot> watchDevices() => _devicesController.stream;

  @override
  Future<CastDevicesSnapshot> registerDevice(
    CastDeviceRegistration registration,
  ) async {
    final Object? failure = registrationFailure;
    if (failure != null) {
      throw failure;
    }
    registrations.add(registration);
    return _devices;
  }

  @override
  Stream<CastSession> watchSession() => _sessionController.stream;

  @override
  Future<CastSession> startSession({
    required String receiverDeviceId,
    required int videoId,
  }) async {
    final Object? failure = startFailure;
    if (failure != null) {
      throw failure;
    }
    starts.add(
      FakeCastStart(receiverDeviceId: receiverDeviceId, videoId: videoId),
    );

    final CastSession session = castSession(
      sessionId: 'session-${_nextSessionNumber++}',
      receiverDeviceId: receiverDeviceId,
      videoId: videoId,
    );
    _session = session;
    return session;
  }

  @override
  Future<CastSession> commitSession({
    required String sessionId,
    required Duration position,
    required bool isPlaying,
  }) async {
    final Object? failure = commitFailure;
    if (failure != null) {
      throw failure;
    }
    commits.add(
      FakeCastCommit(
        sessionId: sessionId,
        position: position,
        isPlaying: isPlaying,
      ),
    );
    return _session ?? castSession(sessionId: sessionId);
  }

  @override
  Future<CastSession> cancelSession({required String sessionId}) async {
    final Object? failure = cancelFailure;
    if (failure != null) {
      throw failure;
    }
    cancels.add(sessionId);

    // The answer goes to the caller only, exactly as the real gateway does; what the API pushes is
    // a separate message a test emits for itself.
    final CastSession cancelled = _changed(
      _requireSession(),
      status: CastSessionStatus.ended,
      endReason: CastEndReason.handoffCancelled,
    );
    _session = cancelled;
    return cancelled;
  }

  @override
  Future<CastSession> returnHandoff({required String sessionId}) async {
    final Object? failure = returnHandoffFailure;
    if (failure != null) {
      throw failure;
    }
    returns.add(sessionId);

    // The Receiver stops and the session is over, with the last confirmed state still on it -
    // that is the position the phone continues from.
    final CastSession returned = _changed(
      _requireSession(),
      status: CastSessionStatus.ended,
      endReason: CastEndReason.returnHandoff,
    );
    _session = returned;
    return returned;
  }

  @override
  Future<CastSession?> endSession({
    String? sessionId,
    required CastEndReason reason,
  }) async {
    final Object? failure = endFailure;
    if (failure != null) {
      throw failure;
    }
    ends.add(FakeCastEnd(sessionId: sessionId, reason: reason));

    final CastSession? current = _session;
    if (current == null) {
      // Nothing to end is an ordinary answer, exactly as it is on the API.
      return null;
    }
    if (sessionId != null &&
        sessionId.isNotEmpty &&
        sessionId != current.sessionId) {
      // An end that named a session the API has moved on from ends nothing.
      return null;
    }

    final CastSession ended = _changed(
      current,
      status: CastSessionStatus.ended,
      endReason: reason,
    );
    _session = ended;
    return ended;
  }

  @override
  Future<CastSession> resolveSession({required String sessionId}) async {
    // Record every question, including one the fake API fails to answer. Tests use this as the
    // call journal; putting it after the injected failure would hide the attempt that proves the
    // Controller retries on the next connection.
    resolves.add(sessionId);
    final Object? failure = resolveFailure;
    if (failure != null) {
      throw failure;
    }

    final CastSession? answer = resolvedSession;
    if (answer != null) {
      return answer;
    }
    // The API has no such session. It says so as an ended session rather than as a refusal, so the
    // caller has something to act on.
    return castSession(
      sessionId: sessionId,
      status: CastSessionStatus.ended,
      controllerDeviceId: '',
      controllerName: '',
      receiverDeviceId: '',
      receiverName: '',
      videoId: 0,
      endReason: CastEndReason.sessionMissing,
    );
  }

  @override
  Future<CastSession> setReceiverPlaying({
    required String sessionId,
    required bool isPlaying,
  }) {
    return _sendCommand(
      FakeCastCommand(
        sessionId: sessionId,
        type: CastCommandType.setPlaying,
        isPlaying: isPlaying,
      ),
    );
  }

  @override
  Future<CastSession> seekReceiver({
    required String sessionId,
    required Duration position,
  }) {
    return _sendCommand(
      FakeCastCommand(
        sessionId: sessionId,
        type: CastCommandType.seekTo,
        position: position,
      ),
    );
  }

  @override
  Future<CastSession> setReceiverVolume({
    required String sessionId,
    required double volume,
  }) {
    return _sendCommand(
      FakeCastCommand(
        sessionId: sessionId,
        type: CastCommandType.setVolume,
        volume: volume,
      ),
    );
  }

  Future<CastSession> _sendCommand(FakeCastCommand command) async {
    final Object? failure = commandFailure;
    if (failure != null) {
      throw failure;
    }
    commands.add(command);

    // A command never changes the session; the answer is simply what it already was.
    return _session ?? castSession(sessionId: command.sessionId);
  }

  @override
  Stream<CastCommand> watchCommands() => _commandController.stream;

  @override
  Stream<CastPrepareCommand> watchPrepareCommands() =>
      _prepareController.stream;

  @override
  Stream<CastCommitCommand> watchCommitCommands() => _commitController.stream;

  @override
  Future<CastSession> confirmPrepared({required String sessionId}) async {
    final Object? failure = confirmPreparedFailure;
    if (failure != null) {
      throw failure;
    }
    preparedConfirmations.add(sessionId);

    final CastSession prepared =
        _changed(_requireSession(), isReceiverPrepared: true);
    _session = prepared;
    return prepared;
  }

  @override
  Future<CastSession> reportPlaybackState({
    required String sessionId,
    required int videoId,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required bool isBuffering,
    required bool isCompleted,
    required double volume,
    required int lastAppliedSeq,
  }) async {
    final Object? failure = reportFailure;
    if (failure != null) {
      throw failure;
    }
    final CastPlaybackState reported = CastPlaybackState(
      videoId: videoId,
      position: position,
      isPlaying: isPlaying,
      duration: duration,
      isBuffering: isBuffering,
      isCompleted: isCompleted,
      volume: volume,
      lastAppliedSeq: lastAppliedSeq,
    );
    reports.add(FakeCastReport(sessionId: sessionId, state: reported));

    // The report is what turns the session active, exactly as the API does with it.
    final CastSession active = _changed(
      _requireSession(),
      status: CastSessionStatus.active,
      isReceiverPrepared: true,
      confirmedState: reported,
    );
    _session = active;
    return active;
  }

  /// What the API sends a Receiver when a Handoff starts: load this video and wait. It carries no
  /// position by design.
  CastPrepareCommand emitPrepareCommand({
    String sessionId = 'session-1',
    int videoId = 42,
    String controllerDeviceId = 'phone-1',
    String controllerName = 'Pixel 8',
  }) {
    _session = castSession(
      sessionId: sessionId,
      controllerDeviceId: controllerDeviceId,
      controllerName: controllerName,
      videoId: videoId,
    );
    final CastPrepareCommand command = CastPrepareCommand(
      sessionId: sessionId,
      videoId: videoId,
      controllerDeviceId: controllerDeviceId,
      controllerName: controllerName,
    );
    _prepareController.add(command);
    return command;
  }

  /// What the API sends a Receiver once the phone has committed: where the viewer actually is, and
  /// whether they were playing or paused.
  CastCommitCommand emitCommitCommand({
    String sessionId = 'session-1',
    int videoId = 42,
    Duration position = const Duration(seconds: 30),
    bool isPlaying = true,
  }) {
    final CastCommitCommand command = CastCommitCommand(
      sessionId: sessionId,
      videoId: videoId,
      position: position,
      isPlaying: isPlaying,
    );
    _commitController.add(command);
    return command;
  }

  /// What the API sends a Receiver when the phone commands it. The number is the API's, so a test
  /// names it exactly as the server would: starting at 1 for each session and only going up.
  CastCommand emitSetPlaying({
    String sessionId = 'session-1',
    required int seq,
    required bool isPlaying,
  }) {
    return _emitCommand(
      CastCommand(
        sessionId: sessionId,
        seq: seq,
        type: CastCommandType.setPlaying,
        isPlaying: isPlaying,
      ),
    );
  }

  CastCommand emitSeekTo({
    String sessionId = 'session-1',
    required int seq,
    required Duration position,
  }) {
    return _emitCommand(
      CastCommand(
        sessionId: sessionId,
        seq: seq,
        type: CastCommandType.seekTo,
        position: position,
      ),
    );
  }

  CastCommand emitSetVolume({
    String sessionId = 'session-1',
    required int seq,
    required double volume,
  }) {
    return _emitCommand(
      CastCommand(
        sessionId: sessionId,
        seq: seq,
        type: CastCommandType.setVolume,
        volume: volume,
      ),
    );
  }

  CastCommand _emitCommand(CastCommand command) {
    _commandController.add(command);
    return command;
  }

  void emitConnectionState(SyncConnectionState state) {
    _connectionState = state;
    _connectionController.add(state);
  }

  void emitDevices(List<CastDevice> devices) {
    _devices = CastDevicesSnapshot(List<CastDevice>.unmodifiable(devices));
    _devicesController.add(_devices);
  }

  /// Pushes a session exactly as the API would.
  void emitSession(CastSession session) {
    _session = session;
    _sessionController.add(session);
  }

  /// What the API pushes once the Receiver says it has the video loaded.
  void emitReceiverPrepared() {
    emitSession(_changed(_requireSession(), isReceiverPrepared: true));
  }

  /// What the API pushes every time the Receiver says what it is playing. The first of these is
  /// what turns the session active; the ones after it are the reporting cadence arriving.
  void emitReceiverConfirmed({
    Duration position = Duration.zero,
    bool isPlaying = true,
    Duration duration = Duration.zero,
    bool isBuffering = false,
    bool isCompleted = false,
    double volume = 1.0,
    int lastAppliedSeq = 0,
  }) {
    final CastSession session = _requireSession();
    emitSession(
      _changed(
        session,
        status: CastSessionStatus.active,
        isReceiverPrepared: true,
        confirmedState: CastPlaybackState(
          videoId: session.videoId,
          position: position,
          isPlaying: isPlaying,
          duration: duration,
          isBuffering: isBuffering,
          isCompleted: isCompleted,
          volume: volume,
          lastAppliedSeq: lastAppliedSeq,
        ),
      ),
    );
  }

  /// What the API pushes while a participant is inside its one-minute reconnect window: the same
  /// live session, saying so, with the last state the Receiver confirmed still on it.
  void emitParticipantReconnecting() {
    emitSession(
      _changed(_requireSession(), status: CastSessionStatus.reconnecting),
    );
  }

  /// What the API pushes when the session is over.
  void emitSessionEnded({
    CastEndReason reason = CastEndReason.participantTimeout,
  }) {
    emitSession(
      _changed(
        _requireSession(),
        status: CastSessionStatus.ended,
        endReason: reason,
      ),
    );
  }

  /// A push whose status this version of the client does not know, which is what a future server
  /// reporting a new lifecycle state looks like from here.
  void emitUnknownSessionStatus() {
    emitSession(
      _changed(_requireSession(), status: CastSessionStatus.unknown),
    );
  }

  CastSession _requireSession() {
    final CastSession? session = _session;
    if (session == null) {
      throw StateError('No Cast Session has been started on this fake gateway');
    }
    return session;
  }

  Future<void> close() async {
    await _devicesController.close();
    await _connectionController.close();
    await _sessionController.close();
    await _prepareController.close();
    await _commitController.close();
    await _commandController.close();
  }
}

/// A command the code under test sent as a Controller.
class FakeCastCommand {
  const FakeCastCommand({
    required this.sessionId,
    required this.type,
    this.isPlaying,
    this.position,
    this.volume,
  });

  final String sessionId;
  final CastCommandType type;
  final bool? isPlaying;
  final Duration? position;
  final double? volume;
}

/// A Cast Session the code under test ended itself, and the reason it named.
///
/// [sessionId] is `null` or empty when the caller said "whichever session I am in", which is what a
/// device that is signing out says.
class FakeCastEnd {
  const FakeCastEnd({required this.sessionId, required this.reason});

  final String? sessionId;
  final CastEndReason reason;
}

/// A Handoff the code under test started.
class FakeCastStart {
  const FakeCastStart({required this.receiverDeviceId, required this.videoId});

  final String receiverDeviceId;
  final int videoId;
}

/// A commit the code under test sent.
class FakeCastCommit {
  const FakeCastCommit({
    required this.sessionId,
    required this.position,
    required this.isPlaying,
  });

  final String sessionId;
  final Duration position;
  final bool isPlaying;
}

/// A playback state this installation reported as a Receiver: Playback Authority, as it left here.
class FakeCastReport {
  const FakeCastReport({required this.sessionId, required this.state});

  final String sessionId;

  /// The whole state, because that is what a report carries.
  final CastPlaybackState state;

  int get videoId => state.videoId;

  Duration get position => state.position;

  Duration get duration => state.duration;

  bool get isPlaying => state.isPlaying;

  bool get isBuffering => state.isBuffering;

  bool get isCompleted => state.isCompleted;

  double get volume => state.volume;

  int get lastAppliedSeq => state.lastAppliedSeq;
}

/// The video a Receiver was told to start.
class FakeCastReceiverStart {
  const FakeCastReceiverStart({
    required this.videoId,
    required this.position,
    required this.isPlaying,
  });

  final int videoId;
  final Duration position;
  final bool isPlaying;
}

/// A progress write the Receiver made for a video it was about to stop playing.
class FakeCastProgressWrite {
  const FakeCastProgressWrite({
    required this.videoId,
    required this.position,
  });

  final int videoId;
  final Duration position;
}

/// A Receiver's video player without a video decoder, which automated Flutter tests deliberately
/// have none of.
///
/// Everything it does is also appended to [journal]. Handing the same journal to a
/// [RecordingCastProgressWriter] is what lets a test assert the order between keeping a displaced
/// video's progress and replacing it, which is the whole point of doing them in that order.
class FakeCastReceiverPlayback implements CastReceiverPlayback {
  FakeCastReceiverPlayback({
    this.playback,
    List<String>? journal,
  }) : journal = journal ?? <String>[];

  /// What this device is playing. A test sets it to the video a cast is about to displace.
  CastLocalPlayback? playback;

  /// What happened here and in the progress writer, in the order it happened.
  final List<String> journal;

  /// Every video this Receiver was asked to load, oldest first.
  final List<int> prepared = <int>[];

  /// Every video this Receiver was told to start, oldest first.
  final List<FakeCastReceiverStart> starts = <FakeCastReceiverStart>[];

  /// Every playing state this Receiver was commanded into, oldest first.
  final List<bool> playingCommands = <bool>[];

  /// Every position this Receiver was commanded to, oldest first.
  final List<Duration> seeks = <Duration>[];

  /// Every volume this Receiver was commanded to, oldest first.
  ///
  /// It stays empty through a whole Handoff: a phone's volume is never copied to a Receiver.
  final List<double> volumes = <double>[];

  /// The player's own volume, which this installation keeps across videos. It starts at loudest,
  /// exactly like a player that has never been told otherwise.
  double volume = 1.0;

  /// How long the video this Receiver starts turns out to be.
  Duration duration = const Duration(minutes: 30);

  /// Thrown by the next load, standing in for a Receiver that cannot play the video.
  Object? prepareFailure;

  /// Thrown by the next start.
  Object? startFailure;

  /// Thrown by the next command, standing in for a player that would not take it.
  Object? commandFailure;

  @override
  CastLocalPlayback? readPlayback() => playback;

  @override
  Future<void> prepare(int videoId) async {
    final Object? failure = prepareFailure;
    if (failure != null) {
      throw failure;
    }
    prepared.add(videoId);
    journal.add('prepare:$videoId');
  }

  @override
  Future<CastLocalPlayback> start({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  }) async {
    final Object? failure = startFailure;
    if (failure != null) {
      throw failure;
    }
    starts.add(
      FakeCastReceiverStart(
        videoId: videoId,
        position: position,
        isPlaying: isPlaying,
      ),
    );
    journal.add('start:$videoId');

    final CastLocalPlayback reached = CastLocalPlayback(
      videoId: videoId,
      position: position,
      isPlaying: isPlaying,
      duration: duration,
      volume: volume,
    );
    playback = reached;
    return reached;
  }

  @override
  Future<void> setPlaying(bool isPlaying) async {
    _requireNoCommandFailure();
    playingCommands.add(isPlaying);
    journal.add('setPlaying:$isPlaying');
    playback = _moved(isPlaying: isPlaying);
  }

  @override
  Future<void> seekTo(Duration position) async {
    _requireNoCommandFailure();
    seeks.add(position);
    journal.add('seekTo:${position.inMilliseconds}');
    playback = _moved(position: position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _requireNoCommandFailure();
    volumes.add(volume);
    journal.add('setVolume:$volume');
    this.volume = volume;
    playback = _moved(volume: volume);
  }

  /// What somebody standing at the Receiver does with its own remote, and what the video does by
  /// itself while it plays. Nothing about it goes through the Cast Session: it simply becomes what
  /// this player is, which is exactly how a real one behaves.
  void moveTo({
    Duration? position,
    bool? isPlaying,
    Duration? duration,
    bool? isBuffering,
    bool? isCompleted,
    double? volume,
  }) {
    if (volume != null) {
      this.volume = volume;
    }
    playback = _moved(
      position: position,
      isPlaying: isPlaying,
      duration: duration,
      isBuffering: isBuffering,
      isCompleted: isCompleted,
      volume: volume,
    );
  }

  void _requireNoCommandFailure() {
    final Object? failure = commandFailure;
    if (failure != null) {
      throw failure;
    }
  }

  CastLocalPlayback? _moved({
    Duration? position,
    bool? isPlaying,
    Duration? duration,
    bool? isBuffering,
    bool? isCompleted,
    double? volume,
  }) {
    final CastLocalPlayback? current = playback;
    if (current == null) {
      return null;
    }
    return CastLocalPlayback(
      videoId: current.videoId,
      position: position ?? current.position,
      isPlaying: isPlaying ?? current.isPlaying,
      duration: duration ?? current.duration,
      isBuffering: isBuffering ?? current.isBuffering,
      isCompleted: isCompleted ?? current.isCompleted,
      volume: volume ?? current.volume,
    );
  }
}

/// The app's playback-progress path, recorded rather than written.
class RecordingCastProgressWriter implements CastPlaybackProgressWriter {
  RecordingCastProgressWriter({List<String>? journal})
      : journal = journal ?? <String>[];

  /// Shared with the Receiver's player when a test asserts the order between them.
  final List<String> journal;

  /// Every progress write, oldest first.
  final List<FakeCastProgressWrite> writes = <FakeCastProgressWrite>[];

  /// Thrown by the next write, standing in for storage that would not take it.
  Object? failure;

  @override
  Future<void> saveProgress({
    required int videoId,
    required Duration position,
  }) async {
    final Object? thrown = failure;
    if (thrown != null) {
      throw thrown;
    }
    writes.add(FakeCastProgressWrite(videoId: videoId, position: position));
    journal.add('progress:$videoId');
  }
}

/// Which device's playback progress this installation writes, recorded rather than acted on.
///
/// The app's real answer is a flag the playback-progress path reads before it writes anything; what
/// a Cast Controller test needs from it is when it changed, and in what order with everything else
/// the phone does.
class RecordingCastProgressWriteOwnership
    implements CastProgressWriteOwnership {
  RecordingCastProgressWriteOwnership({List<String>? journal})
      : journal = journal ?? <String>[];

  /// Shared with the local playback endpoint when a test asserts the order between them.
  final List<String> journal;

  /// Whether playback progress is the Receiver's to write right now, so the phone writes none.
  bool isReceiverOwned = false;

  /// Every time ownership was handed over or taken back, oldest first.
  final List<bool> handovers = <bool>[];

  @override
  void giveToReceiver() {
    isReceiverOwned = true;
    handovers.add(true);
    journal.add('progress-writes:receiver');
  }

  @override
  void takeBack() {
    isReceiverOwned = false;
    handovers.add(false);
    journal.add('progress-writes:phone');
  }
}

/// Local playback without a video decoder, which automated Flutter tests deliberately have none of.
///
/// Everything it does is also appended to [journal]. Handing the same journal to a
/// [RecordingCastProgressWriteOwnership] is what lets a test assert the order between handing
/// playback progress to the Receiver and giving up the local player, which is the whole point of
/// doing them in that order.
class FakeCastPlaybackEndpoint implements CastPlaybackEndpoint {
  FakeCastPlaybackEndpoint({this.playback, List<String>? journal})
      : journal = journal ?? <String>[];

  /// What this device is playing. A test moves it forward to stand for time passing while the
  /// Receiver prepares.
  CastLocalPlayback? playback;

  /// Shared with the progress-write ownership when a test asserts the order between them.
  final List<String> journal;

  /// How many times the local video player has been given up.
  int releaseCount = 0;

  /// Every time local playback was asked to continue here, oldest first. A Return Handoff is the
  /// only thing that does this.
  final List<FakeCastResume> resumes = <FakeCastResume>[];

  bool get isReleased => releaseCount > 0;

  @override
  CastLocalPlayback? readPlayback() => playback;

  @override
  Future<void> release() async {
    releaseCount++;
    playback = null;
    journal.add('release');
  }

  @override
  Future<void> resume({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  }) async {
    journal.add('resume:$videoId');
    resumes.add(
      FakeCastResume(
        videoId: videoId,
        position: position,
        isPlaying: isPlaying,
      ),
    );
    // This device owns a player again, exactly as it does once the restored surface has built one.
    playback = CastLocalPlayback(
      videoId: videoId,
      position: position,
      isPlaying: isPlaying,
    );
  }
}

/// Local playback picked back up here after a Return Handoff.
class FakeCastResume {
  const FakeCastResume({
    required this.videoId,
    required this.position,
    required this.isPlaying,
  });

  final int videoId;
  final Duration position;
  final bool isPlaying;
}

/// Time, driven by the test rather than by the machine.
///
/// A Receiver reports on a cadence, so a test of that cadence has to be able to say "a second has
/// gone by" without a second going by. Advancing this runs every tick that falls due, in the order
/// they fall due, which is what makes "reported because something changed" distinguishable from
/// "reported because the interval elapsed".
class FakeCastClock implements CastClock {
  final List<_FakeCastTimer> _timers = <_FakeCastTimer>[];

  @override
  CastTimer periodic(Duration period, void Function() onTick) {
    final _FakeCastTimer timer = _FakeCastTimer(this, period, onTick);
    _timers.add(timer);
    return timer;
  }

  /// Moves time on by [by] and runs everything that falls due in it.
  void advance(Duration by) {
    for (final _FakeCastTimer timer in List<_FakeCastTimer>.of(_timers)) {
      timer.advanceBy(by);
    }
  }

  void _forget(_FakeCastTimer timer) {
    _timers.remove(timer);
  }
}

class _FakeCastTimer implements CastTimer {
  _FakeCastTimer(this._clock, this._period, this._onTick);

  final FakeCastClock _clock;
  final Duration _period;
  final void Function() _onTick;

  Duration _elapsed = Duration.zero;
  bool _isCancelled = false;

  void advanceBy(Duration by) {
    if (_isCancelled) {
      return;
    }
    _elapsed += by;
    while (!_isCancelled && _elapsed >= _period) {
      _elapsed -= _period;
      _onTick();
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
    _clock._forget(this);
  }
}

/// Cast settings that live only in memory, standing in for secure storage.
class InMemoryCastSettingsRepository implements CastSettingsRepository {
  InMemoryCastSettingsRepository([
    CastSettings initial = CastSettings.defaults,
  ]) : _settings = initial;

  CastSettings _settings;

  int writeCount = 0;

  CastSettings get settings => _settings;

  @override
  Future<CastSettings> read() async => _settings;

  @override
  Future<CastSettings> setReceiverMode(bool isReceiverMode) async {
    writeCount++;
    _settings = _settings.copyWith(isReceiverMode: isReceiverMode);
    return _settings;
  }

  @override
  Future<CastSettings> setDeviceName(String deviceName) async {
    writeCount++;
    _settings = _settings.copyWith(deviceName: deviceName.trim());
    return _settings;
  }

  @override
  Future<CastSettings> setLastSelectedReceiver(String? deviceId) async {
    writeCount++;
    final String trimmed = deviceId?.trim() ?? '';
    _settings = trimmed.isEmpty
        ? _settings.copyWith(clearLastSelectedReceiver: true)
        : _settings.copyWith(lastSelectedReceiverDeviceId: trimmed);
    return _settings;
  }
}

class FixedCastDeviceIdentityRepository implements CastDeviceIdentityRepository {
  FixedCastDeviceIdentityRepository(this._deviceId);

  final String _deviceId;

  @override
  Future<String> deviceId() async => _deviceId;
}

class FakeDeviceModelSource implements DeviceModelSource {
  FakeDeviceModelSource(this._model);

  final String _model;

  @override
  Future<String> androidModel() async => _model;
}

class NoopLogService extends LogService {
  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, Object error, StackTrace stackTrace) {}
}

/// A Cast Session as the API reports it.
CastSession castSession({
  String sessionId = 'session-1',
  CastSessionStatus status = CastSessionStatus.preparing,
  String controllerDeviceId = 'device-1',
  String controllerName = 'Pixel 8',
  String receiverDeviceId = 'tv-2',
  String receiverName = 'Living room',
  int videoId = 42,
  bool isReceiverPrepared = false,
  CastPlaybackState? confirmedState,
  CastEndReason? endReason,
}) {
  return CastSession(
    sessionId: sessionId,
    status: status,
    controllerDeviceId: controllerDeviceId,
    controllerName: controllerName,
    receiverDeviceId: receiverDeviceId,
    receiverName: receiverName,
    videoId: videoId,
    isReceiverPrepared: isReceiverPrepared,
    confirmedState: confirmedState,
    endReason: endReason,
  );
}

/// The same session, moved on. The API always sends the whole thing, so a change is a new session
/// value rather than a patch.
CastSession _changed(
  CastSession session, {
  CastSessionStatus? status,
  bool? isReceiverPrepared,
  CastPlaybackState? confirmedState,
  CastEndReason? endReason,
}) {
  return CastSession(
    sessionId: session.sessionId,
    status: status ?? session.status,
    controllerDeviceId: session.controllerDeviceId,
    controllerName: session.controllerName,
    receiverDeviceId: session.receiverDeviceId,
    receiverName: session.receiverName,
    videoId: session.videoId,
    isReceiverPrepared: isReceiverPrepared ?? session.isReceiverPrepared,
    confirmedState: confirmedState ?? session.confirmedState,
    endReason: endReason ?? session.endReason,
  );
}

/// A real Cast Controller over these doubles, for a widget test that has to be driven by the rules
/// which actually decide what a surface shows.
///
/// A hand-written state passed to a mock controller says what the surface renders and nothing about
/// whether the phone would ever be in that state: a name that falls back to the Android model, or a
/// remembered Receiver that is only preselected while it is online, are the Cast Controller's
/// answers and have to come from it. Everything under the controller is still a double, so no
/// widget test needs a connection, storage or a video decoder.
class CastControllerHarness {
  CastControllerHarness._({
    required this.gateway,
    required this.settingsRepository,
    required this.registrationService,
    required this.controller,
  });

  static Future<CastControllerHarness> start({
    CastSettings settings = CastSettings.defaults,
    String model = 'Pixel Tablet',
    String deviceId = 'device-1',
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

    final CastController controller = CastController(
      gateway: gateway,
      settingsRepository: settingsRepository,
      registrationService: registrationService,
      playbackEndpoint: FakeCastPlaybackEndpoint(),
      progressWriteOwnership: RecordingCastProgressWriteOwnership(),
      logService: NoopLogService(),
    );
    await controller.initialized;

    return CastControllerHarness._(
      gateway: gateway,
      settingsRepository: settingsRepository,
      registrationService: registrationService,
      controller: controller,
    );
  }

  final FakeCastGateway gateway;
  final InMemoryCastSettingsRepository settingsRepository;
  final CastRegistrationService registrationService;
  final CastController controller;

  /// Ends the harness. The Cast Controller itself is left alone: the provider scope it was handed
  /// to owns it and disposes it, and disposing it twice is an error.
  Future<void> dispose() async {
    await registrationService.dispose();
    await gateway.close();
  }
}

/// A device as a snapshot carries it.
CastDevice castDevice({
  required String deviceId,
  required String name,
  String model = 'Pixel Tablet',
  CastDeviceRole role = CastDeviceRole.receiver,
}) {
  return CastDevice(
    deviceId: deviceId,
    name: name,
    model: model,
    role: role,
  );
}
