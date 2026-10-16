import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';

typedef LockScreenSeekHandler = Future<void> Function(Duration position);
typedef LockScreenSeekRelativeHandler = Future<void> Function(Duration offset);
typedef LockScreenSimpleHandler = Future<void> Function();

class LockScreenPlaybackCallbacks {
  const LockScreenPlaybackCallbacks({
    required this.onPlay,
    required this.onPause,
    required this.onSeek,
    required this.onSeekRelative,
    required this.onAddBookmark,
    required this.onStop,
  });

  final LockScreenSimpleHandler onPlay;
  final LockScreenSimpleHandler onPause;
  final LockScreenSeekHandler onSeek;
  final LockScreenSeekRelativeHandler onSeekRelative;
  final LockScreenSimpleHandler onAddBookmark;
  final LockScreenSimpleHandler onStop;
}

class LockScreenPlaybackService {
  LockScreenPlaybackService._();

  static final LockScreenPlaybackService instance = LockScreenPlaybackService._();

  _LocalTubeAudioHandler? _handler;
  int? _activeVideoId;

  bool get _supportsPlatform => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (!_supportsPlatform || _handler != null) {
      return;
    }

    final AudioHandler handler = await AudioService.init(
      builder: _LocalTubeAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.localtube.player.channel.playback',
        androidNotificationChannelName: 'LocalTube Playback',
        androidNotificationChannelDescription:
            'Playback controls for LocalTube on the lock screen',
        androidNotificationIcon: 'mipmap/ic_launcher',
        // Keep the foreground service alive across background pause/resume
        // transitions so Android does not drop media controls on lock screen.
        androidStopForegroundOnPause: false,
      ),
    );
    if (handler is! _LocalTubeAudioHandler) {
      throw StateError('Unexpected audio handler type: ${handler.runtimeType}');
    }
    _handler = handler;
  }

  Future<void> activate({
    required int videoId,
    required String title,
    required Duration duration,
    required LockScreenPlaybackCallbacks callbacks,
  }) async {
    if (!_supportsPlatform) {
      return;
    }
    await initialize();
    final _LocalTubeAudioHandler? handler = _handler;
    if (handler == null) {
      return;
    }

    _activeVideoId = videoId;
    handler.bind(callbacks);
    handler.publishMediaItem(
      videoId: videoId,
      title: title,
      duration: duration,
    );
  }

  Future<void> updatePlaybackState({
    required int videoId,
    required bool isPlaying,
    required bool isLoading,
    required bool isBuffering,
    required Duration position,
    required Duration duration,
  }) async {
    if (!_supportsPlatform || _activeVideoId != videoId) {
      return;
    }
    final _LocalTubeAudioHandler? handler = _handler;
    if (handler == null) {
      return;
    }
    handler.updatePlaybackState(
      isPlaying: isPlaying,
      isLoading: isLoading,
      isBuffering: isBuffering,
      position: position,
      duration: duration,
    );
  }

  Future<void> updateMediaMetadata({
    required int videoId,
    required String title,
    required Duration duration,
  }) async {
    if (!_supportsPlatform || _activeVideoId != videoId) {
      return;
    }
    final _LocalTubeAudioHandler? handler = _handler;
    if (handler == null) {
      return;
    }
    handler.publishMediaItem(
      videoId: videoId,
      title: title,
      duration: duration,
    );
  }

  Future<void> clear({
    required int videoId,
  }) async {
    if (!_supportsPlatform || _activeVideoId != videoId) {
      return;
    }
    _activeVideoId = null;
    final _LocalTubeAudioHandler? handler = _handler;
    if (handler == null) {
      return;
    }
    handler.clear();
  }
}

class _LocalTubeAudioHandler extends BaseAudioHandler with SeekHandler {
  static const Duration _step = Duration(seconds: 10);
  static const String _bookmarkAction = 'localtube.bookmark';

  LockScreenPlaybackCallbacks? _callbacks;

  void bind(LockScreenPlaybackCallbacks callbacks) {
    _callbacks = callbacks;
  }

  void publishMediaItem({
    required int videoId,
    required String title,
    required Duration duration,
  }) {
    final MediaItem item = MediaItem(
      id: 'video:$videoId',
      title: title.trim().isEmpty ? 'Video #$videoId' : title.trim(),
      album: 'LocalTube',
      duration: duration <= Duration.zero ? null : duration,
    );
    queue.add(<MediaItem>[item]);
    mediaItem.add(
      item,
    );
  }

  void updatePlaybackState({
    required bool isPlaying,
    required bool isLoading,
    required bool isBuffering,
    required Duration position,
    required Duration duration,
  }) {
    final AudioProcessingState processingState;
    if (isLoading || isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else if (duration > Duration.zero && position >= duration) {
      processingState = AudioProcessingState.completed;
    } else {
      processingState = AudioProcessingState.ready;
    }

    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.rewind,
          isPlaying ? MediaControl.pause : MediaControl.play,
          MediaControl.custom(
            androidIcon: 'drawable/ic_lock_screen_bookmark',
            label: 'Bookmark',
            name: _bookmarkAction,
          ),
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekBackward,
          MediaAction.seekForward,
        },
        androidCompactActionIndices: const <int>[0, 1, 3],
        processingState: processingState,
        playing: isPlaying,
        updatePosition: position < Duration.zero ? Duration.zero : position,
        bufferedPosition: position < Duration.zero ? Duration.zero : position,
        speed: 1.0,
        queueIndex: 0,
      ),
    );
  }

  void clear() {
    _callbacks = null;
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    queue.add(<MediaItem>[]);
    mediaItem.add(null);
  }

  @override
  Future<void> play() async {
    await _callbacks?.onPlay();
  }

  @override
  Future<void> pause() async {
    await _callbacks?.onPause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _callbacks?.onSeek(position);
  }

  @override
  Future<void> rewind() async {
    await _callbacks?.onSeekRelative(-_step);
  }

  @override
  Future<void> fastForward() async {
    await _callbacks?.onSeekRelative(_step);
  }

  @override
  Future<void> stop() async {
    await _callbacks?.onStop();
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == _bookmarkAction) {
      await _callbacks?.onAddBookmark();
      return null;
    }
    return super.customAction(name, extras);
  }
}
