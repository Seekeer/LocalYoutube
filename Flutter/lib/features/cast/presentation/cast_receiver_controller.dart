import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log_service.dart';
import '../data/cast_device_identity_repository.dart';
import '../domain/cast_clock.dart';
import '../domain/cast_gateway.dart';
import '../domain/cast_playback_endpoint.dart';
import '../domain/cast_playback_progress_writer.dart';
import '../domain/cast_receiver_playback.dart';
import '../domain/cast_session_models.dart';

/// What this device is doing as a Receiver.
enum CastReceiverPhase {
  /// Taking part in no Cast Session. Whatever is on screen is this device's own business.
  idle,

  /// A Handoff has asked for a video and it is being loaded. Nothing that is playing has changed
  /// yet, here or on the phone.
  preparing,

  /// The cast video is playing and this device is Playback Authority.
  casting,
}

/// What a Receiver surface shows about the Cast Session this device is taking part in.
class CastReceiverUiState {
  const CastReceiverUiState({
    this.phase = CastReceiverPhase.idle,
    this.sessionId,
    this.castVideoId,
    this.controllerName,
    this.lastAppliedSeq = 0,
  });

  static const CastReceiverUiState initial = CastReceiverUiState();

  final CastReceiverPhase phase;

  /// The Cast Session this device takes part in, or `null` when it takes part in none.
  final String? sessionId;

  /// The video the Cast Session is about.
  final int? castVideoId;

  /// The name of the phone casting here, so the Receiver can say where playback came from.
  final String? controllerName;

  /// The number of the last Controller command this Receiver accepted, or 0 when it has accepted
  /// none. Commands are numbered by the session, so this starts again with each Cast Session.
  ///
  /// It is here rather than hidden inside the controller because it is what the Receiver has to
  /// tell the phone: the state report carries it, so the phone can see which of its commands the
  /// Receiver has caught up with.
  final int lastAppliedSeq;

  /// Whether a Handoff is being loaded. The phone is still playing throughout.
  bool get isPreparingHandoff => phase == CastReceiverPhase.preparing;

  /// Whether this device is playing a cast video and is Playback Authority.
  bool get isCasting => phase == CastReceiverPhase.casting;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastReceiverUiState &&
        other.phase == phase &&
        other.sessionId == sessionId &&
        other.castVideoId == castVideoId &&
        other.controllerName == controllerName &&
        other.lastAppliedSeq == lastAppliedSeq;
  }

  @override
  int get hashCode => Object.hash(
        phase,
        sessionId,
        castVideoId,
        controllerName,
        lastAppliedSeq,
      );
}

/// The Receiver's half of a Cast Session.
///
/// It is the counterpart of the Cast Controller on the phone, and it is alive for as long as the
/// application is: a Handoff arrives on the connection, not from a screen, so there is nothing to
/// open first.
///
/// Handoff has two phases here too. A prepare command loads the requested video and answers that
/// the Receiver is ready, while leaving whatever it is already playing exactly as it is - the
/// phone is still the device playing, and a slow load must not interrupt the viewer. The commit
/// that follows carries where the viewer actually got to, and acting on it is what takes the
/// screen: there is no confirmation prompt, because casting is a one-action workflow.
///
/// Before a video already playing here is replaced, its progress is kept through the app's
/// ordinary playback-progress path, and that write is awaited rather than left to finish on its
/// own. A position written after the new video started would be a position nobody could rely on,
/// and returning to the displaced video later is the whole reason the write exists.
///
/// Only once the video has actually started does the Receiver report the state it reached. That
/// report is what makes it Playback Authority, and what the phone has been holding its own player
/// open for: nothing is taken away from the viewer until the Receiver is really playing.
///
/// From then on the phone can command it. Every command is absolute and numbered by its session,
/// and a command whose number is not greater than the last one accepted here has been overtaken: it
/// is thrown away rather than applied, so a reconnect cannot put the viewer back at a seek or a
/// volume they have already moved on from. [CastReceiverUiState.lastAppliedSeq] is that number.
///
/// While it is casting, this device is the only thing that knows what playback is doing, so it says
/// so continuously: every second while the video plays, at once when something meaningful changes,
/// and every five seconds while it is paused, as a heartbeat. Each report is the whole state, so a
/// phone that missed one converges on the next.
///
/// Crucially there is one reporting path and not two. A change the phone commanded and a change
/// somebody made with the Receiver's own remote both end up as the same news about the same
/// player, read from the player itself rather than from what anybody asked for. That is what lets
/// the person sitting at the Receiver keep control of the video without the phone ever disagreeing
/// with what is on screen.
///
/// That same reading of the player is where two of the ways a Cast Session ends come from, because
/// nothing else can see them. A Receiver showing no video, or a different one, is somebody here
/// having left the cast video or opened another; a video that reached its end has finished. Both end
/// the session with the reason that says so, and neither is something the phone or the API could
/// have worked out.
///
/// However a session ends, this Receiver is left paused with its player still on screen, so
/// somebody sitting in front of it can pick the video up again with its own remote. Nothing here
/// holds the screen awake for that: the player's own screen-awake behaviour follows whether it is
/// playing, so a paused Cast Session lets the Receiver sleep exactly as an ordinary paused video
/// does.
class CastReceiverController extends StateNotifier<CastReceiverUiState> {
  CastReceiverController({
    required CastGateway gateway,
    required CastReceiverPlayback playback,
    required CastPlaybackProgressWriter progressWriter,
    required CastDeviceIdentityRepository identityRepository,
    required CastClock clock,
    required LogService logService,
  })  : _gateway = gateway,
        _playback = playback,
        _progressWriter = progressWriter,
        _clock = clock,
        _logService = logService,
        super(CastReceiverUiState.initial) {
    _prepareSubscription = _gateway.watchPrepareCommands().listen(_onPrepare);
    _commitSubscription = _gateway.watchCommitCommands().listen(_onCommit);
    _commandSubscription = _gateway.watchCommands().listen(_onCommand);
    _sessionSubscription = _gateway.watchSession().listen(_onSession);
    unawaited(_readOwnDeviceId(identityRepository));
  }

  /// How often the player is read while this device is casting.
  ///
  /// The player is asked rather than listened to because what has to be noticed - somebody at the
  /// Receiver pressing play on its own remote - is a change in the player's own state and not an
  /// event anybody sends here. It is also what makes "reported immediately" mean something a test
  /// can tell apart from "reported because the interval elapsed".
  static const Duration samplePeriod = Duration(milliseconds: 250);

  /// How long a playing Receiver may go without saying anything.
  static const Duration playingReportPeriod = Duration(seconds: 1);

  /// How long a paused Receiver may go without saying anything. Nothing is moving, so this is a
  /// heartbeat rather than news, and it is slower for that reason.
  static const Duration pausedReportPeriod = Duration(seconds: 5);

  /// The furthest ordinary playback can have carried the position since the last report: one
  /// reporting interval, plus the sample that notices the interval has elapsed. A position that
  /// moved further than this, or moved backwards, is somebody seeking rather than the video playing.
  static final Duration _playbackDrift = playingReportPeriod + samplePeriod;

  final CastGateway _gateway;
  final CastReceiverPlayback _playback;
  final CastPlaybackProgressWriter _progressWriter;
  final CastClock _clock;
  final LogService _logService;

  StreamSubscription<CastPrepareCommand>? _prepareSubscription;
  StreamSubscription<CastCommitCommand>? _commitSubscription;
  StreamSubscription<CastCommand>? _commandSubscription;
  StreamSubscription<CastSession>? _sessionSubscription;

  CastReceiverPhase _phase = CastReceiverPhase.idle;
  String? _sessionId;
  int? _castVideoId;
  String? _controllerName;

  /// This installation's stable identity, or empty until it has been read.
  ///
  /// It is here for one question only: whether a session the API describes is one this device is
  /// the Receiver of. Both halves of a Cast Session hear the same session messages, so without it a
  /// phone's own Receiver Controller could not tell a session for another Receiver from its own.
  String _ownDeviceId = '';

  /// The session this device has already told the API it does not have, so that being told about
  /// it again does not say it twice.
  String? _reportedMissingSessionId;

  /// Whether the API answered the last report with "no such session", which is what a restarted
  /// API looks like from here.
  bool _sessionIsMissing = false;

  /// The number of the last command accepted in the current session. Zero between sessions, because
  /// numbering belongs to the session: a Receiver that kept comparing against a number from a
  /// session that is over would ignore every command of the next one.
  int _lastAppliedSeq = 0;

  /// The cadence, while this device is casting and only then.
  CastTimer? _reportTimer;

  /// The state the phone was last told about, and the number that went with it. Everything the
  /// cadence decides is decided against these: what has changed, and how long ago that was.
  CastLocalPlayback? _lastReported;
  int _lastReportedSeq = 0;
  Duration _sinceLastReport = Duration.zero;

  /// Whether a report is on its way. One at a time: a connection slower than the cadence would
  /// otherwise queue up reports that are already out of date by the time they are sent.
  bool _isReporting = false;

  @override
  void dispose() {
    _stopReporting();
    unawaited(_prepareSubscription?.cancel());
    unawaited(_commitSubscription?.cancel());
    unawaited(_commandSubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  /// Reads this installation's stable identity once, so that a session the API describes can be
  /// recognised as one this device is the Receiver of. A failure costs only that recognition, so it
  /// is logged rather than allowed to keep this device from taking a Handoff at all.
  Future<void> _readOwnDeviceId(
    CastDeviceIdentityRepository identityRepository,
  ) async {
    try {
      final String deviceId = await identityRepository.deviceId();
      if (mounted) {
        _ownDeviceId = deviceId.trim();
      }
    } catch (error, stackTrace) {
      _logService.error(
        'CastReceiverController could not read this device identity',
        error,
        stackTrace,
      );
    }
  }

  void _onPrepare(CastPrepareCommand command) {
    unawaited(_prepare(command));
  }

  void _onCommit(CastCommitCommand command) {
    unawaited(_commit(command));
  }

  void _onCommand(CastCommand command) {
    unawaited(_applyCommand(command));
  }

  /// Phase one: load the requested video and say so, without disturbing what is playing.
  Future<void> _prepare(CastPrepareCommand command) async {
    if (!mounted) {
      return;
    }

    // An account has at most one Cast Session, so a prepare that arrives while another Handoff is
    // being loaded is the only live one left and simply replaces it. Whatever this device was
    // reporting was about a session that is over.
    _stopReporting();
    _sessionId = command.sessionId;
    _castVideoId = command.videoId;
    _controllerName = command.controllerName;
    _phase = CastReceiverPhase.preparing;
    // Numbering is the session's, so a new Handoff starts counting from nothing.
    _lastAppliedSeq = 0;
    _sessionIsMissing = false;
    _rebuild();

    try {
      await _playback.prepare(command.videoId);
      if (!_isStillHandling(command.sessionId)) {
        return;
      }
      await _gateway.confirmPrepared(sessionId: command.sessionId);
    } catch (error, stackTrace) {
      // Saying nothing is the honest answer: a Receiver that could not load the video must not
      // claim to be prepared. Nothing has been taken away from anyone - the phone is still playing
      // - and the API's own one-minute window ends the Handoff.
      _logService.error(
        'CastReceiverController could not prepare a cast video',
        error,
        stackTrace,
      );
      if (_isStillHandling(command.sessionId)) {
        _leaveCastState();
      }
    }
  }

  /// Phase two: keep the displaced video's progress, take the screen, and report what was reached.
  Future<void> _commit(CastCommitCommand command) async {
    if (!_isStillHandling(command.sessionId)) {
      // A commit for a Handoff this device is not in the middle of cannot take its screen.
      return;
    }
    if (_phase != CastReceiverPhase.preparing ||
        command.videoId != _castVideoId) {
      return;
    }

    await _keepDisplacedProgress(command.videoId);
    if (!_isStillHandling(command.sessionId)) {
      return;
    }

    try {
      final CastLocalPlayback reached = await _playback.start(
        videoId: command.videoId,
        position: command.position,
        isPlaying: command.isPlaying,
      );
      if (!_isStillHandling(command.sessionId)) {
        return;
      }

      _phase = CastReceiverPhase.casting;
      _rebuild();

      // What the Receiver actually reached, not what it was asked for. The Controller renders
      // this and never its own guess, and this first report is what turns the session active and
      // lets the phone let go of its own player. Everything that follows goes the same way.
      final bool told = await _report(command.sessionId, reached);
      if (!_isStillHandling(command.sessionId)) {
        return;
      }
      if (!told) {
        // The phone never heard that this Receiver took over, so it is still the device playing.
        // Claiming Playback Authority nobody was told about would leave the two disagreeing.
        _leaveCastState();
        return;
      }
      _startReporting();
    } catch (error, stackTrace) {
      _logService.error(
        'CastReceiverController could not take over playback',
        error,
        stackTrace,
      );
      if (_isStillHandling(command.sessionId)) {
        _leaveCastState();
      }
    }
  }

  /// Acts on one command from the phone, or throws it away.
  ///
  /// Three things have to be true before the player is touched: the command belongs to the Handoff
  /// this device is in the middle of, this device is actually playing the cast video, and the
  /// command has not been overtaken.
  ///
  /// The last of those is what the numbering is for. The Controller's commands are absolute, so
  /// applying an old one would not be a small error - it would put the viewer back at a position or
  /// a volume they have already moved on from. The number is taken before the player is touched, so
  /// two commands arriving back to back cannot both pass the check, and a command that then fails
  /// to apply still counts as accepted: retrying it would be replaying it.
  Future<void> _applyCommand(CastCommand command) async {
    if (!_isStillHandling(command.sessionId)) {
      return;
    }
    if (_phase != CastReceiverPhase.casting) {
      // Nothing to command yet. Until the commit lands, the phone is the device playing and its own
      // local controls are what the viewer is using.
      return;
    }
    if (command.seq <= _lastAppliedSeq) {
      return;
    }

    _lastAppliedSeq = command.seq;
    _rebuild();

    try {
      if (command.type == CastCommandType.setPlaying) {
        await _playback.setPlaying(command.isPlaying ?? false);
      } else if (command.type == CastCommandType.seekTo) {
        await _playback.seekTo(command.position ?? Duration.zero);
      } else if (command.type == CastCommandType.setVolume) {
        await _playback.setVolume(command.volume ?? 1.0);
      }
    } catch (error, stackTrace) {
      // The Cast Session is not over because one command did not land. The phone renders the state
      // this device reports, so a command that failed simply never shows up as having happened.
      _logService.error(
        'CastReceiverController could not apply a cast command',
        error,
        stackTrace,
      );
    }
  }

  /// Starts saying what this device is playing, for as long as it is Playback Authority.
  ///
  /// What was already said is deliberately kept: the commit's own report has just gone out, and the
  /// cadence measures from it rather than starting over and repeating it a moment later.
  void _startReporting() {
    _reportTimer?.cancel();
    _sinceLastReport = Duration.zero;
    _reportTimer = _clock.periodic(samplePeriod, _onSample);
  }

  /// Stops saying it, and forgets what was last said: the next Cast Session starts from nothing.
  void _stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _lastReported = null;
    _lastReportedSeq = 0;
    _sinceLastReport = Duration.zero;
  }

  void _onSample() {
    unawaited(_reportIfDue());
  }

  /// One look at the player, and a decision about whether the phone needs telling - or whether
  /// there is still a Cast Session at all.
  ///
  /// The whole cadence is here: something meaningful changed, a command landed, or enough time has
  /// gone by - a second while the video plays, five while it is paused. Nothing else reaches the
  /// phone, and everything that does comes from reading the player rather than from remembering what
  /// anybody asked it to do.
  ///
  /// Two ways a Cast Session ends are here for the same reason. A Receiver showing no video, or a
  /// different one, and a video that reached its end are both things only this device can see, and
  /// it sees them by reading the player exactly as it reads everything else.
  Future<void> _reportIfDue() async {
    final String? sessionId = _sessionId;
    if (!mounted ||
        sessionId == null ||
        _phase != CastReceiverPhase.casting ||
        _isReporting) {
      return;
    }

    _sinceLastReport += samplePeriod;

    final CastLocalPlayback? playback = _playback.readPlayback();
    if (playback == null || playback.videoId != _castVideoId) {
      // Somebody at the Receiver left the cast video or opened another one, so there is nothing
      // here for the phone to control any more. Nothing is paused on the way out: whatever is on
      // screen now is this room's own business, and this device never owned it.
      await _endSession(
        sessionId,
        CastEndReason.receiverNavigatedAway,
        pausePlayback: false,
      );
      return;
    }

    if (playback.isCompleted) {
      // The video reached its end. The phone hears that before it hears the session is over, so
      // the ended session carries a completed state - which is the whole of what stops the phone
      // from starting a finished video again.
      if (_lastReported?.isCompleted != true) {
        await _report(sessionId, playback);
        if (!_isStillHandling(sessionId)) {
          return;
        }
      }
      await _endSession(
        sessionId,
        CastEndReason.playbackCompleted,
        pausePlayback: true,
      );
      return;
    }

    if (!_isReportDue(playback)) {
      return;
    }
    await _report(sessionId, playback);

    if (_sessionIsMissing && _isStillHandling(sessionId)) {
      // The API has no such session, which is what a restarted API looks like from here. There is
      // nothing to tell it and nobody it could tell, so this Receiver simply stops being
      // Playback Authority - paused, with its player still on screen.
      _leaveCastState();
      await _pausePlayback();
    }
  }

  bool _isReportDue(CastLocalPlayback playback) {
    final CastLocalPlayback? last = _lastReported;
    if (last == null) {
      return true;
    }
    if (_lastAppliedSeq != _lastReportedSeq) {
      // A command landed. The phone is waiting to see that it did.
      return true;
    }
    if (_isMeaningfulChange(last, playback)) {
      return true;
    }
    return _sinceLastReport >=
        (playback.isPlaying ? playingReportPeriod : pausedReportPeriod);
  }

  /// Whether [now] is different enough from [last] that the phone should hear about it at once
  /// rather than at the next interval.
  ///
  /// Everything except the position is meaningful whenever it differs: a video that started or
  /// finished, playing or paused, buffering, a different length, a different volume. The position is
  /// the one value that changes by itself, so only a move ordinary playback could not have made
  /// counts - which is exactly what a seek is, whoever performed it.
  static bool _isMeaningfulChange(
    CastLocalPlayback last,
    CastLocalPlayback now,
  ) {
    return now.videoId != last.videoId ||
        now.isPlaying != last.isPlaying ||
        now.isBuffering != last.isBuffering ||
        now.isCompleted != last.isCompleted ||
        now.duration != last.duration ||
        now.volume != last.volume ||
        _hasSeeked(last, now);
  }

  static bool _hasSeeked(CastLocalPlayback last, CastLocalPlayback now) {
    final Duration moved = now.position - last.position;
    if (!last.isPlaying && !now.isPlaying) {
      // A paused video does not move by itself, so any movement at all is somebody seeking.
      return moved != Duration.zero;
    }
    return moved.isNegative || moved > _playbackDrift;
  }

  /// Tells the phone what this device is playing, and answers whether it heard.
  ///
  /// The bookkeeping is done before the call rather than after it, for the same reason the applied
  /// command number is: everything between here and the answer is another chance for the cadence to
  /// decide the same report is due again. An attempt therefore counts as an attempt even when it
  /// fails - reports are absolute rather than deltas, so the next one carries everything the lost
  /// one would have, and a connection that is down does not turn the cadence into a retry storm.
  Future<bool> _report(String sessionId, CastLocalPlayback playback) async {
    _isReporting = true;
    _lastReported = playback;
    _lastReportedSeq = _lastAppliedSeq;
    _sinceLastReport = Duration.zero;

    try {
      await _gateway.reportPlaybackState(
        sessionId: sessionId,
        videoId: playback.videoId,
        position: playback.position,
        duration: playback.duration,
        isPlaying: playback.isPlaying,
        isBuffering: playback.isBuffering,
        isCompleted: playback.isCompleted,
        volume: playback.volume,
        lastAppliedSeq: _lastReportedSeq,
      );
      return true;
    } catch (error, stackTrace) {
      // A refusal that says the API has no such session means more than a report that was lost:
      // there is no Cast Session left to report to, and the caller acts on it rather than trying
      // again a second later.
      _sessionIsMissing =
          CastErrorReason.tryParse(error) == CastErrorReason.sessionNotFound;
      _logService.error(
        'CastReceiverController could not report its playback state',
        error,
        stackTrace,
      );
      return false;
    } finally {
      _isReporting = false;
    }
  }

  /// Keeps the progress of the video the cast is about to replace, before it is replaced.
  ///
  /// There is nothing to keep when the Receiver is playing nothing, when what it is playing is
  /// already the cast video - that is a reposition rather than a replacement - or when the
  /// displaced video is still at its very start, where a written zero would only overwrite a real
  /// position with nothing.
  Future<void> _keepDisplacedProgress(int castVideoId) async {
    final CastLocalPlayback? displaced = _playback.readPlayback();
    if (displaced == null ||
        displaced.videoId <= 0 ||
        displaced.videoId == castVideoId ||
        displaced.position <= Duration.zero) {
      return;
    }

    try {
      await _progressWriter.saveProgress(
        videoId: displaced.videoId,
        position: displaced.position,
      );
    } catch (error, stackTrace) {
      // The cast still happens. One lost position is worth a log; refusing the Handoff the viewer
      // asked for because of it is not.
      _logService.error(
        'CastReceiverController could not keep the displaced video progress',
        error,
        stackTrace,
      );
    }
  }

  void _onSession(CastSession session) {
    if (!_isStillHandling(session.sessionId)) {
      // News about a Handoff this device has already left behind is not news about the one it is
      // in now - with one exception, which is a session it has never heard of at all.
      _sayThisReceiverDoesNotHaveIt(session);
      return;
    }

    if (session.isLive) {
      _castVideoId = session.videoId;
      if (session.controllerName.isNotEmpty) {
        _controllerName = session.controllerName;
      }
      _rebuild();
      return;
    }

    // Ended - or a status this version does not know, which is treated the same way on purpose.
    // Either way this device is nobody's Playback Authority any more.
    final bool wasCasting = _phase == CastReceiverPhase.casting;
    _leaveCastState();

    if (wasCasting) {
      // Every way a Cast Session ends leaves this Receiver paused: playback asked for back, a
      // video that finished, a phone that never came back, somebody signing out, a session the API
      // no longer has, and a reason this version has never heard of. None of them is a reason to go
      // on playing to a room whose remote has stopped working.
      //
      // A Handoff that ended before it committed is the one case with nothing to pause. This device
      // was never playing the cast video, and pausing would stop whatever the person in front of it
      // was watching all along.
      unawaited(_pausePlayback());
    }
  }

  /// The Receiver's application restarted while a Cast Session was live.
  ///
  /// The API knows this device by the stable identity it registers under, so it binds it back to
  /// the session it was in and goes on describing one - but nothing here is playing the cast video
  /// and there is no Handoff half-finished to pick up. Left alone, the phone would hold a remote for
  /// a Receiver showing nothing.
  ///
  /// Saying the session is missing is the honest answer, and it is the same answer the phone gives
  /// when a restarted API has lost it: whichever of the two devices no longer has the session, both
  /// leave cast state and neither is left in a false Remote Control Mode.
  ///
  /// The identity is what makes this safe to act on. Both halves of a Cast Session hear the same
  /// session messages, so a phone's own Receiver Controller hears every session that phone is the
  /// Controller of; only a session that names this device as its Receiver is one this device ought
  /// to have.
  void _sayThisReceiverDoesNotHaveIt(CastSession session) {
    final String ownDeviceId = _ownDeviceId;
    if (!session.isLive ||
        _sessionId != null ||
        ownDeviceId.isEmpty ||
        session.receiverDeviceId != ownDeviceId ||
        session.sessionId == _reportedMissingSessionId) {
      return;
    }

    _reportedMissingSessionId = session.sessionId;
    unawaited(_endOnApi(session.sessionId, CastEndReason.sessionMissing));
  }

  /// Leaves the Cast Session because of something only this device could see, and tells the API so
  /// the phone hears it too.
  ///
  /// Cast state is left first, which stops the cadence: a reason read off the player would
  /// otherwise be read again, and said again, while the API is being told about it once.
  Future<void> _endSession(
    String sessionId,
    CastEndReason reason, {
    required bool pausePlayback,
  }) async {
    _leaveCastState();
    if (pausePlayback) {
      await _pausePlayback();
    }
    await _endOnApi(sessionId, reason);
  }

  Future<void> _endOnApi(String sessionId, CastEndReason reason) async {
    try {
      await _gateway.endSession(sessionId: sessionId, reason: reason);
    } catch (error, stackTrace) {
      // This device has left the session either way. An end the API refused - most often because it
      // had already ended the session itself - changes nothing here.
      _logService.error(
        'CastReceiverController could not end its Cast Session',
        error,
        stackTrace,
      );
    }
  }

  /// Pauses this Receiver, leaving its player screen open.
  ///
  /// Somebody still sitting in front of it can pick the video up again with its own remote, and a
  /// paused player holds the screen awake no more than any other paused video does.
  Future<void> _pausePlayback() async {
    try {
      await _playback.setPlaying(false);
    } catch (error, stackTrace) {
      // The Cast Session is over either way. A Receiver that would not pause - one whose player
      // screen has already gone, most likely - is worth a log and nothing else.
      _logService.error(
        'CastReceiverController could not pause after its Cast Session ended',
        error,
        stackTrace,
      );
    }
  }

  /// Whether [sessionId] is still the Handoff this device is in the middle of. Everything that
  /// resumes after an await checks it, so a Handoff that ended meanwhile cannot be carried on with.
  bool _isStillHandling(String sessionId) {
    return mounted && _sessionId != null && _sessionId == sessionId;
  }

  void _leaveCastState() {
    _stopReporting();
    _phase = CastReceiverPhase.idle;
    _sessionId = null;
    _castVideoId = null;
    _controllerName = null;
    _lastAppliedSeq = 0;
    _sessionIsMissing = false;
    _rebuild();
  }

  void _rebuild() {
    state = CastReceiverUiState(
      phase: _phase,
      sessionId: _sessionId,
      castVideoId: _castVideoId,
      controllerName: _controllerName,
      lastAppliedSeq: _lastAppliedSeq,
    );
  }
}

/// Deliberately not auto-disposed, and supplied by the composition root rather than built here: a
/// Handoff arrives on the connection, and a Receiver that only listened while some particular
/// page was open would be unreachable exactly when the viewer wants to cast to it, so the one
/// Receiver of this installation is created with the application.
///
/// It builds nothing of its own on purpose. Providers are lazy, so a factory here would look like
/// the definition of this controller while never running - and the first screen that did watch it
/// would get a second Receiver, with its own connection subscriptions and its own clock, alongside
/// the one the application has been running all along.
final StateNotifierProvider<CastReceiverController, CastReceiverUiState>
    castReceiverControllerProvider =
    StateNotifierProvider<CastReceiverController, CastReceiverUiState>(
  (Ref ref) => throw UnimplementedError(),
);
