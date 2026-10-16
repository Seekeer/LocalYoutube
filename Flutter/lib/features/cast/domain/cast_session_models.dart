/// The Cast Session protocol as it travels over SignalR.
///
/// Every literal in this file is the API's wire contract, observed against the real hub in
/// `src/Api.IntegrationTests/CastProtocolWireFormatTests.cs` and declared once on the server in
/// `src/BookStore.API/SignalR/Cast/CastProtocol.cs`. Changing a string here changes the protocol.
///
/// Values this client does not recognise never leave a device stuck. An unknown status and an
/// unknown end reason both read as `unknown`, which the Cast Controller treats exactly like a
/// session that ended: the phone leaves Remote Control Mode and goes back to playing locally,
/// rather than sitting in a mode it cannot reason about. An unrecognised refusal is likewise still
/// a refusal.
library;

/// Where a Cast Session is in its life, as the API reports it.
///
/// All four states exist from the start even though this version of the app only ever sees three
/// of them: the API is free to report [reconnecting] as soon as the slice that introduces it lands,
/// and an installed client has to understand it rather than treat it as a broken message.
enum CastSessionStatus {
  /// Handoff has started. The Receiver is loading the video; the phone is still playing it.
  preparing('preparing'),

  /// The Receiver has confirmed its playback state and is now Playback Authority.
  active('active'),

  /// A participant is inside its reconnect window. The session is still this device's.
  reconnecting('reconnecting'),

  /// Over. [CastSession.endReason] says why.
  ended('ended'),

  /// A status this client does not know, treated exactly like [ended].
  unknown('');

  const CastSessionStatus(this.wireValue);

  /// The value the API sends for this status. Empty for [unknown], which never travels.
  final String wireValue;

  /// Whether the Receiver is still this device's playback, so Remote Control Mode stays.
  bool get isLive =>
      this == preparing || this == active || this == reconnecting;

  /// Never fails: anything unrecognised reads as [unknown] so the device leaves cast state.
  static CastSessionStatus parse(Object? rawValue) {
    if (rawValue is String) {
      final String value = rawValue.trim();
      for (final CastSessionStatus status in CastSessionStatus.values) {
        if (status != CastSessionStatus.unknown && status.wireValue == value) {
          return status;
        }
      }
    }
    return CastSessionStatus.unknown;
  }
}

/// Why a Cast Session ended.
///
/// The whole vocabulary is here from the start for the same reason the statuses are: the API can
/// begin sending any of these at any time, and a client that met one it had never heard of would
/// otherwise have no defined thing to do.
enum CastEndReason {
  /// The viewer asked for playback back on the phone.
  returnHandoff('returnHandoff'),

  /// The viewer cancelled a Handoff that had not committed.
  handoffCancelled('handoffCancelled'),

  /// Preparation did not finish inside its window.
  handoffExpired('handoffExpired'),

  /// The Receiver left the cast video or opened another one.
  receiverNavigatedAway('receiverNavigatedAway'),

  /// The video reached its duration.
  playbackCompleted('playbackCompleted'),

  /// A participant logged out or stopped offering itself in that role.
  participantSignedOut('participantSignedOut'),

  /// A participant did not come back before its reconnect window ran out.
  participantTimeout('participantTimeout'),

  /// The server has no such session, which is what an API restart looks like.
  sessionMissing('sessionMissing'),

  /// A reason this client does not know. The session still ended.
  unknown('');

  const CastEndReason(this.wireValue);

  final String wireValue;

  /// Never fails: anything unrecognised reads as [unknown], and the session still ended.
  static CastEndReason parse(Object? rawValue) {
    if (rawValue is String) {
      final String value = rawValue.trim();
      for (final CastEndReason reason in CastEndReason.values) {
        if (reason != CastEndReason.unknown && reason.wireValue == value) {
          return reason;
        }
      }
    }
    return CastEndReason.unknown;
  }
}

/// What the Controller is asking the Receiver to do.
///
/// Every command is absolute: it says what the state is to become rather than how to change it.
/// There is deliberately no toggle and no stop. A toggle that was lost, or applied twice, would
/// leave the two devices disagreeing about what it meant, and stopping a session is Return Handoff
/// rather than a command to the player.
enum CastCommandType {
  /// Play or pause. The command names the state to reach.
  setPlaying('setPlaying'),

  /// Go to an absolute position from the start of the video. Timestamp selection is one of these:
  /// the phone works out which timestamp it means and sends the position.
  seekTo('seekTo'),

  /// Set the LocalTube player's own volume, normalised from 0 (silent) to 1 (loudest). It is the
  /// player's volume and never the Android system volume.
  setVolume('setVolume'),

  /// A command this version does not know. It is never acted on.
  unknown('');

  const CastCommandType(this.wireValue);

  /// The value the API sends for this command. Empty for [unknown], which never travels.
  final String wireValue;

  /// Never fails: anything unrecognised reads as [unknown], which a Receiver ignores rather than
  /// guessing at.
  static CastCommandType parse(Object? rawValue) {
    if (rawValue is String) {
      final String value = rawValue.trim();
      for (final CastCommandType type in CastCommandType.values) {
        if (type != CastCommandType.unknown && type.wireValue == value) {
          return type;
        }
      }
    }
    return CastCommandType.unknown;
  }
}

/// One absolute command from the Controller, as the API sends it to the Receiver.
///
/// [seq] is the command's place in its session's order. It starts at 1 for each Cast Session and
/// only ever goes up, and the API is the one that hands it out, so two commands can never carry the
/// same number and a phone that reconnected and lost count cannot repeat one. A Receiver ignores a
/// command whose number is not greater than the last one it applied, which is what stops a reconnect
/// from replaying an old seek or volume after a newer one.
///
/// Exactly one of [isPlaying], [position] and [volume] is filled in - the one [type] names. Reading
/// another would be reading a value nobody sent.
class CastCommand {
  const CastCommand({
    required this.sessionId,
    required this.seq,
    required this.type,
    this.isPlaying,
    this.position,
    this.volume,
  });

  final String sessionId;

  /// This command's place in its session's order. Greater than zero.
  final int seq;

  final CastCommandType type;

  /// The state to reach, for [CastCommandType.setPlaying].
  final bool? isPlaying;

  /// The absolute position to go to, for [CastCommandType.seekTo].
  final Duration? position;

  /// The player's volume from 0 to 1, for [CastCommandType.setVolume].
  final double? volume;

  /// Returns `null` when the payload is not a command this client can act on.
  ///
  /// A command without a session, without a number, of a type this version does not know, or
  /// missing the value its own type names, is not guessed at. Ignoring it leaves the Receiver
  /// exactly as the viewer last saw it, which is the only safe thing to do with an instruction
  /// whose meaning was never agreed.
  static CastCommand? tryParse(Object? rawValue) {
    if (rawValue is! Map<Object?, Object?>) {
      return null;
    }
    final String sessionId = _readString(rawValue['sessionId']);
    final int seq = _readInt(rawValue['seq']) ?? 0;
    if (sessionId.isEmpty || seq <= 0) {
      return null;
    }

    final CastCommandType type = CastCommandType.parse(rawValue['type']);
    switch (type) {
      case CastCommandType.setPlaying:
        final Object? isPlaying = rawValue['isPlaying'];
        if (isPlaying is! bool) {
          return null;
        }
        return CastCommand(
          sessionId: sessionId,
          seq: seq,
          type: type,
          isPlaying: isPlaying,
        );
      case CastCommandType.seekTo:
        final int? milliseconds = _readInt(rawValue['positionMs']);
        if (milliseconds == null || milliseconds < 0) {
          return null;
        }
        return CastCommand(
          sessionId: sessionId,
          seq: seq,
          type: type,
          position: Duration(milliseconds: milliseconds),
        );
      case CastCommandType.setVolume:
        final double? volume = _readVolume(rawValue['volume']);
        if (volume == null) {
          return null;
        }
        return CastCommand(
          sessionId: sessionId,
          seq: seq,
          type: type,
          volume: volume,
        );
      case CastCommandType.unknown:
        return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastCommand &&
        other.sessionId == sessionId &&
        other.seq == seq &&
        other.type == type &&
        other.isPlaying == isPlaying &&
        other.position == position &&
        other.volume == volume;
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, seq, type, isPlaying, position, volume);
}

/// Why the API refused a cast call.
///
/// These arrive as the message of a hub exception rather than in a payload, so they are read out of
/// whatever the transport wrapped them in. A refusal this client cannot name is still a refusal:
/// the caller reports a failure and goes back to local playback instead of waiting.
class CastErrorReason {
  const CastErrorReason._();

  /// The account already has a Cast Session, and a second start never takes it over.
  static const String sessionAlreadyActive = 'sessionAlreadyActive';

  /// No live session of this account carries that identifier.
  static const String sessionNotFound = 'sessionNotFound';

  /// The session has left the preparing phase, so Handoff cannot be advanced again.
  static const String sessionNotPreparing = 'sessionNotPreparing';

  /// The Receiver is not playing yet, so there is nothing for a command to act on. A phone that
  /// commanded a Receiver the API does not yet consider active has simply got ahead of it.
  static const String sessionNotActive = 'sessionNotActive';

  /// This device is not the one that started the session.
  static const String notSessionController = 'notSessionController';

  /// This device is not the one the session casts to.
  static const String notSessionReceiver = 'notSessionReceiver';

  /// This connection never said what device it is.
  static const String deviceNotRegistered = 'deviceNotRegistered';

  /// The chosen Receiver is not online under that identity on this account.
  static const String receiverUnavailable = 'receiverUnavailable';

  /// Commit arrived before the Receiver said the video was loaded.
  static const String receiverNotPrepared = 'receiverNotPrepared';

  /// A device cannot hand playback over to itself.
  static const String cannotCastToSelf = 'cannotCastToSelf';

  /// The Receiver reported a different video than the session casts.
  static const String videoMismatch = 'videoMismatch';

  /// The API refused to end a session for a reason no device may declare. Four of the end reasons
  /// are the API's own conclusions to draw, and a client naming one of those would be ending a
  /// session over something that did not happen.
  static const String unknownEndReason = 'unknownEndReason';

  /// Not a wire value: what this client reports when the API refused for a reason it does not
  /// know. The cast simply did not happen, and the viewer keeps watching locally.
  static const String unrecognised = 'castFailed';

  /// Every refusal this client can name.
  static const List<String> known = <String>[
    sessionAlreadyActive,
    sessionNotFound,
    sessionNotPreparing,
    sessionNotActive,
    notSessionController,
    notSessionReceiver,
    deviceNotRegistered,
    receiverUnavailable,
    receiverNotPrepared,
    cannotCastToSelf,
    videoMismatch,
    unknownEndReason,
  ];

  /// The reason inside [error], or `null` when this client does not recognise it.
  static String? tryParse(Object? error) {
    if (error == null) {
      return null;
    }
    final String text = error.toString();
    for (final String reason in known) {
      if (text.contains(reason)) {
        return reason;
      }
    }
    return null;
  }
}

/// The Receiver's confirmed playback state: Playback Authority, as it travels on the wire.
///
/// The Controller renders this and never its own optimistic guess. There is deliberately no
/// optimistic seek and no optimistic volume: the phone is allowed to lag by the reporting interval
/// rather than show a command that failed to apply.
///
/// It is the whole state rather than a part of it, because during a Cast Session it is the only
/// description of playback the phone has, and it is always complete rather than a delta, so a phone
/// that missed one converges on the next.
class CastPlaybackState {
  const CastPlaybackState({
    required this.videoId,
    required this.position,
    required this.isPlaying,
    this.duration = Duration.zero,
    this.isBuffering = false,
    this.isCompleted = false,
    this.volume = 1.0,
    this.lastAppliedSeq = 0,
  });

  final int videoId;

  /// Absolute position from the start of the video.
  final Duration position;

  final bool isPlaying;

  /// How long the video is, or zero while the Receiver does not know yet.
  final Duration duration;

  /// Whether the Receiver is waiting for data rather than showing the video.
  final bool isBuffering;

  /// Whether the video has reached its end.
  final bool isCompleted;

  /// The LocalTube player's volume on the Receiver, from 0 (silent) to 1 (loudest). It is the
  /// Receiver's own and never this phone's.
  final double volume;

  /// The number of the last Controller command the Receiver applied, or 0 when it has applied none.
  /// Commands are numbered by the session, so this starts again with each Cast Session.
  ///
  /// The phone reads it rather than assuming a command it sent has landed.
  final int lastAppliedSeq;

  /// Returns `null` when the payload is not a playback state this client can use.
  ///
  /// A value the protocol has no meaning for is read as the nearest thing that does rather than
  /// failing the whole state: a Receiver that is playing is more use to the viewer than a phone
  /// showing nothing because one field was unreadable.
  static CastPlaybackState? tryParse(Object? rawValue) {
    if (rawValue is! Map<Object?, Object?>) {
      return null;
    }
    final int? videoId = _readInt(rawValue['videoId']);
    if (videoId == null || videoId <= 0) {
      return null;
    }
    final int lastAppliedSeq = _readInt(rawValue['lastAppliedSeq']) ?? 0;
    return CastPlaybackState(
      videoId: videoId,
      position: _readPosition(rawValue['positionMs']),
      isPlaying: rawValue['isPlaying'] == true,
      duration: _readPosition(rawValue['durationMs']),
      isBuffering: rawValue['isBuffering'] == true,
      isCompleted: rawValue['isCompleted'] == true,
      // A volume outside the player's range is a value this protocol has no meaning for, so it
      // reads as loudest - where a player nobody has turned down already is.
      volume: _readVolume(rawValue['volume']) ?? 1.0,
      lastAppliedSeq: lastAppliedSeq < 0 ? 0 : lastAppliedSeq,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastPlaybackState &&
        other.videoId == videoId &&
        other.position == position &&
        other.isPlaying == isPlaying &&
        other.duration == duration &&
        other.isBuffering == isBuffering &&
        other.isCompleted == isCompleted &&
        other.volume == volume &&
        other.lastAppliedSeq == lastAppliedSeq;
  }

  @override
  int get hashCode => Object.hash(
        videoId,
        position,
        isPlaying,
        duration,
        isBuffering,
        isCompleted,
        volume,
        lastAppliedSeq,
      );
}

/// A Cast Session as the API reports it: the whole thing, never a delta.
///
/// The Receiver's name travels inside the session rather than being looked up in the device list,
/// so Remote Control Mode can still say where playback is even when the device list moves on.
class CastSession {
  const CastSession({
    required this.sessionId,
    required this.status,
    required this.controllerDeviceId,
    required this.controllerName,
    required this.receiverDeviceId,
    required this.receiverName,
    required this.videoId,
    required this.isReceiverPrepared,
    this.confirmedState,
    this.endReason,
  });

  final String sessionId;

  final CastSessionStatus status;

  /// The stable identity of the phone that started the session. Only it may act on the session.
  final String controllerDeviceId;

  final String controllerName;

  final String receiverDeviceId;

  final String receiverName;

  final int videoId;

  /// Whether the Receiver has loaded the video and is waiting for the commit. Meaningful only while
  /// [status] is [CastSessionStatus.preparing].
  final bool isReceiverPrepared;

  /// The Receiver's last confirmed playback state, or `null` until it confirms one.
  final CastPlaybackState? confirmedState;

  /// Why the session ended, or `null` for a session that has not ended.
  final CastEndReason? endReason;

  /// Whether this session still owns playback, so the phone stays in Remote Control Mode.
  bool get isLive => status.isLive;

  /// Returns `null` only when the payload is not a session at all. Unknown values inside a
  /// well-formed session are read as unknown rather than failing the whole message.
  static CastSession? tryParse(Object? rawValue) {
    if (rawValue is! Map<Object?, Object?>) {
      return null;
    }
    final String sessionId = _readString(rawValue['sessionId']);
    if (sessionId.isEmpty) {
      return null;
    }

    final Object? rawEndReason = rawValue['endReason'];

    return CastSession(
      sessionId: sessionId,
      status: CastSessionStatus.parse(rawValue['status']),
      controllerDeviceId: _readString(rawValue['controllerDeviceId']),
      controllerName: _readString(rawValue['controllerName']),
      receiverDeviceId: _readString(rawValue['receiverDeviceId']),
      receiverName: _readString(rawValue['receiverName']),
      videoId: _readInt(rawValue['videoId']) ?? 0,
      isReceiverPrepared: rawValue['isReceiverPrepared'] == true,
      confirmedState: CastPlaybackState.tryParse(rawValue['confirmedState']),
      endReason: rawEndReason == null ? null : CastEndReason.parse(rawEndReason),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastSession &&
        other.sessionId == sessionId &&
        other.status == status &&
        other.controllerDeviceId == controllerDeviceId &&
        other.controllerName == controllerName &&
        other.receiverDeviceId == receiverDeviceId &&
        other.receiverName == receiverName &&
        other.videoId == videoId &&
        other.isReceiverPrepared == isReceiverPrepared &&
        other.confirmedState == confirmedState &&
        other.endReason == endReason;
  }

  @override
  int get hashCode => Object.hash(
        sessionId,
        status,
        controllerDeviceId,
        controllerName,
        receiverDeviceId,
        receiverName,
        videoId,
        isReceiverPrepared,
        confirmedState,
        endReason,
      );
}

/// Phase one of Handoff, as the API sends it to the Receiver.
///
/// It deliberately carries no position. The Receiver loads the video and waits; where the viewer
/// actually is travels with [CastCommitCommand], which is what keeps a slow Receiver from sending
/// playback backwards.
class CastPrepareCommand {
  const CastPrepareCommand({
    required this.sessionId,
    required this.videoId,
    required this.controllerDeviceId,
    required this.controllerName,
  });

  final String sessionId;

  /// The video the Receiver is asked to load.
  final int videoId;

  /// Who is casting, so the Receiver can say where playback came from.
  final String controllerDeviceId;

  final String controllerName;

  /// Returns `null` when the payload is not a command this client can act on.
  ///
  /// A command without a session or a video is not guessed at. Ignoring it leaves the API's own
  /// one-minute window to end the Handoff, which puts the phone back where it was rather than
  /// leaving the Receiver loading something nobody asked for.
  static CastPrepareCommand? tryParse(Object? rawValue) {
    if (rawValue is! Map<Object?, Object?>) {
      return null;
    }
    final String sessionId = _readString(rawValue['sessionId']);
    final int videoId = _readInt(rawValue['videoId']) ?? 0;
    if (sessionId.isEmpty || videoId <= 0) {
      return null;
    }

    return CastPrepareCommand(
      sessionId: sessionId,
      videoId: videoId,
      controllerDeviceId: _readString(rawValue['controllerDeviceId']),
      controllerName: _readString(rawValue['controllerName']),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastPrepareCommand &&
        other.sessionId == sessionId &&
        other.videoId == videoId &&
        other.controllerDeviceId == controllerDeviceId &&
        other.controllerName == controllerName;
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, videoId, controllerDeviceId, controllerName);
}

/// Phase two of Handoff, as the API sends it to the Receiver: the Controller's latest absolute
/// position and the playing or paused state the viewer was in.
///
/// Acting on one replaces whatever the Receiver was playing, with no confirmation prompt, so
/// casting stays a one-action workflow.
class CastCommitCommand {
  const CastCommitCommand({
    required this.sessionId,
    required this.videoId,
    required this.position,
    required this.isPlaying,
  });

  final String sessionId;

  final int videoId;

  /// Absolute position from the start of the video.
  final Duration position;

  /// What the viewer was doing on the phone, which the Handoff preserves.
  final bool isPlaying;

  /// Returns `null` when the payload is not a command this client can act on.
  static CastCommitCommand? tryParse(Object? rawValue) {
    if (rawValue is! Map<Object?, Object?>) {
      return null;
    }
    final String sessionId = _readString(rawValue['sessionId']);
    final int videoId = _readInt(rawValue['videoId']) ?? 0;
    if (sessionId.isEmpty || videoId <= 0) {
      return null;
    }

    return CastCommitCommand(
      sessionId: sessionId,
      videoId: videoId,
      position: _readPosition(rawValue['positionMs']),
      isPlaying: rawValue['isPlaying'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastCommitCommand &&
        other.sessionId == sessionId &&
        other.videoId == videoId &&
        other.position == position &&
        other.isPlaying == isPlaying;
  }

  @override
  int get hashCode => Object.hash(sessionId, videoId, position, isPlaying);
}

String _readString(Object? value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

/// Times travel as integer milliseconds. A missing or negative one reads as the start of the video
/// rather than as a position that cannot exist.
Duration _readPosition(Object? value) {
  final int milliseconds = _readInt(value) ?? 0;
  return milliseconds <= 0 ? Duration.zero : Duration(milliseconds: milliseconds);
}

/// The player's volume, normalised from 0 to 1. Returns `null` for anything outside that range,
/// which is a value this protocol has no meaning for rather than a loud one.
double? _readVolume(Object? value) {
  final double? volume = value is num ? value.toDouble() : null;
  if (volume == null || volume.isNaN || volume < 0 || volume > 1) {
    return null;
  }
  return volume;
}
