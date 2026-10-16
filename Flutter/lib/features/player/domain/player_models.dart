enum PlayableSourceKind {
  localFile,
  remoteUrl,
}

class OfflinePlaybackUnavailableException implements Exception {
  const OfflinePlaybackUnavailableException({required this.videoId});

  final int videoId;

  String get message => 'This video is not available offline.';

  @override
  String toString() => message;
}

class PlayableVideo {
  const PlayableVideo({
    required this.videoId,
    required this.sourceUri,
    required this.sourceKind,
    required this.startPosition,
    required this.title,
  });

  final int videoId;
  final Uri sourceUri;
  final PlayableSourceKind sourceKind;
  final Duration startPosition;
  final String title;

  bool get isLocal => sourceKind == PlayableSourceKind.localFile;
}

class VideoTimestamp {
  const VideoTimestamp({
    required this.position,
    required this.label,
  });

  final Duration position;
  final String label;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is VideoTimestamp &&
        other.position == position &&
        other.label == label;
  }

  @override
  int get hashCode => Object.hash(position, label);
}
