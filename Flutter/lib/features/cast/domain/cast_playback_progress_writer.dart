/// How a Receiver keeps the progress of a video it is about to stop playing.
///
/// Narrow on purpose, and deliberately not a cast-specific way of remembering positions: the
/// implementation is the app's ordinary playback-progress path, the same one a local viewer's
/// progress already travels on. A video the cast displaced therefore comes back exactly where a
/// locally watched one would, and nothing new has to be reconciled with it.
///
/// It is an interface so that the order between keeping the displaced video's progress and
/// replacing it can be asserted in a test, which is the whole point of doing it in that order.
abstract interface class CastPlaybackProgressWriter {
  /// Writes [position] as the progress of [videoId], completing once it has been written.
  ///
  /// The Receiver awaits this before it replaces playback. A write left to finish on its own would
  /// be racing the very thing it exists to happen before.
  Future<void> saveProgress({
    required int videoId,
    required Duration position,
  });
}
