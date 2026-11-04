import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../core/logging/log_service.dart';
import '../../../core/playback/playback_mode.dart';
import '../../bookmarks/data/bookmarks_repository.dart';
import '../../bookmarks/domain/bookmark_models.dart';
import '../../downloads/data/download_file_validator.dart';
import '../data/android_remote_playback_network_lock.dart';
import '../data/playback_screen_wake_lock.dart';
import '../data/playback_sync_repository.dart';
import '../data/stream_authorization_header_provider.dart';
import '../domain/player_models.dart';
import '../domain/player_start_intent.dart';
import '../domain/player_volume.dart';
import '../domain/usecases/play_video_use_case.dart';
import 'lock_screen_playback_service.dart';

class PlayerNavigationEntry {
  const PlayerNavigationEntry({
    required this.id,
    required this.fromPosition,
    required this.toPosition,
    required this.createdAtUtc,
  });

  final int id;
  final Duration fromPosition;
  final Duration toPosition;
  final DateTime createdAtUtc;
}

class PlayerUiState {
  const PlayerUiState({
    required this.videoId,
    required this.isLoading,
    required this.isPlaying,
    required this.isBuffering,
    required this.isRecovering,
    required this.position,
    required this.duration,
    required this.sourceKind,
    required this.bookmarks,
    required this.navigationEntries,
    this.errorMessage,
  });

  final int videoId;
  final bool isLoading;
  final bool isPlaying;
  final bool isBuffering;
  final bool isRecovering;
  final Duration position;
  final Duration duration;
  final PlayableSourceKind? sourceKind;
  final List<BookmarkItem> bookmarks;
  final List<PlayerNavigationEntry> navigationEntries;
  final String? errorMessage;

  factory PlayerUiState.initial(int videoId) => PlayerUiState(
        videoId: videoId,
        isLoading: true,
        isPlaying: false,
        isBuffering: true,
        isRecovering: false,
        position: Duration.zero,
        duration: Duration.zero,
        sourceKind: null,
        bookmarks: const <BookmarkItem>[],
        navigationEntries: const <PlayerNavigationEntry>[],
      );

  PlayerUiState copyWith({
    bool? isLoading,
    bool? isPlaying,
    bool? isBuffering,
    bool? isRecovering,
    Duration? position,
    Duration? duration,
    PlayableSourceKind? sourceKind,
    List<BookmarkItem>? bookmarks,
    List<PlayerNavigationEntry>? navigationEntries,
    String? errorMessage,
    bool clearError = false,
    bool clearSourceKind = false,
  }) {
    return PlayerUiState(
      videoId: videoId,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isRecovering: isRecovering ?? this.isRecovering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      sourceKind: clearSourceKind ? null : sourceKind ?? this.sourceKind,
      bookmarks: bookmarks ?? this.bookmarks,
      navigationEntries: navigationEntries ?? this.navigationEntries,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class _RemotePlaybackAuthorizationException implements Exception {
  const _RemotePlaybackAuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CorruptedSegmentRecoveryTracker {
  CorruptedSegmentRecoveryTracker({
    this.skipStep = const Duration(seconds: 3),
    this.repeatWindow = const Duration(seconds: 5),
  });

  final Duration skipStep;
  final Duration repeatWindow;

  Duration? _lastFailurePosition;
  Duration? _lastPlannedResumePosition;
  Duration _accumulatedSkip = Duration.zero;

  Duration get accumulatedSkip => _accumulatedSkip;

  Duration nextResumePosition(Duration rawResumePosition) {
    final Duration normalized =
        rawResumePosition < Duration.zero ? Duration.zero : rawResumePosition;
    final Duration? previousFailurePosition = _lastFailurePosition;
    if (previousFailurePosition != null &&
        (normalized - previousFailurePosition).abs() <= repeatWindow) {
      final Duration base = _lastPlannedResumePosition != null &&
              _lastPlannedResumePosition! > normalized
          ? _lastPlannedResumePosition!
          : normalized;
      _lastPlannedResumePosition = base + skipStep;
      _accumulatedSkip = _lastPlannedResumePosition! - normalized;
    } else {
      _accumulatedSkip = Duration.zero;
      _lastPlannedResumePosition = normalized;
    }
    _lastFailurePosition = normalized;
    return _lastPlannedResumePosition!;
  }

  void clearIfRecovered(Duration position) {
    final Duration? lastPlannedResumePosition = _lastPlannedResumePosition;
    if (lastPlannedResumePosition == null) {
      return;
    }
    if (position > lastPlannedResumePosition + repeatWindow) {
      reset();
    }
  }

  void reset() {
    _lastFailurePosition = null;
    _lastPlannedResumePosition = null;
    _accumulatedSkip = Duration.zero;
  }
}

class PlayerController extends StateNotifier<PlayerUiState> {
  PlayerController({
    required int videoId,
    required bool localOnly,
    required PlayVideoUseCase playVideoUseCase,
    required PlaybackSyncRepository playbackSyncRepository,
    required BookmarksRepository bookmarksRepository,
    required StreamAuthorizationHeaderProvider
        streamAuthorizationHeaderProvider,
    required LogService logService,
    PlaybackScreenWakeLock? playbackScreenWakeLock,
    PlayerStartIntent? startIntent,
    PlayerVolume? playerVolume,
  })  : _videoId = videoId,
        _localOnly = localOnly,
        _playVideoUseCase = playVideoUseCase,
        _playbackSyncRepository = playbackSyncRepository,
        _bookmarksRepository = bookmarksRepository,
        _streamAuthorizationHeaderProvider = streamAuthorizationHeaderProvider,
        _logService = logService,
        _playbackScreenWakeLock =
            playbackScreenWakeLock ?? AndroidPlaybackScreenWakeLock.instance,
        _startIntent = startIntent,
        _playerVolume = playerVolume ?? PlayerVolume(),
        super(PlayerUiState.initial(videoId)) {
    _initialize();
  }

  static const Duration _savePeriod = Duration(seconds: 5);
  static const Duration _bookmarkOutboxRetryPeriod = Duration(seconds: 3);
  static const Duration _quickResumeBookmarkThreshold = Duration(seconds: 2);
  static const Duration _navigationCaptureThreshold = Duration(seconds: 2);
  static const int _maxNavigationEntries = 20;
  static const Duration _remoteResumeSeekThreshold = Duration(
    milliseconds: 500,
  );
  static const String _manualBookmarkCaption = '(bookmark)';
  static const String _playPauseBookmarkCaption = '(play\\pause)';
  static const Duration _playbackHealthCheckPeriod = Duration(seconds: 2);
  static const Duration _bufferingRecoveryThreshold = Duration(seconds: 20);
  static const Duration _stalledPositionRecoveryThreshold = Duration(
    seconds: 15,
  );
  static const Duration _stalledPositionDeltaThreshold = Duration(
    milliseconds: 400,
  );
  static const Duration _runtimeErrorLogThrottle = Duration(seconds: 10);
  static const Duration _cooldownSkipLogThrottle = Duration(seconds: 15);
  static const int _maxRecoveryAttempts = 3;
  static const Duration _recoveryBackoffStep = Duration(seconds: 2);
  static const Duration _recoveryRetryCooldownAfterLimit = Duration(
    seconds: 30,
  );
  static final VideoPlayerOptions _videoPlayerOptions = VideoPlayerOptions(
    allowBackgroundPlayback: true,
  );

  final int _videoId;
  final bool _localOnly;
  final PlayVideoUseCase _playVideoUseCase;
  final PlaybackSyncRepository _playbackSyncRepository;
  final BookmarksRepository _bookmarksRepository;
  final StreamAuthorizationHeaderProvider _streamAuthorizationHeaderProvider;
  final LogService _logService;
  final PlaybackScreenWakeLock _playbackScreenWakeLock;

  /// How something outside this player already decided it should start, or `null` when nothing did
  /// and the player resumes and plays as it always has. Read once, while loading.
  final PlayerStartIntent? _startIntent;

  /// This installation's player volume, which outlives any one video.
  final PlayerVolume _playerVolume;

  PlayableVideo? _playable;
  VideoPlayerController? _videoPlayer;
  Timer? _periodicSaveTimer;
  Timer? _bookmarksOutboxTimer;
  Timer? _playbackHealthTimer;
  bool _initialized = false;
  bool _isDisposed = false;
  bool _isRecovering = false;
  int _recoveryAttempts = 0;
  double _lastSavedSeconds = 0;
  DateTime? _lastUserPauseAtUtc;
  Duration? _pendingExternalStartPosition;
  bool _completionPositionSaved = false;
  String? _preferredTitle;
  int _nextNavigationEntryId = 1;
  DateTime? _bufferingStartedAtUtc;
  DateTime? _stalledPositionStartedAtUtc;
  DateTime? _recoveryRetryBlockedUntilUtc;
  DateTime? _lastRuntimeErrorLoggedAtUtc;
  DateTime? _lastRecoveryCooldownSkipLogAtUtc;
  String? _lastRuntimeErrorSignature;
  Duration _lastObservedPlaybackPosition = Duration.zero;
  final CorruptedSegmentRecoveryTracker _corruptedSegmentRecoveryTracker =
      CorruptedSegmentRecoveryTracker();
  String? _stickyPlaybackErrorMessage;

  VideoPlayerController? get videoController => _videoPlayer;

  Future<void> togglePlayback() async {
    final VideoPlayerController? controller = _videoPlayer;
    if (controller?.value.isPlaying ?? false) {
      await pause();
      return;
    }
    await play();
  }

  Future<void> play() async {
    final VideoPlayerController? controller = _videoPlayer;
    if (_isDisposed ||
        state.isLoading ||
        state.errorMessage != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      return;
    }

    final DateTime? pauseStartedAt = _lastUserPauseAtUtc;
    final Duration positionBeforeResume = controller.value.position;
    await controller.play();
    _lastUserPauseAtUtc = null;
    _syncFromVideoPlayer();
    unawaited(_syncWithRemoteBeforeResume(controller, positionBeforeResume));
    if (pauseStartedAt != null) {
      final Duration pauseDuration = DateTime.now().toUtc().difference(
            pauseStartedAt,
          );
      if (pauseDuration <= _quickResumeBookmarkThreshold) {
        unawaited(
          _addBookmarkAtCurrentPosition(caption: _playPauseBookmarkCaption),
        );
      }
    }
  }

  Future<void> pause() async {
    final VideoPlayerController? controller = _videoPlayer;
    if (_isDisposed ||
        state.isLoading ||
        state.errorMessage != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (!controller.value.isPlaying) {
      return;
    }
    await controller.pause();
    _lastUserPauseAtUtc = DateTime.now().toUtc();
    await _saveCurrentPosition(force: true);
    _syncFromVideoPlayer();
  }

  Future<void> seek(
    Duration targetPosition, {
    bool trackNavigation = true,
  }) async {
    final VideoPlayerController? controller = _videoPlayer;
    if (_isDisposed ||
        state.isLoading ||
        state.errorMessage != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final Duration previousPosition = _clampToDuration(
      controller.value.position,
    );
    final Duration bounded = _clampToDuration(targetPosition);
    if (trackNavigation) {
      _recordNavigation(fromPosition: previousPosition, toPosition: bounded);
    }
    await controller.seekTo(bounded);
    await _saveCurrentPosition(force: true);
    _syncFromVideoPlayer();
  }

  Future<void> seekRelative(Duration offset) async {
    await seek(state.position + offset);
  }

  /// Sets the LocalTube player's own volume, from 0 (silent) to 1 (loudest).
  ///
  /// The value is this installation's rather than this video's: it is remembered whether or not
  /// there is a player to apply it to right now, and the next video starts at it. It is never the
  /// Android system volume, so it cannot turn down anything else on the device.
  Future<void> setPlayerVolume(double volume) async {
    final double kept = _playerVolume.setValue(volume);
    final VideoPlayerController? controller = _videoPlayer;
    if (_isDisposed || controller == null || !controller.value.isInitialized) {
      return;
    }
    await controller.setVolume(kept);
  }

  /// Puts this installation's volume on a player that has just been opened, so a video that
  /// replaced another sounds the same as the one it replaced.
  Future<void> _applyPlayerVolume(VideoPlayerController controller) async {
    try {
      await controller.setVolume(_playerVolume.value);
    } catch (error, stackTrace) {
      // A player that would not take a volume still plays. This is not worth failing a video for.
      _logService.error('applyPlayerVolume failed', error, stackTrace);
    }
  }

  Future<bool> addTextBookmark(double positionSeconds, String caption) async {
    final bool added = await _bookmarksRepository.addBookmark(
      videoId: _videoId,
      positionSeconds: positionSeconds,
      caption: caption,
    );
    await _refreshBookmarks(syncRemote: false);
    return added;
  }

  Future<void> addManualBookmark() async {
    await _addBookmarkAtCurrentPosition(caption: _manualBookmarkCaption);
  }

  Future<void> setPreferredTitle(String? title) async {
    final String? normalized = _normalizeTitle(title);
    if (_preferredTitle == normalized) {
      return;
    }
    _preferredTitle = normalized;
    await _publishLockScreenMediaMetadata();
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    try {
      await _bookmarksRepository.deleteBookmark(bookmarkId);
      await _bookmarksRepository.processOutbox();
      await _refreshBookmarks(syncRemote: false);
    } catch (error, stackTrace) {
      _logService.error('deleteBookmark failed', error, stackTrace);
    }
  }

  Future<void> seekToNavigationOrigin(int navigationEntryId) async {
    PlayerNavigationEntry? entry;
    for (final PlayerNavigationEntry item in state.navigationEntries) {
      if (item.id == navigationEntryId) {
        entry = item;
        break;
      }
    }
    if (entry == null) {
      return;
    }

    await seek(entry.fromPosition, trackNavigation: false);
    if (_isDisposed) {
      return;
    }

    final List<PlayerNavigationEntry> updated = state.navigationEntries
        .where((PlayerNavigationEntry item) => item.id != navigationEntryId)
        .toList(growable: false);
    state = state.copyWith(navigationEntries: updated);
  }

  Future<void> applyExternalStartPosition(Duration position) async {
    if (_isDisposed) {
      return;
    }
    _pendingExternalStartPosition =
        position < Duration.zero ? Duration.zero : position;
    if (!_initialized || _playable == null || state.isLoading) {
      return;
    }
    await _seekToExternalStartIfNeeded();
  }

  Future<void> onLifecycleStateChanged(AppLifecycleState lifecycleState) async {
    if (_isDisposed) {
      return;
    }
    _logService.debug(
      'Player lifecycle: ${lifecycleState.name}; ${_stateSnapshot()}',
    );
    if (lifecycleState == AppLifecycleState.resumed) {
      _syncFromVideoPlayer();
      unawaited(_recoverOnResumeIfNeeded());
      unawaited(_syncOutboxAndRefreshBookmarks());
      return;
    }
    if (lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      await _saveCurrentPosition(force: true);
    }
  }

  Future<void> _recoverOnResumeIfNeeded() async {
    if (_isDisposed || _isRecovering || _playable == null) {
      return;
    }
    final VideoPlayerController? controller = _videoPlayer;
    if (controller == null) {
      return;
    }

    final String? runtimeError = _runtimeErrorMessage(
      controller.value.errorDescription,
    );
    if (runtimeError == null) {
      _lastRuntimeErrorSignature = null;
      _lastRuntimeErrorLoggedAtUtc = null;
      return;
    }

    _logService.warn(
      'Playback resumed with runtime error, triggering recovery '
      '(${_logService.sanitize(runtimeError)}); '
      '${_controllerSnapshot(controller.value)}',
    );
    await _recoverPlayback(reason: 'resume-runtime-error');
  }

  Future<void> _initialize() async {
    if (_initialized || _isDisposed) {
      return;
    }
    _initialized = true;
    state = state.copyWith(
      isLoading: true,
      isBuffering: true,
      clearError: true,
      clearSourceKind: true,
    );

    try {
      _logService.info('Initializing player controller for video=$_videoId.');
      final PlayableVideo playable = await _playVideoUseCase.call(
        videoId: _videoId,
        localOnly: _localOnly,
      );
      if (_isDisposed) {
        return;
      }
      _playable = playable;
      await _setRemotePlaybackNetworkLock(
        playable.sourceKind == PlayableSourceKind.remoteUrl,
      );

      if (_isDisposed) {
        return;
      }

      // Where this video begins, and whether it begins playing. Without an intent both are what
      // they have always been: the resolved resume position, and playing.
      final PlayerStartIntent? startIntent = _startIntent;
      final Duration startPosition =
          startIntent?.position ?? playable.startPosition;
      final bool shouldAutoPlay = startIntent?.isPlaying ?? true;

      _lastSavedSeconds = startPosition.inMilliseconds / 1000;
      _stickyPlaybackErrorMessage = null;
      _recoveryRetryBlockedUntilUtc = null;
      _lastRecoveryCooldownSkipLogAtUtc = null;
      _corruptedSegmentRecoveryTracker.reset();
      _logService.info(
        'playback-auth: resolved source '
        'video=${playable.videoId}, '
        'source=${playable.sourceKind.name}, '
        'uri=${_logService.sanitize(playable.sourceUri.toString())}, '
        'startMs=${playable.startPosition.inMilliseconds}.',
      );

      final VideoPlayerController videoPlayer = await _createVideoPlayer(
        playable,
        refreshRemoteSession:
            playable.sourceKind == PlayableSourceKind.remoteUrl,
        refreshReason: 'initialize',
      );
      // Source resolution and authorization can finish after the page has closed.
      // A controller created in that window was never owned by dispose().
      if (_isDisposed) {
        await videoPlayer.dispose();
        return;
      }
      _videoPlayer = videoPlayer;
      videoPlayer.addListener(_onVideoPlayerUpdated);
      await videoPlayer.initialize();
      if (_isDisposed) {
        return;
      }
      _logService.info(
        'Video controller initialized: ${_controllerSnapshot(videoPlayer.value)}',
      );

      final Duration boundedStart = _clampToMaxDuration(
        startPosition,
        videoPlayer.value.duration,
      );
      await LockScreenPlaybackService.instance.activate(
        isCurrent: () => !_isDisposed,
        videoId: playable.videoId,
        title: _resolvedPlaybackTitle(),
        duration: videoPlayer.value.duration,
        callbacks: LockScreenPlaybackCallbacks(
          onPlay: play,
          onPause: pause,
          onSeek: seek,
          onSeekRelative: seekRelative,
          onAddBookmark: addManualBookmark,
          onStop: pause,
        ),
      );
      if (_isDisposed) {
        return;
      }
      if (boundedStart > Duration.zero) {
        await videoPlayer.seekTo(boundedStart);
      }
      if (_isDisposed) {
        return;
      }
      await _applyPlayerVolume(videoPlayer);
      if (_isDisposed) {
        return;
      }
      if (shouldAutoPlay) {
        await videoPlayer.play();
        _logService.info(
          'Autoplay started after initialization: '
          '${_controllerSnapshot(videoPlayer.value)}',
        );
      } else {
        _logService.info(
          'Autoplay suppressed after initialization by a start intent: '
          '${_controllerSnapshot(videoPlayer.value)}',
        );
      }
      if (_isDisposed) {
        return;
      }
      _startPlaybackHealthWatchdog();

      _periodicSaveTimer?.cancel();
      _periodicSaveTimer = Timer.periodic(
        _savePeriod,
        (_) => unawaited(_saveCurrentPosition()),
      );

      _syncFromVideoPlayer();
      state = state.copyWith(
        isLoading: false,
        isBuffering: false,
        sourceKind: playable.sourceKind,
      );
      await _seekToExternalStartIfNeeded();
      await _refreshBookmarks(syncRemote: true);
      if (_isDisposed) {
        return;
      }
      _bookmarksOutboxTimer?.cancel();
      _bookmarksOutboxTimer = Timer.periodic(
        _bookmarkOutboxRetryPeriod,
        (_) => unawaited(_syncOutboxAndRefreshBookmarks()),
      );
    } on InvalidDownloadException catch (error) {
      if (_isDisposed) {
        return;
      }
      await _setRemotePlaybackNetworkLock(false);
      if (_isDisposed) {
        return;
      }
      _logService.warn('Downloaded video check failed: ${error.reason}');
      state = state.copyWith(
        isLoading: false,
        isBuffering: false,
        errorMessage: error.message,
      );
    } on OfflinePlaybackUnavailableException catch (error) {
      if (_isDisposed) {
        return;
      }
      await _setRemotePlaybackNetworkLock(false);
      if (_isDisposed) {
        return;
      }
      _logService.warn('Offline playback unavailable: $error');
      state = state.copyWith(
        isLoading: false,
        isBuffering: false,
        errorMessage: error.message,
      );
    } catch (error, stackTrace) {
      if (_isDisposed) {
        return;
      }
      await _setRemotePlaybackNetworkLock(false);
      if (_isDisposed) {
        return;
      }
      _logService.error('Player initialization failed', error, stackTrace);
      state = state.copyWith(
        isLoading: false,
        isBuffering: false,
        errorMessage: 'Unable to play video: $error',
      );
    }
  }

  Future<void> _setRemotePlaybackNetworkLock(bool enabled) async {
    try {
      await AndroidRemotePlaybackNetworkLock.instance.setEnabled(enabled);
    } catch (error, stackTrace) {
      _logService.error(
        'setRemotePlaybackNetworkLock failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _setPlaybackScreenWakeLock(bool isPlaying) async {
    try {
      await _playbackScreenWakeLock.setPlaying(
        videoId: _videoId,
        isPlaying: isPlaying,
      );
    } catch (error, stackTrace) {
      _logService.error(
        'setPlaybackScreenWakeLock failed',
        error,
        stackTrace,
      );
    }
  }

  Future<VideoPlayerController> _createVideoPlayer(
    PlayableVideo playable, {
    required bool refreshRemoteSession,
    required String refreshReason,
  }) async {
    _logService.info(
      'Playback source kind selected ($refreshReason): '
      '${playable.sourceKind.name}, refreshRequested=$refreshRemoteSession.',
    );
    switch (playable.sourceKind) {
      case PlayableSourceKind.localFile:
        _logService.info(
          'Creating local file player: '
          '${_logService.sanitize(playable.sourceUri.toString())}',
        );
        return VideoPlayerController.file(
          File.fromUri(playable.sourceUri),
          videoPlayerOptions: _videoPlayerOptions,
        );
      case PlayableSourceKind.remoteUrl:
        final StreamAuthorizationHeaderResult authResult =
            await _streamAuthorizationHeaderProvider.buildHeaders(
          refreshSession: refreshRemoteSession,
          reason: refreshReason,
        );
        if (authResult.isFailure) {
          final StreamAuthorizationFailure failure = authResult.failure!;
          final String errorMessage = failure.message;
          _logService.warn(
            'playback-auth: remote playback authorization failed '
            '($refreshReason): '
            'reason=${failure.logCode}, '
            '${_logService.sanitize(errorMessage)}.',
          );
          _logService.warn(
            'playback-auth: aborting remote playback initialization before '
            'VideoPlayerController.networkUrl ($refreshReason): '
            'uri=${_logService.sanitize(playable.sourceUri.toString())}.',
          );
          throw _RemotePlaybackAuthorizationException(errorMessage);
        }
        _logService.info(
          'Remote playback authorization succeeded ($refreshReason): '
          'uri=${_logService.sanitize(playable.sourceUri.toString())}, '
          'auth=${authResult.headers.containsKey(HttpHeaders.authorizationHeader)}.',
        );
        return VideoPlayerController.networkUrl(
          playable.sourceUri,
          httpHeaders: authResult.headers,
          videoPlayerOptions: _videoPlayerOptions,
        );
    }
  }

  Duration _clampToMaxDuration(Duration value, Duration maxDuration) {
    if (maxDuration <= Duration.zero) {
      return value < Duration.zero ? Duration.zero : value;
    }
    if (value < Duration.zero) {
      return Duration.zero;
    }
    if (value > maxDuration) {
      return maxDuration;
    }
    return value;
  }

  void _onVideoPlayerUpdated() {
    if (_isDisposed) {
      return;
    }

    _syncFromVideoPlayer();
    final VideoPlayerController? controller = _videoPlayer;
    if (controller == null) {
      return;
    }

    final String? runtimeError = _runtimeErrorMessage(
      controller.value.errorDescription,
    );
    if (runtimeError != null && !_isRecovering) {
      if (_shouldLogRuntimeError(runtimeError)) {
        _logService.warn(
          'Runtime playback error detected (listener): '
          '${_logService.sanitize(runtimeError)}; '
          '${_controllerSnapshot(controller.value)}',
        );
      }
      unawaited(_recoverPlayback(reason: 'runtime-error'));
    }
    if (!controller.value.isInitialized) {
      return;
    }

    final Duration duration = controller.value.duration;
    if (duration <= Duration.zero) {
      return;
    }

    final bool isCompleted = controller.value.position >= duration;
    if (isCompleted && !_completionPositionSaved) {
      _completionPositionSaved = true;
      unawaited(_saveCurrentPosition(force: true));
      return;
    }

    if (!isCompleted) {
      _completionPositionSaved = false;
    }
  }

  Duration _clampToDuration(Duration value) {
    return _clampToMaxDuration(value, state.duration);
  }

  Future<void> _seekToExternalStartIfNeeded() async {
    final Duration? pendingPosition = _pendingExternalStartPosition;
    final VideoPlayerController? controller = _videoPlayer;
    if (_isDisposed || pendingPosition == null || controller == null) {
      return;
    }
    _pendingExternalStartPosition = null;
    try {
      final Duration duration = controller.value.duration;
      final Duration boundedPosition = _clampToMaxDuration(
        pendingPosition,
        duration,
      );
      await controller.seekTo(boundedPosition);
      await _saveCurrentPosition(force: true);
      _syncFromVideoPlayer();
    } catch (error, stackTrace) {
      _logService.error('applyExternalStartPosition failed', error, stackTrace);
    }
  }

  Future<void> _syncWithRemoteBeforeResume(
    VideoPlayerController controller,
    Duration positionBeforeResume,
  ) async {
    if (_isDisposed || !controller.value.isInitialized) {
      return;
    }

    try {
      final merged = await _playbackSyncRepository.reconcileVideo(_videoId);
      if (merged == null) {
        return;
      }

      final Duration target = _clampToMaxDuration(
        Duration(milliseconds: (merged.positionSeconds * 1000).round()),
        controller.value.duration,
      );
      final Duration current = _clampToMaxDuration(
        positionBeforeResume,
        controller.value.duration,
      );
      final Duration delta = target - current;
      if (delta.abs() < _remoteResumeSeekThreshold) {
        return;
      }

      await controller.seekTo(target);
      _lastSavedSeconds = merged.positionSeconds;
      _syncFromVideoPlayer();
    } catch (error, stackTrace) {
      _logService.error('syncWithRemoteBeforeResume failed', error, stackTrace);
    }
  }

  Future<void> _saveCurrentPosition({bool force = false}) async {
    final PlayableVideo? playable = _playable;
    final VideoPlayerController? controller = _videoPlayer;
    if (playable == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    final double seconds = controller.value.position.inMilliseconds / 1000;
    if (!force && (seconds - _lastSavedSeconds).abs() < 1) {
      return;
    }
    _lastSavedSeconds = seconds;
    await _playbackSyncRepository.savePosition(
      videoId: playable.videoId,
      positionSeconds: seconds,
    );
  }

  String? _runtimeErrorMessage(String? rawDescription) {
    final String description = (rawDescription ?? '').trim();
    if (description.isEmpty) {
      return null;
    }
    return 'Playback error: $description';
  }

  void _startPlaybackHealthWatchdog() {
    _playbackHealthTimer?.cancel();
    _bufferingStartedAtUtc = null;
    _stalledPositionStartedAtUtc = null;
    _lastObservedPlaybackPosition = state.position;
    _playbackHealthTimer = Timer.periodic(
      _playbackHealthCheckPeriod,
      (_) => unawaited(_watchPlaybackHealth()),
    );
  }

  Future<void> _watchPlaybackHealth() async {
    if (_isDisposed || _isRecovering) {
      return;
    }
    final VideoPlayerController? controller = _videoPlayer;
    if (controller == null) {
      return;
    }

    final VideoPlayerValue value = controller.value;
    final String? runtimeError = _runtimeErrorMessage(value.errorDescription);
    if (runtimeError != null) {
      if (_shouldLogRuntimeError(runtimeError)) {
        _logService.warn(
          'Runtime playback error detected (health watchdog): '
          '${_logService.sanitize(runtimeError)}; '
          '${_controllerSnapshot(value)}',
        );
      }
      await _recoverPlayback(reason: 'health-runtime-error');
      return;
    }
    if (!value.isInitialized) {
      return;
    }
    final DateTime now = DateTime.now().toUtc();
    final Duration duration = value.duration;
    final Duration currentPosition =
        value.position < Duration.zero ? Duration.zero : value.position;

    final bool isCompleted =
        duration > Duration.zero && currentPosition >= duration;
    if (isCompleted) {
      _bufferingStartedAtUtc = null;
      _stalledPositionStartedAtUtc = null;
      _lastObservedPlaybackPosition = currentPosition;
      return;
    }

    if (value.isBuffering) {
      _stalledPositionStartedAtUtc = null;
      _lastObservedPlaybackPosition = currentPosition;
      _bufferingStartedAtUtc ??= now;
      if (now.difference(_bufferingStartedAtUtc!) >=
          _bufferingRecoveryThreshold) {
        _logService.warn(
          'Health watchdog: buffering exceeded threshold '
          '(${_bufferingRecoveryThreshold.inSeconds}s); '
          '${_controllerSnapshot(value)}',
        );
        await _recoverPlayback(reason: 'long-buffering');
      }
      return;
    }
    _bufferingStartedAtUtc = null;

    if (!value.isPlaying) {
      _stalledPositionStartedAtUtc = null;
      _lastObservedPlaybackPosition = currentPosition;
      return;
    }

    final Duration delta = currentPosition - _lastObservedPlaybackPosition;
    if (delta.abs() >= _stalledPositionDeltaThreshold) {
      _stalledPositionStartedAtUtc = null;
      _lastObservedPlaybackPosition = currentPosition;
      _recoveryAttempts = 0;
      return;
    }

    _stalledPositionStartedAtUtc ??= now;
    if (now.difference(_stalledPositionStartedAtUtc!) >=
        _stalledPositionRecoveryThreshold) {
      _logService.warn(
        'Health watchdog: stalled position exceeded threshold '
        '(${_stalledPositionRecoveryThreshold.inSeconds}s); '
        'deltaMs=${delta.inMilliseconds}; ${_controllerSnapshot(value)}',
      );
      await _recoverPlayback(reason: 'stalled-position');
    }
  }

  Future<void> _recoverPlayback({required String reason}) async {
    if (_isDisposed || _isRecovering) {
      return;
    }
    final PlayableVideo? playable = _playable;
    final VideoPlayerController? current = _videoPlayer;
    if (playable == null || current == null) {
      return;
    }
    final DateTime now = DateTime.now().toUtc();
    final DateTime? blockedUntil = _recoveryRetryBlockedUntilUtc;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      final DateTime? lastLogAt = _lastRecoveryCooldownSkipLogAtUtc;
      if (lastLogAt == null ||
          now.difference(lastLogAt) >= _cooldownSkipLogThrottle) {
        _lastRecoveryCooldownSkipLogAtUtc = now;
        _logService.warn(
          'Recovery skipped ($reason): cooldown active until '
          '${blockedUntil.toIso8601String()}; '
          '${_controllerSnapshot(current.value)}',
        );
      }
      return;
    }
    if (_recoveryAttempts >= _maxRecoveryAttempts) {
      _recoveryAttempts = 0;
      _recoveryRetryBlockedUntilUtc = now.add(_recoveryRetryCooldownAfterLimit);
      _stickyPlaybackErrorMessage =
          'Playback interrupted. Reconnecting will continue automatically.';
      state = state.copyWith(
        isRecovering: false,
        isBuffering: false,
        errorMessage: _stickyPlaybackErrorMessage,
      );
      _logService.warn(
        'Recovery retry limit reached, delaying next attempt until '
        '${_recoveryRetryBlockedUntilUtc!.toIso8601String()}.',
      );
      return;
    }

    _isRecovering = true;
    _recoveryRetryBlockedUntilUtc = null;
    _lastRecoveryCooldownSkipLogAtUtc = null;
    _recoveryAttempts += 1;
    final int attempt = _recoveryAttempts;
    const bool shouldResumePlaying = true;
    final Duration rawResumePosition = current.value.isInitialized
        ? _clampToMaxDuration(current.value.position, current.value.duration)
        : state.position;
    final Duration resumePosition = _resolveRecoveryResumePosition(
      rawResumePosition,
    );

    state = state.copyWith(
      isRecovering: true,
      isBuffering: true,
      clearError: true,
    );
    _logService.warn(
      'Recovering playback ($reason), attempt=$attempt, '
      'autoPlay=$shouldResumePlaying, '
      'resumeMs=${resumePosition.inMilliseconds}, '
      'rawResumeMs=${rawResumePosition.inMilliseconds}, '
      'skipMs=${_corruptedSegmentRecoveryTracker.accumulatedSkip.inMilliseconds}; '
      '${_controllerSnapshot(current.value)}',
    );

    try {
      if (attempt > 1) {
        final Duration backoff = Duration(
          milliseconds: _recoveryBackoffStep.inMilliseconds * (attempt - 1),
        );
        await Future<void>.delayed(backoff);
        if (_isDisposed) {
          return;
        }
      }

      await _replaceVideoController(
        playable: playable,
        resumePosition: resumePosition,
        autoPlay: shouldResumePlaying,
        refreshReason: 'recover-$reason',
      );
      _recoveryAttempts = 0;
      _stickyPlaybackErrorMessage = null;
      _lastRuntimeErrorSignature = null;
      _lastRuntimeErrorLoggedAtUtc = null;
      final VideoPlayerController? recoveredController = _videoPlayer;
      if (recoveredController != null) {
        _logService.info(
          'Playback recovery succeeded ($reason), attempt=$attempt; '
          '${_controllerSnapshot(recoveredController.value)}',
        );
      } else {
        _logService.info(
          'Playback recovery succeeded ($reason), attempt=$attempt; '
          'controller is null after recovery.',
        );
      }
    } catch (error, stackTrace) {
      _logService.error(
        'Playback recovery failed ($reason, attempt=$attempt)',
        error,
        stackTrace,
      );
      _stickyPlaybackErrorMessage = 'Unable to recover playback: $error';
      if (!_isDisposed) {
        state = state.copyWith(
          isRecovering: false,
          isBuffering: false,
          errorMessage: _stickyPlaybackErrorMessage,
        );
      }
      return;
    } finally {
      _isRecovering = false;
      _bufferingStartedAtUtc = null;
      _stalledPositionStartedAtUtc = null;
      if (!_isDisposed) {
        _syncFromVideoPlayer();
      }
    }
  }

  Duration _resolveRecoveryResumePosition(Duration rawResumePosition) {
    final Duration effective =
        _corruptedSegmentRecoveryTracker.nextResumePosition(rawResumePosition);
    if (_corruptedSegmentRecoveryTracker.accumulatedSkip > Duration.zero) {
      _logService.warn(
        'Repeated playback failure near the same position; '
        'applying additional skip of '
        '${_corruptedSegmentRecoveryTracker.skipStep.inMilliseconds}ms, '
        'totalSkipMs=${_corruptedSegmentRecoveryTracker.accumulatedSkip.inMilliseconds}, '
        'positionMs=${rawResumePosition.inMilliseconds}.',
      );
    }
    return effective;
  }

  Future<void> _replaceVideoController({
    required PlayableVideo playable,
    required Duration resumePosition,
    required bool autoPlay,
    required String refreshReason,
  }) async {
    final VideoPlayerController? previous = _videoPlayer;
    final bool wasPreviousPlaying = previous?.value.isPlaying ?? false;
    _logService.debug(
      'Replacing video controller: source=${playable.sourceKind.name}, '
      'uri=${_logService.sanitize(playable.sourceUri.toString())}, '
      'resumeMs=${resumePosition.inMilliseconds}, autoPlay=$autoPlay.',
    );
    final VideoPlayerController next = await _createVideoPlayer(
      playable,
      refreshRemoteSession: playable.sourceKind == PlayableSourceKind.remoteUrl,
      refreshReason: refreshReason,
    );
    if (_isDisposed) {
      await next.dispose();
      return;
    }
    next.addListener(_onVideoPlayerUpdated);
    bool nextActivated = false;
    Duration boundedPosition = Duration.zero;
    try {
      await next.initialize();
      _logService.info(
        'New video controller initialized during replace: '
        '${_controllerSnapshot(next.value)}',
      );

      boundedPosition = _clampToMaxDuration(
        resumePosition,
        next.value.duration,
      );
      if (boundedPosition > Duration.zero) {
        await next.seekTo(boundedPosition);
      }
      await _applyPlayerVolume(next);
      if (_isDisposed) {
        next.removeListener(_onVideoPlayerUpdated);
        await next.dispose();
        return;
      }

      if (previous != null) {
        _logService.debug(
          'Parking previous video controller until replace commits: '
          '${_controllerSnapshot(previous.value)}',
        );
        previous.removeListener(_onVideoPlayerUpdated);
        try {
          await previous.pause();
        } catch (_) {}
      }

      if (_isDisposed) {
        next.removeListener(_onVideoPlayerUpdated);
        await next.dispose();
        return;
      }
      _videoPlayer = next;
      nextActivated = true;
      if (autoPlay) {
        await next.play();
        _logService.debug(
          'Auto-play requested after controller replace; '
          '${_controllerSnapshot(next.value)}',
        );
      }

      _completionPositionSaved = false;
      _lastObservedPlaybackPosition = boundedPosition;
      await LockScreenPlaybackService.instance.updateMediaMetadata(
        videoId: playable.videoId,
        title: _resolvedPlaybackTitle(),
        duration: next.value.duration,
      );
      _logService.debug(
        'Media metadata updated after controller replace: '
        'video=${playable.videoId}, durationMs=${next.value.duration.inMilliseconds}.',
      );
    } catch (_) {
      if (nextActivated && !_isDisposed) {
        _videoPlayer = previous;
        if (previous != null) {
          previous.addListener(_onVideoPlayerUpdated);
          if (wasPreviousPlaying && previous.value.isInitialized) {
            try {
              await previous.play();
            } catch (_) {}
          }
        }
      }
      next.removeListener(_onVideoPlayerUpdated);
      await next.dispose();
      rethrow;
    }

    if (previous != null) {
      _logService.debug(
        'Disposing previous video controller after replace commit: '
        '${_controllerSnapshot(previous.value)}',
      );
      try {
        await previous.dispose();
      } catch (error, stackTrace) {
        _logService.error(
          'Previous video controller disposal failed after replace commit',
          error,
          stackTrace,
        );
      }
    }
  }

  bool _shouldLogRuntimeError(String runtimeError) {
    final String signature = runtimeError.trim();
    final DateTime now = DateTime.now().toUtc();
    final String? previousSignature = _lastRuntimeErrorSignature;
    final DateTime? previousLoggedAt = _lastRuntimeErrorLoggedAtUtc;
    if (previousSignature == signature &&
        previousLoggedAt != null &&
        now.difference(previousLoggedAt) < _runtimeErrorLogThrottle) {
      return false;
    }
    _lastRuntimeErrorSignature = signature;
    _lastRuntimeErrorLoggedAtUtc = now;
    return true;
  }

  String _controllerSnapshot(VideoPlayerValue value) {
    final String rawError = (value.errorDescription ?? '').trim();
    final String sanitizedError =
        rawError.isEmpty ? '-' : _logService.sanitize(rawError);
    return 'initialized=${value.isInitialized}, '
        'playing=${value.isPlaying}, '
        'buffering=${value.isBuffering}, '
        'positionMs=${value.position.inMilliseconds}, '
        'durationMs=${value.duration.inMilliseconds}, '
        'error=$sanitizedError';
  }

  String _stateSnapshot() {
    final String error = (state.errorMessage ?? '').trim();
    final String sanitizedError =
        error.isEmpty ? '-' : _logService.sanitize(error);
    return 'uiLoading=${state.isLoading}, '
        'uiPlaying=${state.isPlaying}, '
        'uiBuffering=${state.isBuffering}, '
        'uiRecovering=${state.isRecovering}, '
        'uiPositionMs=${state.position.inMilliseconds}, '
        'uiDurationMs=${state.duration.inMilliseconds}, '
        'uiError=$sanitizedError';
  }

  Future<void> _addBookmarkAtCurrentPosition({required String caption}) async {
    final PlayableVideo? playable = _playable;
    final VideoPlayerController? controller = _videoPlayer;
    if (playable == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      final bool added = await _bookmarksRepository.addBookmark(
        videoId: playable.videoId,
        positionSeconds: controller.value.position.inMilliseconds / 1000,
        caption: caption,
      );
      if (added) {
        await _bookmarksRepository.processOutbox();
      }
      await _refreshBookmarks(syncRemote: false);
    } catch (error, stackTrace) {
      _logService.error('addBookmark failed', error, stackTrace);
    }
  }

  void _recordNavigation({
    required Duration fromPosition,
    required Duration toPosition,
  }) {
    if (_isDisposed) {
      return;
    }
    if (fromPosition == toPosition) {
      return;
    }
    if ((toPosition - fromPosition).abs() < _navigationCaptureThreshold) {
      return;
    }

    final PlayerNavigationEntry entry = PlayerNavigationEntry(
      id: _nextNavigationEntryId++,
      fromPosition: fromPosition,
      toPosition: toPosition,
      createdAtUtc: DateTime.now().toUtc(),
    );
    final List<PlayerNavigationEntry> updated = <PlayerNavigationEntry>[
      entry,
      ...state.navigationEntries,
    ];
    if (updated.length > _maxNavigationEntries) {
      updated.removeRange(_maxNavigationEntries, updated.length);
    }
    state = state.copyWith(navigationEntries: updated);
  }

  Future<void> _syncOutboxAndRefreshBookmarks() async {
    if (_isDisposed || _playable == null) {
      return;
    }
    try {
      await _bookmarksRepository.processOutbox();
      await _refreshBookmarks(syncRemote: false);
    } catch (error, stackTrace) {
      _logService.error(
        'syncOutboxAndRefreshBookmarks failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _refreshBookmarks({required bool syncRemote}) async {
    if (_isDisposed) {
      return;
    }

    try {
      final List<BookmarkItem> bookmarks = syncRemote
          ? await _bookmarksRepository.loadForVideo(_videoId)
          : await _bookmarksRepository.listLocalForVideo(_videoId);
      if (_isDisposed) {
        return;
      }
      state = state.copyWith(bookmarks: bookmarks);
    } catch (error, stackTrace) {
      _logService.error('refreshBookmarks failed', error, stackTrace);
    }
  }

  String _resolvedPlaybackTitle() {
    final String preferred = (_preferredTitle ?? '').trim();
    if (preferred.isNotEmpty) {
      return preferred;
    }
    final String playableTitle = (_playable?.title ?? '').trim();
    if (playableTitle.isNotEmpty) {
      return playableTitle;
    }
    return 'Video #$_videoId';
  }

  String? _normalizeTitle(String? title) {
    final String normalized = (title ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _publishLockScreenMediaMetadata() async {
    final PlayableVideo? playable = _playable;
    if (playable == null) {
      return;
    }
    final VideoPlayerController? controller = _videoPlayer;
    final Duration duration =
        controller != null && controller.value.isInitialized
            ? controller.value.duration
            : state.duration;
    await LockScreenPlaybackService.instance.updateMediaMetadata(
      videoId: playable.videoId,
      title: _resolvedPlaybackTitle(),
      duration: duration,
    );
  }

  void _syncFromVideoPlayer() {
    final VideoPlayerController? controller = _videoPlayer;
    if (controller == null) {
      return;
    }

    final VideoPlayerValue value = controller.value;
    final Duration duration =
        value.isInitialized ? value.duration : state.duration;
    final Duration position = value.isInitialized
        ? _clampToMaxDuration(value.position, duration)
        : state.position;
    final Duration normalizedDuration =
        duration < Duration.zero ? Duration.zero : duration;
    final Duration normalizedPosition =
        position < Duration.zero ? Duration.zero : position;
    final String? runtimeError = _runtimeErrorMessage(value.errorDescription);
    final String? effectiveError = runtimeError ?? _stickyPlaybackErrorMessage;
    _corruptedSegmentRecoveryTracker.clearIfRecovered(normalizedPosition);

    state = state.copyWith(
      isLoading: !value.isInitialized,
      isPlaying: value.isPlaying,
      isBuffering: !value.isInitialized || value.isBuffering,
      isRecovering: _isRecovering,
      position: normalizedPosition,
      duration: normalizedDuration,
      sourceKind: _playable?.sourceKind ?? state.sourceKind,
      errorMessage: effectiveError,
      clearError: effectiveError == null,
    );
    unawaited(_setPlaybackScreenWakeLock(value.isPlaying));
    final PlayableVideo? playable = _playable;
    if (playable != null) {
      unawaited(
        LockScreenPlaybackService.instance.updatePlaybackState(
          videoId: playable.videoId,
          isPlaying: value.isPlaying,
          isLoading: !value.isInitialized,
          isBuffering: !value.isInitialized || value.isBuffering,
          position: normalizedPosition,
          duration: normalizedDuration,
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _periodicSaveTimer?.cancel();
    _bookmarksOutboxTimer?.cancel();
    _playbackHealthTimer?.cancel();

    final VideoPlayerController? controller = _videoPlayer;
    final PlayableVideo? playable = _playable;
    if (controller != null &&
        playable != null &&
        controller.value.isInitialized) {
      final double seconds = controller.value.position.inMilliseconds / 1000;
      _lastSavedSeconds = seconds;
      unawaited(
        _playbackSyncRepository.savePosition(
          videoId: playable.videoId,
          positionSeconds: seconds,
        ),
      );
    }

    _videoPlayer = null;
    if (controller != null) {
      controller.removeListener(_onVideoPlayerUpdated);
      unawaited(controller.dispose());
    }
    unawaited(_setRemotePlaybackNetworkLock(false));
    unawaited(_setPlaybackScreenWakeLock(false));
    unawaited(LockScreenPlaybackService.instance.clear(videoId: _videoId));
    super.dispose();
  }
}

final playerControllerProvider = StateNotifierProvider.autoDispose
    .family<PlayerController, PlayerUiState, int>(
  (Ref ref, int videoId) => PlayerController(
    videoId: videoId,
    localOnly: ref.watch(effectiveAutonomousModeProvider),
    playVideoUseCase: ref.watch(playVideoUseCaseProvider),
    playbackSyncRepository: ref.watch(playbackSyncRepositoryProvider),
    bookmarksRepository: ref.watch(bookmarksRepositoryProvider),
    streamAuthorizationHeaderProvider: ref.watch(streamAuthHeaderProvider),
    logService: ref.watch(logServiceProvider),
    // Taken while the player is being built, which is what leaves no window in which it has
    // already started on its own. Nothing left an intent for an ordinary local open, so this is
    // null and the player resumes and plays exactly as it always has.
    startIntent: ref.watch(playerStartIntentsProvider).take(videoId),
    playerVolume: ref.watch(playerVolumeProvider),
  ),
);
