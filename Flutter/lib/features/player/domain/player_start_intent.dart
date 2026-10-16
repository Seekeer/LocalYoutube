import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How a player is to start, when something outside it has already decided.
///
/// Ordinary local playback decides for itself: it resumes where the viewer left off, and it starts
/// playing. A Cast Session does not get to make either choice. The Handoff carries the viewer's
/// absolute position and whether they were playing or paused, and a Receiver that ignored the
/// second of those - that started playing a Handoff the viewer had paused - would have overruled
/// them.
class PlayerStartIntent {
  const PlayerStartIntent({
    required this.position,
    required this.isPlaying,
  });

  /// Where the video is to begin, absolute from its start.
  final Duration position;

  /// Whether it is to begin playing. `false` means the player must not start on its own.
  final bool isPlaying;
}

/// Intents left for players that have not been built yet, one per video.
///
/// A player starts playing as soon as it has loaded, which is what a viewer opening a video wants
/// and is the wrong thing exactly once: when the video is being opened on behalf of a paused
/// Handoff. Leaving the intent here before the player route is opened is what closes that window -
/// the player takes it while it is being built, so there is no moment in which it has already
/// started on its own and has to be caught and stopped.
///
/// An intent is taken once. A player built for a video the intent was not left for finds nothing
/// and behaves exactly as it always has.
class PlayerStartIntents {
  final Map<int, PlayerStartIntent> _byVideoId = <int, PlayerStartIntent>{};

  /// Leaves [intent] for the next player of [videoId], replacing any intent left before it.
  void put(int videoId, PlayerStartIntent intent) {
    _byVideoId[videoId] = intent;
  }

  /// The intent for [videoId], removing it. Returns `null` when none was left.
  PlayerStartIntent? take(int videoId) => _byVideoId.remove(videoId);

  /// Throws away an intent nobody is going to take, so it cannot reach a later player.
  void clear(int videoId) {
    _byVideoId.remove(videoId);
  }
}

/// One set of intents for the whole application. It holds no configuration, no credentials and no
/// connection, so there is nothing about it a test or an environment would need to replace.
final Provider<PlayerStartIntents> playerStartIntentsProvider =
    Provider<PlayerStartIntents>((Ref ref) => PlayerStartIntents());
