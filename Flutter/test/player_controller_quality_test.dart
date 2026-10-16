import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/bookmarks/data/bookmarks_repository.dart';
import 'package:localtube_flutter/features/bookmarks/domain/bookmark_models.dart';
import 'package:localtube_flutter/features/downloads/data/download_file_validator.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_screen_wake_lock.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/player/data/stream_authorization_header_provider.dart';
import 'package:localtube_flutter/features/player/domain/player_models.dart';
import 'package:localtube_flutter/features/player/domain/usecases/play_video_use_case.dart';
import 'package:localtube_flutter/features/player/presentation/player_controller.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayerPlatform originalPlatform;
  late _FakeVideoPlayerPlatform fakePlatform;
  late _FakePlaybackSyncRepository playbackSyncRepository;
  late _FakeBookmarksRepository bookmarksRepository;
  late _RecordingLogService logService;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    playbackSyncRepository = _FakePlaybackSyncRepository();
    bookmarksRepository = _FakeBookmarksRepository();
    logService = _RecordingLogService();
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
  });

  testWidgets(
    'screen wake lock follows playback and is released on dispose',
    (WidgetTester tester) async {
      final _RecordingPlaybackScreenWakeLock screenWakeLock =
          _RecordingPlaybackScreenWakeLock();
      final PlayerController controller = PlayerController(
        videoId: 73,
        playVideoUseCase: _FakePlayVideoUseCase(
          PlayableVideo(
            videoId: 73,
            sourceUri: Uri.parse('https://example.invalid/video.mp4'),
            sourceKind: PlayableSourceKind.remoteUrl,
            startPosition: Duration.zero,
            title: 'Keep awake video',
          ),
        ),
        playbackSyncRepository: playbackSyncRepository,
        bookmarksRepository: bookmarksRepository,
        streamAuthorizationHeaderProvider:
            _ScriptedStreamAuthorizationHeaderProvider(
          <StreamAuthorizationHeaderResult>[
            StreamAuthorizationHeaderResult.success(
              const <String, String>{
                HttpHeaders.authorizationHeader: 'Bearer token',
              },
            ),
          ],
        ),
        logService: logService,
        localOnly: false,
        playbackScreenWakeLock: screenWakeLock,
      );

      await tester.pump();
      for (int attempt = 0;
          attempt < 10 && !controller.state.isPlaying;
          attempt += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(controller.state.isPlaying, isTrue);
      expect(screenWakeLock.isPlayingByVideo[73], isTrue);

      await controller.pause();
      await tester.pump();
      expect(screenWakeLock.isPlayingByVideo[73], isFalse);

      await controller.play();
      await tester.pump();
      expect(screenWakeLock.isPlayingByVideo[73], isTrue);

      controller.dispose();
      expect(screenWakeLock.isPlayingByVideo[73], isFalse);
    },
  );

  testWidgets(
      'player aborts remote initialization before networkUrl create when auth fails',
      (WidgetTester tester) async {
    final PlayerController controller = PlayerController(
      videoId: 42,
      playVideoUseCase: _FakePlayVideoUseCase(
        PlayableVideo(
          videoId: 42,
          sourceUri: Uri.parse('https://example.invalid/video.mp4'),
          sourceKind: PlayableSourceKind.remoteUrl,
          startPosition: Duration.zero,
          title: 'Remote video',
        ),
      ),
      playbackSyncRepository: playbackSyncRepository,
      bookmarksRepository: bookmarksRepository,
      streamAuthorizationHeaderProvider:
          _ScriptedStreamAuthorizationHeaderProvider(
        <StreamAuthorizationHeaderResult>[
          const StreamAuthorizationHeaderResult.failure(
            StreamAuthorizationFailure(
              reason: StreamAuthorizationFailureReason.refreshFailed,
              message: 'Playback session refresh failed. Please try again.',
            ),
          ),
        ],
      ),
      logService: logService,
      localOnly: false,
    );

    await tester.pump();
    await tester.pump();

    expect(fakePlatform.createCallCount, 0);
    expect(controller.videoController, isNull);
    expect(
      controller.state.errorMessage,
      contains('Playback session refresh failed. Please try again.'),
    );

    controller.dispose();
  });

  testWidgets(
      'failed recovery keeps prior controller alive and a later retry can still replace it',
      (WidgetTester tester) async {
    final PlayerController controller = PlayerController(
      videoId: 99,
      playVideoUseCase: _FakePlayVideoUseCase(
        PlayableVideo(
          videoId: 99,
          sourceUri: Uri.parse('https://example.invalid/video.mp4'),
          sourceKind: PlayableSourceKind.remoteUrl,
          startPosition: Duration.zero,
          title: 'Recoverable remote video',
        ),
      ),
      playbackSyncRepository: playbackSyncRepository,
      bookmarksRepository: bookmarksRepository,
      streamAuthorizationHeaderProvider:
          _ScriptedStreamAuthorizationHeaderProvider(
        <StreamAuthorizationHeaderResult>[
          StreamAuthorizationHeaderResult.success(
            const <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer first-token',
            },
          ),
          const StreamAuthorizationHeaderResult.failure(
            StreamAuthorizationFailure(
              reason: StreamAuthorizationFailureReason.refreshFailed,
              message: 'Playback session refresh failed. Please try again.',
            ),
          ),
          StreamAuthorizationHeaderResult.success(
            const <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer second-token',
            },
          ),
        ],
      ),
      logService: logService,
      localOnly: false,
    );

    await tester.pump();
    for (int attempt = 0;
        attempt < 10 &&
            (controller.videoController == null ||
                !(controller.videoController?.value.isInitialized ?? false) ||
                controller.state.isLoading);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final VideoPlayerController originalController =
        controller.videoController!;
    final int originalPlayerId = originalController.playerId;
    expect(originalController.value.isInitialized, isTrue);
    expect(fakePlatform.createCallCount, 1);

    fakePlatform.pushError(
      playerId: originalPlayerId,
      message: 'decoder exploded',
    );
    await tester.pump();
    await tester.pump();

    expect(fakePlatform.createCallCount, 1);
    expect(fakePlatform.disposedPlayerIds, isNot(contains(originalPlayerId)));
    expect(controller.videoController, same(originalController));

    fakePlatform.pushError(
      playerId: originalPlayerId,
      message: 'decoder exploded again',
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    for (int attempt = 0;
        attempt < 10 &&
            identical(controller.videoController, originalController);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(fakePlatform.createCallCount, 2);
    expect(controller.videoController, isNot(same(originalController)));
    expect(controller.videoController?.playerId, isNot(originalPlayerId));

    controller.dispose();
  });

  testWidgets(
      'previous controller cleanup failure after commit does not surface false recovery failure',
      (WidgetTester tester) async {
    final PlayerController controller = PlayerController(
      videoId: 77,
      playVideoUseCase: _FakePlayVideoUseCase(
        PlayableVideo(
          videoId: 77,
          sourceUri: Uri.parse('https://example.invalid/video.mp4'),
          sourceKind: PlayableSourceKind.remoteUrl,
          startPosition: Duration.zero,
          title: 'Cleanup failure video',
        ),
      ),
      playbackSyncRepository: playbackSyncRepository,
      bookmarksRepository: bookmarksRepository,
      streamAuthorizationHeaderProvider:
          _ScriptedStreamAuthorizationHeaderProvider(
        <StreamAuthorizationHeaderResult>[
          StreamAuthorizationHeaderResult.success(
            const <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer first-token',
            },
          ),
          StreamAuthorizationHeaderResult.success(
            const <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer second-token',
            },
          ),
        ],
      ),
      logService: logService,
      localOnly: false,
    );

    await tester.pump();
    for (int attempt = 0;
        attempt < 10 &&
            (controller.videoController == null ||
                !(controller.videoController?.value.isInitialized ?? false) ||
                controller.state.isLoading);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final VideoPlayerController originalController =
        controller.videoController!;
    final int originalPlayerId = originalController.playerId;
    fakePlatform.playerIdsToFailDispose.add(originalPlayerId);

    fakePlatform.pushError(
      playerId: originalPlayerId,
      message: 'recover me',
    );
    await tester.pump();
    for (int attempt = 0;
        attempt < 10 &&
            identical(controller.videoController, originalController);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.videoController, isNot(same(originalController)));
    expect(controller.state.errorMessage,
        isNot(contains('Unable to recover playback')));
    expect(
      logService.errors.where(
        (String entry) => entry.contains('Playback recovery failed'),
      ),
      isEmpty,
    );

    controller.dispose();
  });

  test(
      'corrupted segment recovery tracker progressively skips repeated failures',
      () {
    final CorruptedSegmentRecoveryTracker tracker =
        CorruptedSegmentRecoveryTracker(
      skipStep: const Duration(seconds: 3),
      repeatWindow: const Duration(seconds: 5),
    );

    expect(
      tracker.nextResumePosition(const Duration(milliseconds: 209237)),
      const Duration(milliseconds: 209237),
    );
    expect(tracker.accumulatedSkip, Duration.zero);

    expect(
      tracker.nextResumePosition(const Duration(milliseconds: 209237)),
      const Duration(milliseconds: 212237),
    );
    expect(tracker.accumulatedSkip, const Duration(seconds: 3));

    expect(
      tracker.nextResumePosition(const Duration(milliseconds: 212237)),
      const Duration(milliseconds: 215237),
    );
    expect(tracker.accumulatedSkip, const Duration(seconds: 3));

    tracker.clearIfRecovered(const Duration(milliseconds: 225000));
    expect(
      tracker.nextResumePosition(const Duration(milliseconds: 300000)),
      const Duration(milliseconds: 300000),
    );
    expect(tracker.accumulatedSkip, Duration.zero);
  });

  testWidgets('recovery resumes playback automatically after runtime error',
      (WidgetTester tester) async {
    final PlayerController controller = PlayerController(
      videoId: 56,
      playVideoUseCase: _FakePlayVideoUseCase(
        PlayableVideo(
          videoId: 56,
          sourceUri: Uri.parse('https://example.invalid/video.mp4'),
          sourceKind: PlayableSourceKind.remoteUrl,
          startPosition: Duration.zero,
          title: 'Auto resume video',
        ),
      ),
      playbackSyncRepository: playbackSyncRepository,
      bookmarksRepository: bookmarksRepository,
      streamAuthorizationHeaderProvider:
          _ScriptedStreamAuthorizationHeaderProvider(
        <StreamAuthorizationHeaderResult>[
          StreamAuthorizationHeaderResult.success(
            const <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer first-token',
            },
          ),
          StreamAuthorizationHeaderResult.success(
            const <String, String>{
              HttpHeaders.authorizationHeader: 'Bearer second-token',
            },
          ),
        ],
      ),
      logService: logService,
      localOnly: false,
    );

    await tester.pump();
    for (int attempt = 0;
        attempt < 10 &&
            (controller.videoController == null ||
                !(controller.videoController?.value.isInitialized ?? false) ||
                controller.state.isLoading);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final VideoPlayerController originalController =
        controller.videoController!;
    final int originalPlayerId = originalController.playerId;
    expect(originalController.value.isPlaying, isTrue);

    fakePlatform.pushError(
      playerId: originalPlayerId,
      message: 'recover and continue',
    );
    await tester.pump();
    for (int attempt = 0;
        attempt < 10 &&
            identical(controller.videoController, originalController);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(controller.videoController, isNot(same(originalController)));
    expect(controller.videoController?.value.isPlaying, isTrue);

    controller.dispose();
  });

  testWidgets('damaged download shows an actionable error without recovery',
      (WidgetTester tester) async {
    const InvalidDownloadException failure =
        InvalidDownloadException('Invalid MP4 box size.');
    final PlayerController controller = PlayerController(
      videoId: 42,
      localOnly: true,
      playVideoUseCase: _FakePlayVideoUseCase(null, error: failure),
      playbackSyncRepository: playbackSyncRepository,
      bookmarksRepository: bookmarksRepository,
      streamAuthorizationHeaderProvider:
          _ScriptedStreamAuthorizationHeaderProvider(
              const <StreamAuthorizationHeaderResult>[]),
      logService: logService,
    );
    await tester.pump();
    expect(fakePlatform.createCallCount, 0);
    expect(controller.state.isLoading, isFalse);
    expect(controller.state.isRecovering, isFalse);
    expect(controller.state.errorMessage, failure.message);
    controller.dispose();
  });

  testWidgets('offline playback failure does not create a video controller',
      (WidgetTester tester) async {
    const OfflinePlaybackUnavailableException failure =
        OfflinePlaybackUnavailableException(videoId: 42);
    final PlayerController controller = PlayerController(
      videoId: 42,
      localOnly: true,
      playVideoUseCase: _FakePlayVideoUseCase(
        null,
        error: failure,
      ),
      playbackSyncRepository: playbackSyncRepository,
      bookmarksRepository: bookmarksRepository,
      streamAuthorizationHeaderProvider:
          _ScriptedStreamAuthorizationHeaderProvider(
              const <StreamAuthorizationHeaderResult>[]),
      logService: logService,
    );

    await tester.pump();

    expect(fakePlatform.createCallCount, 0);
    expect(controller.videoController, isNull);
    expect(controller.state.isLoading, isFalse);
    expect(controller.state.errorMessage, contains(failure.message));

    controller.dispose();
  });
}

class _FakePlayVideoUseCase implements PlayVideoUseCase {
  _FakePlayVideoUseCase(this._playable, {this.error});

  final PlayableVideo? _playable;
  final Object? error;

  @override
  Future<PlayableVideo> call(
      {required int videoId, bool localOnly = false}) async {
    final Object? error = this.error;
    if (error != null) {
      throw error;
    }
    return _playable!;
  }
}

class _RecordingPlaybackScreenWakeLock implements PlaybackScreenWakeLock {
  final Map<int, bool> isPlayingByVideo = <int, bool>{};

  @override
  Future<void> setPlaying({
    required int videoId,
    required bool isPlaying,
  }) async {
    isPlayingByVideo[videoId] = isPlaying;
  }
}

class _FakePlaybackSyncRepository implements PlaybackSyncRepository {
  @override
  Future<void> processOutbox() async {}

  @override
  Future<PlaybackPositionSnapshot?> reconcileVideo(int videoId) async => null;

  @override
  Future<void> reconcileRecent({int limit = 20}) async {}

  @override
  Future<Duration> resolveStartPosition(
    int videoId, {
    bool localOnly = false,
  }) async =>
      Duration.zero;

  @override
  Future<void> savePosition({
    required int videoId,
    required double positionSeconds,
    DateTime? updatedAt,
    bool syncRemote = true,
  }) async {}
}

class _FakeBookmarksRepository implements BookmarksRepository {
  @override
  Future<bool> addBookmark({
    required int videoId,
    required double positionSeconds,
    required String caption,
  }) async {
    return true;
  }

  @override
  Future<void> deleteBookmark(int bookmarkId) async {}

  @override
  Future<List<BookmarkItem>> listLocalForVideo(int videoId) async {
    return const <BookmarkItem>[];
  }

  @override
  Future<List<BookmarkItem>> loadForVideo(int videoId) async {
    return const <BookmarkItem>[];
  }

  @override
  Future<void> processOutbox() async {}

  @override
  Future<void> reconcileVideo(int videoId) async {}
}

class _ScriptedStreamAuthorizationHeaderProvider
    implements StreamAuthorizationHeaderProvider {
  _ScriptedStreamAuthorizationHeaderProvider(this._results);

  final List<StreamAuthorizationHeaderResult> _results;

  @override
  Future<StreamAuthorizationHeaderResult> buildHeaders({
    required bool refreshSession,
    required String reason,
  }) async {
    if (_results.isEmpty) {
      throw StateError('No scripted auth result left for $reason');
    }
    return _results.removeAt(0);
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int createCallCount = 0;
  int _nextPlayerId = 1;
  final List<int> disposedPlayerIds = <int>[];
  final Set<int> playerIdsToFailDispose = <int>{};
  final Map<int, StreamController<VideoEvent>> _events =
      <int, StreamController<VideoEvent>>{};
  final Map<int, Duration> _positions = <int, Duration>{};
  final Map<int, Duration> _durations = <int, Duration>{};
  final Set<int> _pendingInitializedEvents = <int>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final int playerId = _nextPlayerId++;
    createCallCount += 1;
    final StreamController<VideoEvent> controller =
        StreamController<VideoEvent>.broadcast();
    _events[playerId] = controller;
    _positions[playerId] = Duration.zero;
    _durations[playerId] = const Duration(seconds: 30);
    _pendingInitializedEvents.add(playerId);
    return playerId;
  }

  @override
  Future<void> dispose(int playerId) async {
    if (playerIdsToFailDispose.remove(playerId)) {
      throw StateError('dispose failed for $playerId');
    }
    disposedPlayerIds.add(playerId);
    await _events.remove(playerId)?.close();
    _positions.remove(playerId);
    _durations.remove(playerId);
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  void pushError({
    required int playerId,
    required String message,
  }) {
    _events[playerId]?.addError(
      PlatformException(code: 'video', message: message),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    _events[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> play(int playerId) async {
    _events[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    if (_pendingInitializedEvents.remove(playerId)) {
      scheduleMicrotask(() {
        final StreamController<VideoEvent>? controller = _events[playerId];
        if (controller == null || controller.isClosed) {
          return;
        }
        controller.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: _durations[playerId],
            size: const Size(1920, 1080),
          ),
        );
      });
    }
    return _events[playerId]!.stream;
  }

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();
}

class _NoopLogService extends LogService {
  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, Object error, StackTrace stackTrace) {}
}

class _RecordingLogService extends _NoopLogService {
  final List<String> errors = <String>[];

  @override
  void error(String message, Object error, StackTrace stackTrace) {
    errors.add('$message :: $error');
  }
}
