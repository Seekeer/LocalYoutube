import '../../sync/domain/sync_models.dart';
import 'cast_models.dart';
import 'cast_session_models.dart';

/// Everything the Cast Session needs from the connection to the API.
///
/// Narrow on purpose. The real implementation is the SignalR hub the rest of the app already keeps
/// open, but nothing above this interface knows that, so the Cast Controller and the registration
/// service can be driven by a fake in a test without a socket, a token or a server.
abstract interface class CastGateway {
  /// Whether the connection is usable right now.
  SyncConnectionState get connectionState;

  Stream<SyncConnectionState> watchConnectionState();

  /// The account's devices as the API last reported them.
  CastDevicesSnapshot get devices;

  /// Every authoritative snapshot the API reports: the answer to a registration and every later
  /// change on the account. Always the full list, never a delta.
  Stream<CastDevicesSnapshot> watchDevices();

  /// Announces this installation and answers with the account's snapshot.
  ///
  /// Calling it again rebinds the same stable identity rather than adding a second device, which is
  /// what makes re-registering after a rename or a Receiver Mode change safe.
  Future<CastDevicesSnapshot> registerDevice(
    CastDeviceRegistration registration,
  );

  /// Every change to the Cast Session this device takes part in, as the API pushes it.
  ///
  /// Always the whole session, so a client that missed a message still converges on the next one.
  Stream<CastSession> watchSession();

  /// Phase one of Handoff: asks [receiverDeviceId] to load [videoId].
  ///
  /// Local playback is deliberately untouched - the phone keeps playing while a slow Receiver
  /// gets ready, and where the viewer is only travels with [commitSession].
  ///
  /// Throws when the API refuses, carrying one of the [CastErrorReason] values.
  Future<CastSession> startSession({
    required String receiverDeviceId,
    required int videoId,
  });

  /// Phase two of Handoff: hands over the latest absolute position and the playing/paused intent.
  ///
  /// The Receiver confirms what it actually reached afterwards, and only that confirmation lets the
  /// phone give up its local player.
  Future<CastSession> commitSession({
    required String sessionId,
    required Duration position,
    required bool isPlaying,
  });

  /// Tells the Receiver to play or to pause. Absolute, so a command that was lost cannot leave the
  /// two devices disagreeing about what a toggle would have meant.
  ///
  /// The API numbers the command and passes it on; the answer is the session as it stands, which a
  /// command never changes. What the Receiver actually reached comes back through the state it
  /// reports, and that is the only thing Remote Control Mode renders.
  Future<CastSession> setReceiverPlaying({
    required String sessionId,
    required bool isPlaying,
  });

  /// Tells the Receiver to go to an absolute position. Timestamp selection travels as one of these.
  Future<CastSession> seekReceiver({
    required String sessionId,
    required Duration position,
  });

  /// Tells the Receiver to set the LocalTube player's volume, from 0 (silent) to 1 (loudest).
  ///
  /// It is the player's own volume and never the Android system volume, so casting cannot turn
  /// down anything else on the Receiver.
  Future<CastSession> setReceiverVolume({
    required String sessionId,
    required double volume,
  });

  /// Every command the API sends this device as a Receiver, each numbered by its session.
  ///
  /// A command whose number is not greater than the last one applied has been overtaken and is
  /// ignored, which is what stops a reconnect from replaying an old seek or volume.
  Stream<CastCommand> watchCommands();

  /// Backs out of a Handoff that has not committed, and answers with the ended session.
  ///
  /// Local playback was never given up, so there is nothing to bring back: the viewer simply keeps
  /// watching here. The API refuses this once the Receiver is playing - stopping that is Return
  /// Handoff - and refuses it for a session that has already run out of time, which is the same
  /// outcome seen from the other side.
  Future<CastSession> cancelSession({required String sessionId});

  /// Return Handoff: brings playback back to the Controller, and answers with the ended session.
  ///
  /// Only the initiating Controller may, and only once the Receiver is actually playing. The API
  /// ends the session with [CastEndReason.returnHandoff] and tells the Receiver, which is what
  /// stops the Receiver; the ended session still carries the last state the Receiver confirmed,
  /// so the phone continues from a position both devices had already agreed on.
  ///
  /// Backing out of a Handoff that never reached the Receiver is [cancelSession] instead: there
  /// is nothing there to bring back, and this is refused for such a session.
  Future<CastSession> returnHandoff({required String sessionId});

  /// Ends the Cast Session this device takes part in, for a reason only this device can know.
  ///
  /// There is no reconnect window on any of these, and that is the point. A window exists because
  /// a dropped connection is usually a lift or a tunnel; none of these is. The device is still
  /// there and has said what happened, so waiting a minute would be waiting for something that has
  /// already occurred.
  ///
  /// [reason] must be one a device may declare: [CastEndReason.receiverNavigatedAway] and
  /// [CastEndReason.playbackCompleted] from the Receiver only,
  /// [CastEndReason.participantSignedOut] and [CastEndReason.sessionMissing] from either. Anything
  /// else is refused with [CastErrorReason.unknownEndReason]; the other four reasons are the API's
  /// own conclusions and have their own calls or timers.
  ///
  /// A blank [sessionId] means "whichever session I am in", which is what a device that is signing
  /// out wants: it is leaving whatever it was doing rather than reasoning about which side of a
  /// session it was on. Naming one refuses to end anything else, so an end overtaken by a later
  /// Handoff ends nothing.
  ///
  /// Answers `null` when there was nothing to end - no session, or one this device takes no part
  /// in. Ending is something a device does on its way out, so that is an ordinary answer.
  Future<CastSession?> endSession({
    String? sessionId,
    required CastEndReason reason,
  });

  /// What the API has for the session this device believes it is in.
  ///
  /// Cast Sessions live only in the API's memory, so a restarted API has none of them while a phone
  /// is still holding a remote for one. Nothing would ever arrive to say so - a device in Remote
  /// Control Mode is waiting to be told things rather than asking - so this is how it finds out.
  ///
  /// It does not refuse: a session the API does not have comes back ended with
  /// [CastEndReason.sessionMissing], which is something the device can act on, and so does a
  /// session of this account that this device takes no part in.
  Future<CastSession> resolveSession({required String sessionId});

  /// Every phase-one Handoff command the API sends this device as a Receiver.
  ///
  /// The Receiver is asked to load a video and nothing else: the phone is still playing, and it
  /// stays that way until the commit arrives.
  Stream<CastPrepareCommand> watchPrepareCommands();

  /// Every phase-two Handoff command the API sends this device as a Receiver, carrying where the
  /// viewer actually is and whether they were playing or paused.
  Stream<CastCommitCommand> watchCommitCommands();

  /// Tells the API the Receiver has the video loaded and is waiting for the commit.
  ///
  /// Only the session's own Receiver may, and only while the Handoff is still preparing; anything
  /// else is refused with one of the [CastErrorReason] values.
  Future<CastSession> confirmPrepared({required String sessionId});

  /// Reports the playback state the Receiver is actually in: Playback Authority, as often as it
  /// changes.
  ///
  /// The first of these is what makes the Receiver Playback Authority: the session turns active and
  /// the phone finally releases its local player. The ones that follow keep the phone up to date -
  /// every second while playing, at once when something meaningful changes, and every five seconds
  /// while paused.
  ///
  /// It carries the whole state rather than a part of it, because a phone that rendered less would
  /// be guessing at the rest. [lastAppliedSeq] is the number of the last Controller command this
  /// Receiver applied, or 0 for none, so the phone can see which of its commands it has
  /// caught up with.
  ///
  /// There is one of these rather than two on purpose. A change the phone commanded and a change
  /// somebody made with the Receiver's own remote are the same news about the same playback, so
  /// both travel here.
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
  });
}
