import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/logging/log_service.dart';
import '../../core/playback/playback_mode.dart';
import '../../features/cast/data/cast_playback_binding.dart';
import '../../features/cast/data/cast_receiver_playback_binding.dart';
import '../../features/cast/domain/cast_playback_endpoint.dart';
import '../../features/player/domain/player_start_intent.dart';
import '../../features/player/domain/player_volume.dart';
import '../../features/player/domain/usecases/play_video_use_case.dart';
import '../bootstrap/bootstrap_providers.dart';
import '../router/app_routes.dart';

/// Makes this installation a real Receiver that can be cast to.
///
/// The Receiver's half of a Cast Session is driven through a seam so that it can be tested without
/// a video decoder; this is the thing on the other side of that seam in the running application.
/// Without it the seam has nothing behind it and a Handoff to this device simply runs out of time.
///
/// It sits in the application shell rather than on a screen, and for the same reason the Receiver
/// Controller does: a Handoff arrives on the connection, and a Receiver that could only be reached
/// while some particular page happened to be open would be unreachable exactly when the viewer wants
/// to cast to it. From here it can open the player for a video the Receiver is not showing.
class CastReceiverPlayerHost extends ConsumerStatefulWidget {
  const CastReceiverPlayerHost({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<CastReceiverPlayerHost> createState() =>
      _CastReceiverPlayerHostState();
}

class _CastReceiverPlayerHostState
    extends ConsumerState<CastReceiverPlayerHost> {
  CastReceiverPlaybackBinding? _binding;
  _AppCastReceiverPlayer? _player;

  @override
  void initState() {
    super.initState();

    final _AppCastReceiverPlayer player = _AppCastReceiverPlayer(
      localPlayback: ref.read(castPlaybackBindingProvider),
      startIntents: ref.read(playerStartIntentsProvider),
      playerVolume: ref.read(playerVolumeProvider),
      playVideoUseCase: ref.read(playVideoUseCaseProvider),
      isAutonomous: () => mounted && ref.read(effectiveAutonomousModeProvider),
      openPlayer: _openPlayer,
      logService: ref.read(logServiceProvider),
    );
    final CastReceiverPlaybackBinding binding =
        ref.read(castReceiverPlaybackBindingProvider);
    binding.bind(player);
    _player = player;
    _binding = binding;
  }

  @override
  void dispose() {
    final _AppCastReceiverPlayer? player = _player;
    if (player != null) {
      _binding?.unbind(player);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// Opens the player for a cast video, wherever the Receiver happened to be.
  ///
  /// The position is deliberately not in the route: it travels in the start intent, together with
  /// whether the video is to begin playing, because a Handoff that the viewer had paused must not be
  /// started by a player that only knew where to begin.
  void _openPlayer(int videoId) {
    widget.router.go('${AppRoutes.player}/$videoId');
  }
}

/// The real player behind [CastReceiverPlayer].
///
/// Everything it does, it does through the player screen: it opens that screen for the cast video
/// and then drives the very player the screen is showing, which is the same player the person
/// standing at the Receiver drives with its own remote. That is what makes the two agree.
///
/// It never holds a player controller. The screen that owns one binds it, and this reaches it
/// through that binding, so a player thrown away with its screen cannot be driven afterwards.
class _AppCastReceiverPlayer implements CastReceiverPlayer {
  _AppCastReceiverPlayer({
    required CastPlaybackBinding localPlayback,
    required PlayerStartIntents startIntents,
    required PlayerVolume playerVolume,
    required PlayVideoUseCase playVideoUseCase,
    required bool Function() isAutonomous,
    required void Function(int videoId) openPlayer,
    required LogService logService,
  })  : _localPlayback = localPlayback,
        _startIntents = startIntents,
        _playerVolume = playerVolume,
        _playVideoUseCase = playVideoUseCase,
        _isAutonomous = isAutonomous,
        _openPlayer = openPlayer,
        _logService = logService;

  /// How often the player screen is asked whether it has caught up. It is asked rather than
  /// listened to because what has to be true - the screen for this video is open and its player has
  /// a video loaded - is spread across a route change and a player's own loading, and neither of
  /// them is a single event to wait for.
  static const Duration _pollPeriod = Duration(milliseconds: 100);

  /// How long the Receiver is given to open a cast video before the Handoff is given up on. Well
  /// inside the API's own minute, so a Receiver that cannot open the video fails while the phone
  /// is still watching locally rather than after it has stopped waiting.
  static const Duration _openTimeout = Duration(seconds: 20);

  /// How long the player is then given to reach the playing or paused state that was asked for.
  /// After that, what it actually reached is what the phone is told.
  static const Duration _settleWindow = Duration(seconds: 3);

  final CastPlaybackBinding _localPlayback;
  final PlayerStartIntents _startIntents;
  final PlayerVolume _playerVolume;
  final PlayVideoUseCase _playVideoUseCase;
  final bool Function() _isAutonomous;
  final void Function(int videoId) _openPlayer;
  final LogService _logService;

  @override
  CastLocalPlayback? readPlayback() => _localPlayback.readPlayback();

  /// Phase one: make sure this Receiver can actually play the video, without touching the screen.
  ///
  /// Resolving the source is the whole of what can be checked without taking the screen, and it is
  /// the part that fails: the video has to exist, a downloaded copy or a stream this account is
  /// allowed has to be reachable, and a Receiver with neither must not claim to be prepared. The
  /// video itself is opened by the commit, because opening it here would replace what the viewer at
  /// this Receiver is watching before the phone has decided to hand over at all.
  @override
  Future<void> prepareVideo(int videoId) async {
    await _playVideoUseCase.call(videoId: videoId, localOnly: _isAutonomous());
  }

  /// Phase two: take the screen, at the position and in the state the viewer was in.
  ///
  /// The intent is left before the player route is opened so a paused Handoff never plays even for
  /// a moment. The position and the state are then set explicitly as well, because the Receiver
  /// may already have this very video open - the player is reused then, and an intent nobody takes
  /// would leave the viewer wherever that player happened to be.
  @override
  Future<CastLocalPlayback> startVideo({
    required int videoId,
    required Duration position,
    required bool isPlaying,
  }) async {
    _startIntents.put(
      videoId,
      PlayerStartIntent(position: position, isPlaying: isPlaying),
    );

    try {
      _openPlayer(videoId);
      final CastLocalPlayer player = await _awaitPlayerFor(videoId);
      await player.seekTo(position);
      await player.setPlaying(isPlaying);
      return await _awaitReachedState(videoId: videoId, isPlaying: isPlaying);
    } finally {
      // Whether this worked or not, an intent nobody took must not reach a player the viewer opens
      // themselves later on.
      _startIntents.clear(videoId);
    }
  }

  @override
  Future<void> setPlaying(bool isPlaying) =>
      _requirePlayer().setPlaying(isPlaying);

  @override
  Future<void> seekTo(Duration position) => _requirePlayer().seekTo(position);

  @override
  Future<void> setVolume(double volume) async {
    final CastLocalPlayer? player = _localPlayback.currentPlayer;
    if (player == null) {
      // The volume is this installation's, not this video's, so it is kept even with nothing
      // playing: whatever opens next starts at it.
      _playerVolume.setValue(volume);
      return;
    }
    await player.setPlayerVolume(volume);
  }

  /// Waits until the player screen for [videoId] is open and its player has the video loaded.
  Future<CastLocalPlayer> _awaitPlayerFor(int videoId) async {
    final DateTime deadline = DateTime.now().toUtc().add(_openTimeout);
    while (true) {
      final CastLocalPlayer? player = _localPlayback.currentPlayer;
      if (player != null &&
          player.isReady &&
          player.readPlayback()?.videoId == videoId) {
        return player;
      }
      if (DateTime.now().toUtc().isAfter(deadline)) {
        _logService.warn(
          'Cast Receiver gave up opening video $videoId after '
          '${_openTimeout.inSeconds}s',
        );
        throw StateError('This Receiver could not open the cast video $videoId');
      }
      await Future<void>.delayed(_pollPeriod);
    }
  }

  /// What the Receiver actually reached, which is what the phone is told - never what it asked
  /// for. It is given a moment to get there and then reported as it stands.
  Future<CastLocalPlayback> _awaitReachedState({
    required int videoId,
    required bool isPlaying,
  }) async {
    final DateTime settleBy = DateTime.now().toUtc().add(_settleWindow);
    while (true) {
      final CastLocalPlayback? reached = _localPlayback.readPlayback();
      if (reached == null || reached.videoId != videoId) {
        throw StateError(
          'This Receiver left the cast video $videoId before it started',
        );
      }
      if (reached.isPlaying == isPlaying ||
          DateTime.now().toUtc().isAfter(settleBy)) {
        return reached;
      }
      await Future<void>.delayed(_pollPeriod);
    }
  }

  CastLocalPlayer _requirePlayer() {
    final CastLocalPlayer? player = _localPlayback.currentPlayer;
    if (player == null) {
      throw StateError('This Receiver is showing no player to command');
    }
    return player;
  }
}
