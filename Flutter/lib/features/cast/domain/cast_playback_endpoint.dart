/// This installation's own video player, as a Cast Session sees it.
///
/// A Handoff needs three things from local playback and nothing else: where the viewer is at the
/// moment the Receiver is ready, a way to give the player up once the Receiver has confirmed it
/// took over, and a way to take playback back when it comes home.
///
/// It is an interface because a Cast Controller test has to drive a Handoff without a video
/// decoder, which automated Flutter tests deliberately do not have.
abstract interface class CastPlaybackEndpoint {
  /// What this device is playing right now, or `null` when it is playing nothing.
  ///
  /// Read at commit time rather than when the viewer pressed cast, so a Receiver that took a
  /// while to load continues from where the viewer actually is instead of sending them backwards.
  CastLocalPlayback? readPlayback();

  /// Gives up the local video player.
  ///
  /// Called only after the Receiver has confirmed its playback state, so playback never disappears
  /// from the phone before the Receiver is ready to show it.
  Future<void> release();

  /// Continues [videoId] here at [position], playing or paused as asked: the other end of
  /// [release].
  ///
  /// This is what a Return Handoff does with the Receiver's last confirmed position. It is stated
  /// rather than performed: while the Receiver was playing this device owned no player at all, so
  /// what this has to reach is the player the restored surface is about to build, not one that is
  /// already there.
  Future<void> resume({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  });
}

/// Where local playback is, at one instant.
///
/// Handoff needs only the first three: which video, where in it, and whether it was playing. The
/// rest are what a Receiver reports about itself, because during a Cast Session this is the only
/// description of playback either device has and the phone renders it rather than a guess. They
/// have defaults so that the places which only care about a Handoff can go on saying only that.
class CastLocalPlayback {
  const CastLocalPlayback({
    required this.videoId,
    required this.position,
    required this.isPlaying,
    this.duration = Duration.zero,
    this.isBuffering = false,
    this.isCompleted = false,
    this.volume = 1.0,
  });

  final int videoId;

  /// Absolute position from the start of the video.
  final Duration position;

  /// What the viewer was doing, which the Handoff preserves.
  final bool isPlaying;

  /// How long the video is, or zero while the player does not know yet.
  final Duration duration;

  /// Whether the player is waiting for data rather than showing the video.
  final bool isBuffering;

  /// Whether the video has reached its end.
  final bool isCompleted;

  /// The LocalTube player's volume on this installation, from 0 (silent) to 1 (loudest). Never the
  /// Android system volume.
  final double volume;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CastLocalPlayback &&
        other.videoId == videoId &&
        other.position == position &&
        other.isPlaying == isPlaying &&
        other.duration == duration &&
        other.isBuffering == isBuffering &&
        other.isCompleted == isCompleted &&
        other.volume == volume;
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
      );
}
