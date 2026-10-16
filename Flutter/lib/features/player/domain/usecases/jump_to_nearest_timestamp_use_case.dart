import '../player_models.dart';

class JumpToNearestTimestampUseCase {
  VideoTimestamp? call({
    required Duration currentPosition,
    required List<VideoTimestamp> timestamps,
  }) {
    if (timestamps.isEmpty) {
      return null;
    }

    final Duration normalizedPosition =
        currentPosition < Duration.zero ? Duration.zero : currentPosition;
    final List<VideoTimestamp> sorted = <VideoTimestamp>[...timestamps]
      ..sort((VideoTimestamp a, VideoTimestamp b) {
        return a.position.compareTo(b.position);
      });

    for (final VideoTimestamp timestamp in sorted) {
      if (timestamp.position > normalizedPosition) {
        return timestamp;
      }
    }

    return null;
  }
}
