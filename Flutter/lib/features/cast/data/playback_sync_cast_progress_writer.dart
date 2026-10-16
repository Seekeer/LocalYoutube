import '../../player/data/playback_sync_repository.dart';
import '../domain/cast_playback_progress_writer.dart';

/// The Receiver's progress writes on the app's existing playback-progress path.
///
/// [PlaybackSyncRepository.savePosition] is where an ordinary viewer's progress already goes: it
/// writes locally, pushes to the server, and falls back to the sync outbox when that push fails.
/// Handing a displaced video to it is what makes "the position is there when that video is
/// reopened" true without inventing a second kind of progress.
class PlaybackSyncCastProgressWriter implements CastPlaybackProgressWriter {
  const PlaybackSyncCastProgressWriter(this._playbackSyncRepository);

  final PlaybackSyncRepository _playbackSyncRepository;

  @override
  Future<void> saveProgress({
    required int videoId,
    required Duration position,
  }) {
    final double positionSeconds =
        position.isNegative ? 0.0 : position.inMilliseconds / 1000;
    return _playbackSyncRepository.savePosition(
      videoId: videoId,
      positionSeconds: positionSeconds,
    );
  }
}
