import 'cast_playback_endpoint.dart';

/// This installation's video player as a Receiver drives it.
///
/// A Handoff asks the Receiver for three things, in this order: the requested video loaded and
/// ready while the phone keeps playing, what the Receiver itself is playing at the moment the
/// commit arrives, and that requested video started at the committed position in the committed
/// playing or paused state.
///
/// Once it is playing, the phone can also command it: play or pause, go to a position, set the
/// player's volume. Those are absolute and they are the same three things the person standing at
/// the Receiver can do with its own remote, which is why they are the player's own operations
/// rather than anything the Cast Session invented.
///
/// It is an interface for the same reason [CastPlaybackEndpoint] is: the Receiver's half of a
/// Handoff has to be drivable in a test without a video decoder, which automated Flutter tests
/// deliberately do not have.
abstract interface class CastReceiverPlayback {
  /// What this device is playing right now, or `null` when it is playing nothing.
  ///
  /// Read at commit time, because the video that is about to be replaced is the one whose progress
  /// has to be kept before it goes.
  CastLocalPlayback? readPlayback();

  /// Loads [videoId] and gets it ready to play, without disturbing whatever is playing now.
  ///
  /// Phase one of Handoff. Nothing the viewer can see changes here: the phone is still the device
  /// playing, and it stays that way until the commit arrives.
  Future<void> prepare(int videoId);

  /// Starts the prepared video at [position] in the [isPlaying] state, replacing any local playback
  /// that was running, and answers with the state it actually reached.
  ///
  /// There is no confirmation prompt by design: a successful commit simply takes the screen, so
  /// casting stays a one-action workflow. What comes back is Playback Authority as this device
  /// holds it, and it is what the Controller is told.
  Future<CastLocalPlayback> start({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  });

  /// Reaches the playing or paused state the Controller asked for.
  Future<void> setPlaying(bool isPlaying);

  /// Goes to an absolute position from the start of the cast video.
  Future<void> seekTo(Duration position);

  /// Sets the LocalTube player's own volume, from 0 (silent) to 1 (loudest).
  ///
  /// It is this installation's volume rather than this video's, and it is never the Android system
  /// volume: a Cast Session changes what LocalTube plays and nothing else on the Receiver. The
  /// value survives the video being replaced, and Handoff never writes it - a phone's volume means
  /// nothing in a room with different acoustics.
  Future<void> setVolume(double volume);
}
