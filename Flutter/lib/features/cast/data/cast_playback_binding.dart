import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/domain/player_start_intent.dart';
import '../domain/cast_playback_endpoint.dart';

/// The running application's [CastPlaybackEndpoint]: whichever local player is on screen.
///
/// A Cast Session is started from the player screen and outlives it, while the video player itself
/// belongs to that screen and is thrown away when it leaves. This indirection is what lets the Cast
/// Session ask about local playback without holding on to a player, and without knowing which
/// screen is showing one.
///
/// A screen [bind]s itself while it owns a player and [unbind]s when it gives it up. With nothing
/// bound the endpoint reports no local playback, which is exactly the truth in Remote Control Mode.
///
/// Both halves of a Cast Session reach the screen through here. The Controller's half needs only
/// what [CastPlaybackEndpoint] says - where the viewer is, a way to let go, and a way to pick
/// playback back up when a Return Handoff brings it home. The Receiver's half needs the player
/// itself, because a Receiver being commanded from a phone is driving the very video it is
/// showing; that is what [currentPlayer] is for.
class CastPlaybackBinding implements CastPlaybackEndpoint {
  CastPlaybackBinding(this._startIntents);

  /// Where a Return Handoff leaves the position playback is to continue from. A player takes its
  /// intent while it is being built, which is the only moment there is: the player this page gave
  /// up is gone, and the one that continues playback does not exist yet.
  final PlayerStartIntents _startIntents;

  CastLocalPlayer? _player;

  /// Makes [player] the local player the Cast Session talks to, replacing any previous one.
  void bind(CastLocalPlayer player) {
    _player = player;
  }

  /// Stops talking to [player], unless something else has already bound in its place.
  void unbind(CastLocalPlayer player) {
    if (identical(_player, player)) {
      _player = null;
    }
  }

  /// The player this installation is showing, or `null` when it is showing none.
  CastLocalPlayer? get currentPlayer => _player;

  @override
  CastLocalPlayback? readPlayback() => _player?.readPlayback();

  @override
  Future<void> release() async {
    final CastLocalPlayer? player = _player;
    _player = null;
    await player?.releasePlayback();
  }

  /// Continues [videoId] here, wherever the player that is to show it comes from.
  ///
  /// The intent is left for the player rather than performed on one, because the usual case is that
  /// there is no player at all: Remote Control Mode released it, and the surface that rebuilds
  /// after the Cast Session ends is what builds the next one. A player that is already bound - a
  /// screen that got there first - is also driven, for the same reason a Handoff sets the position
  /// explicitly as well as leaving it: an intent nobody takes would leave the viewer wherever that
  /// player happened to be.
  @override
  Future<void> resume({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  }) async {
    final Duration from = position.isNegative ? Duration.zero : position;
    _startIntents.put(
      videoId,
      PlayerStartIntent(position: from, isPlaying: isPlaying),
    );

    final CastLocalPlayer? player = _player;
    if (player == null) {
      return;
    }
    await player.seekTo(from);
    await player.setPlaying(isPlaying);
  }
}

/// A local video player that has made itself available to the Cast Session.
abstract interface class CastLocalPlayer {
  /// Where this player is right now, or `null` when it has nothing to report.
  CastLocalPlayback? readPlayback();

  /// Whether this player has a video open and can be acted on.
  ///
  /// A player that is still loading, or that failed to open its video, has nothing to play, pause
  /// or seek. A Receiver waits for this before it claims a Handoff has taken its screen, so it
  /// never tells a phone it is playing something it is not.
  bool get isReady;

  /// Stops local playback because the Receiver has taken over.
  Future<void> releasePlayback();

  /// Reaches the playing or paused state asked for.
  Future<void> setPlaying(bool isPlaying);

  /// Goes to an absolute position from the start of the video.
  Future<void> seekTo(Duration position);

  /// Sets the LocalTube player's own volume, which this installation keeps across videos.
  Future<void> setPlayerVolume(double volume);
}

/// One binding for the whole application.
///
/// It has a real value rather than being supplied by the composition root: it holds no
/// configuration, no credentials and no connection, and neither does the set of start intents it
/// leaves a returning Handoff in, so there is nothing about either a test or an environment would
/// need to replace.
final Provider<CastPlaybackBinding> castPlaybackBindingProvider =
    Provider<CastPlaybackBinding>(
  (Ref ref) => CastPlaybackBinding(ref.watch(playerStartIntentsProvider)),
);
