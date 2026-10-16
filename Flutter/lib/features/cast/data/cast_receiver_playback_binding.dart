import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cast_playback_endpoint.dart';
import '../domain/cast_receiver_playback.dart';

/// The running application's [CastReceiverPlayback]: whichever surface can play a cast video on
/// this installation right now.
///
/// The same indirection as `CastPlaybackBinding` on the Controller side, and for the same reason. A
/// Cast Session outlives any one screen, while a video player belongs to the screen showing it, so
/// a surface [bind]s itself while it can play and [unbind]s when it can no longer.
///
/// With nothing bound this Receiver cannot take a Handoff, and says so rather than quietly
/// accepting one it cannot honour: the Receiver leaves the Handoff to the API's one-minute window
/// and the viewer simply keeps watching on the phone.
class CastReceiverPlaybackBinding implements CastReceiverPlayback {
  CastReceiverPlayer? _player;

  /// Makes [player] the surface a Cast Session plays on, replacing any previous one.
  void bind(CastReceiverPlayer player) {
    _player = player;
  }

  /// Stops using [player], unless something else has already bound in its place.
  void unbind(CastReceiverPlayer player) {
    if (identical(_player, player)) {
      _player = null;
    }
  }

  @override
  CastLocalPlayback? readPlayback() => _player?.readPlayback();

  @override
  Future<void> prepare(int videoId) => _requirePlayer().prepareVideo(videoId);

  @override
  Future<CastLocalPlayback> start({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  }) {
    return _requirePlayer().startVideo(
      videoId: videoId,
      position: position,
      isPlaying: isPlaying,
    );
  }

  @override
  Future<void> setPlaying(bool isPlaying) =>
      _requirePlayer().setPlaying(isPlaying);

  @override
  Future<void> seekTo(Duration position) => _requirePlayer().seekTo(position);

  @override
  Future<void> setVolume(double volume) => _requirePlayer().setVolume(volume);

  CastReceiverPlayer _requirePlayer() {
    final CastReceiverPlayer? player = _player;
    if (player == null) {
      throw StateError(
        'This installation has no surface that can play a cast video',
      );
    }
    return player;
  }
}

/// A surface that can play the video a Cast Session hands to this Receiver.
abstract interface class CastReceiverPlayer {
  /// What this surface is playing right now, or `null` when it is playing nothing.
  CastLocalPlayback? readPlayback();

  /// Loads [videoId] ready to play without disturbing whatever is playing now.
  Future<void> prepareVideo(int videoId);

  /// Starts [videoId] at [position] in the [isPlaying] state, replacing whatever was playing, and
  /// answers with the state it actually reached.
  Future<CastLocalPlayback> startVideo({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  });

  /// Reaches the playing or paused state the Controller asked for.
  Future<void> setPlaying(bool isPlaying);

  /// Goes to an absolute position from the start of the cast video.
  Future<void> seekTo(Duration position);

  /// Sets the LocalTube player's own volume, which this installation keeps across videos.
  Future<void> setVolume(double volume);
}

/// One binding for the whole application.
///
/// It has a real value rather than being supplied by the composition root, exactly like the
/// Controller side's binding: it holds no configuration, no credentials and no connection.
final Provider<CastReceiverPlaybackBinding> castReceiverPlaybackBindingProvider =
    Provider<CastReceiverPlaybackBinding>(
  (Ref ref) => CastReceiverPlaybackBinding(),
);
