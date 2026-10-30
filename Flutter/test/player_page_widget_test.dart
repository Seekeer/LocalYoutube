import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/network/network_status.dart';
import 'package:localtube_flutter/features/bookmarks/domain/bookmark_models.dart';
import 'package:localtube_flutter/features/app_updates/apk_update_controller.dart';
import 'package:localtube_flutter/features/cast/data/cast_playback_binding.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_labels.dart';
import 'package:localtube_flutter/features/cast/domain/cast_session_models.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_controller.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_entry_point.dart';
import 'package:localtube_flutter/features/cast/presentation/remote_control_mode_view.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/catalog/domain/catalog_models.dart';
import 'package:localtube_flutter/features/player/domain/player_models.dart';
import 'package:localtube_flutter/features/player/domain/usecases/extract_timestamps_use_case.dart';
import 'package:localtube_flutter/features/player/domain/usecases/jump_to_nearest_timestamp_use_case.dart';
import 'package:localtube_flutter/features/player/presentation/player_page.dart';
import 'package:localtube_flutter/features/player/presentation/player_controller.dart';
import 'package:localtube_flutter/features/sync/domain/sync_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

class MockPlayerController extends StateNotifier<PlayerUiState>
    implements PlayerController {
  MockPlayerController(super.state);
  Duration? lastSeekPosition;
  bool? lastSeekTrackNavigation;
  int? lastSeekToNavigationOriginId;
  double? lastPlayerVolume;
  int pauseCallCount = 0;
  int togglePlaybackCallCount = 0;

  void updatePosition(Duration position) {
    state = state.copyWith(position: position);
  }

  @override
  VideoPlayerController? get videoController => null;

  @override
  Future<void> togglePlayback() async {
    togglePlaybackCallCount += 1;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {
    pauseCallCount += 1;
  }

  @override
  Future<void> seek(Duration position, {bool trackNavigation = true}) async {
    lastSeekPosition = position;
    lastSeekTrackNavigation = trackNavigation;
  }

  @override
  Future<void> seekRelative(Duration offset) async {}

  @override
  Future<void> setPlayerVolume(double volume) async {
    lastPlayerVolume = volume;
  }

  @override
  Future<void> addManualBookmark() async {}

  @override
  Future<bool> addTextBookmark(double positionSeconds, String caption) async =>
      true;

  @override
  Future<void> setPreferredTitle(String? title) async {}

  @override
  Future<void> deleteBookmark(int id) async {}

  @override
  Future<void> seekToNavigationOrigin(int id) async {
    lastSeekToNavigationOriginId = id;
  }

  @override
  Future<void> onLifecycleStateChanged(AppLifecycleState state) async {}

  @override
  Future<void> applyExternalStartPosition(Duration position) async {}
}

class MockCastController extends StateNotifier<CastUiState>
    implements CastController {
  MockCastController(super.state);

  /// Every absolute position the Receiver was told to go to, oldest first.
  final List<Duration> seeks = <Duration>[];

  /// Every playing state the Receiver was told to reach, oldest first.
  final List<bool> playingCommands = <bool>[];

  /// Every volume the Receiver's player was told to take, oldest first.
  final List<double> volumes = <double>[];

  int returnedHandoffs = 0;

  /// Pushes the Cast Session on, exactly as the real controller does when the API says something.
  void emit(CastUiState next) {
    state = next;
  }

  @override
  Future<void> get initialized async {}

  @override
  Future<void> setReceiverMode(bool isReceiverMode) async {}

  @override
  Future<void> renameDevice(String name) async {}

  @override
  Future<void> selectReceiver(String? deviceId) async {}

  @override
  Future<void> startCast({required int videoId}) async {}

  @override
  Future<void> cancelCast() async {}

  @override
  Future<void> returnHandoff() async {
    returnedHandoffs++;
  }

  @override
  Future<void> setReceiverPlaying(bool isPlaying) async {
    playingCommands.add(isPlaying);
  }

  @override
  Future<void> seekReceiver(Duration position) async {
    seeks.add(position);
  }

  @override
  Future<void> setReceiverVolume(double volume) async {
    volumes.add(volume);
  }
}

class MockExtractTimestampsUseCase extends Fake
    implements ExtractTimestampsUseCase {
  @override
  List<VideoTimestamp> call(String description) => [];
}

class MockJumpToNearestTimestampUseCase extends Fake
    implements JumpToNearestTimestampUseCase {}

class MockAuthNotifier extends Mock implements AuthNotifier {
  @override
  bool get isOfflineFallback => false;
}

class MockAppConfig extends Fake implements AppConfig {
  @override
  String get apiBaseUrl =>
      'https://api.example.invalid:9999';

  @override
  int get connectTimeoutMs => 15000;

  @override
  int get receiveTimeoutMs => 30000;

  @override
  int get sendTimeoutMs => 15000;

  @override
  String get crashReportUrl => '';
}

class MockLocalVideoMetadataRepository implements LocalVideoMetadataRepository {
  @override
  Future<void> upsertRouteMetadata({
    required int videoId,
    String? title,
    String? description,
  }) async {}

  @override
  Future<void> upsertCatalogItem(CatalogItem item) async {}

  Future<LocalVideoMetadata?> findById(int videoId) async => null;

  Future<void> delete(int videoId) async {}

  @override
  Future<LocalVideoMetadata?> findByVideoId(int videoId) async => null;

  @override
  Future<void> updateThumbnail({
    required int videoId,
    required String thumbnailLocalPath,
    DateTime? updatedAt,
  }) async {}

  @override
  Future<void> upsertCatalogItems(List<CatalogItem> items) async {}

  @override
  Future<Map<int, String>> listThumbnailPaths() async {
    return const <int, String>{};
  }
}

Widget buildPlayerPage({
  required String videoId,
  required MockPlayerController controller,
  ExtractTimestampsUseCase? extractTimestampsUseCase,
  JumpToNearestTimestampUseCase? jumpToNearestTimestampUseCase,
  CastUiState? castState,
  MockCastController? castController,
}) {
  final int parsedVideoId = int.parse(videoId);

  return ProviderScope(
    overrides: <Override>[
      appConfigProvider.overrideWith((ref) => MockAppConfig()),
      playerControllerProvider(parsedVideoId).overrideWith((ref) => controller),
      localVideoMetadataRepositoryProvider.overrideWith(
        (ref) => MockLocalVideoMetadataRepository(),
      ),
      extractTimestampsUseCaseProvider.overrideWith(
        (ref) => extractTimestampsUseCase ?? MockExtractTimestampsUseCase(),
      ),
      jumpToNearestTimestampUseCaseProvider.overrideWith(
        (ref) =>
            jumpToNearestTimestampUseCase ??
            MockJumpToNearestTimestampUseCase(),
      ),
      castControllerProvider.overrideWith(
        (ref) =>
            castController ??
            MockCastController(castState ?? CastUiState.initial),
      ),
      networkStatusProvider.overrideWith(
        (ref) => const Stream<NetworkStatus>.empty(),
      ),
      authNotifierProvider.overrideWith((ref) => MockAuthNotifier()),
    ],
    child: MaterialApp(
      home: PlayerPage(
        videoId: videoId,
        videoDescription: '00:10 Intro\n00:40 Chapter 2',
      ),
    ),
  );
}

/// A phone in Remote Control Mode: the Cast Session reached the Receiver, so playback lives
/// there and this device owns no player.
CastUiState remoteControlState({
  CastPlaybackState? confirmedState,
  SyncConnectionState connectionState = SyncConnectionState.connected,
  bool isSessionReconnecting = false,
}) {
  return CastUiState(
    isReceiverMode: false,
    deviceName: 'Pixel 8',
    deviceModel: 'Pixel 8',
    receivers: const <CastDeviceLabel>[],
    selectedReceiverDeviceId: null,
    connectionState: connectionState,
    phase: CastPhase.remoteControl,
    sessionId: 'session-1',
    castVideoId: 42,
    castReceiverName: 'Living room',
    confirmedState: confirmedState,
    isSessionReconnecting: isSessionReconnecting,
  );
}

/// The page's own player, playing an ordinary video. Nothing in Remote Control Mode may read it,
/// which is exactly what the tests that use it assert.
MockPlayerController buildLocalPlayer() {
  return MockPlayerController(
    const PlayerUiState(
      videoId: 42,
      isLoading: false,
      isPlaying: true,
      isBuffering: false,
      isRecovering: false,
      position: Duration(seconds: 30),
      duration: Duration(minutes: 10),
      sourceKind: null,
      bookmarks: <BookmarkItem>[],
      navigationEntries: <PlayerNavigationEntry>[],
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(AppLifecycleState.resumed);
    registerFallbackValue(MockAppConfig());
  });

  testWidgets('paused viewing owns the update installation guard until the page closes', (tester) async {
    final controller = MockPlayerController(const PlayerUiState(
      videoId: 42, isLoading: false, isPlaying: false, isBuffering: false,
      isRecovering: false, position: Duration(seconds: 30),
      duration: Duration(minutes: 10), sourceKind: null,
      bookmarks: <BookmarkItem>[], navigationEntries: <PlayerNavigationEntry>[],
    ));
    await tester.pumpWidget(buildPlayerPage(videoId: '42', controller: controller));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(PlayerPage)));
    final surfaces = container.read(openUpdatePlaybackSurfacesProvider);
    expect(surfaces.count, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(surfaces.count, 0);
  });

  testWidgets('shows invalid id message when videoId is not numeric', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PlayerPage(videoId: 'not-a-number'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Invalid video id'), findsOneWidget);
  });

  testWidgets('shows offline playback error without a loading indicator', (
    WidgetTester tester,
  ) async {
    const String message = 'This video is not available offline.';
    final MockPlayerController controller = MockPlayerController(
      const PlayerUiState(
        videoId: 42,
        isLoading: false,
        isPlaying: false,
        isBuffering: false,
        isRecovering: false,
        position: Duration.zero,
        duration: Duration.zero,
        sourceKind: null,
        bookmarks: <BookmarkItem>[],
        navigationEntries: <PlayerNavigationEntry>[],
        errorMessage: message,
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(videoId: '42', controller: controller),
    );
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.text('Video stream is unavailable'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets(
      'Remote Control Mode names the Receiver, shows the connection and owns '
      'no local video player', (WidgetTester tester) async {
    final MockPlayerController controller = buildLocalPlayer();

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: controller,
        castState: remoteControlState(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(RemoteControlModeView.title), findsOneWidget);
    expect(find.text('Living room'), findsOneWidget);
    expect(find.byKey(RemoteControlModeView.connectionStatusKey), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);

    // No local video player, and none of the surface that would drive one. The sliders that are
    // here drive the Receiver instead, which is what the mode is for.
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byType(CastEntryPoint), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsNothing);
    expect(find.byKey(RemoteControlModeView.seekSliderKey), findsOneWidget);
    expect(find.byKey(RemoteControlModeView.volumeSliderKey), findsOneWidget);
  });

  testWidgets(
      'Remote Control Mode renders the position, length and status the '
      'Receiver confirmed', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castState: remoteControlState(
          confirmedState: const CastPlaybackState(
            videoId: 42,
            position: Duration(minutes: 3, seconds: 20),
            isPlaying: true,
            duration: Duration(minutes: 45),
            isBuffering: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(RemoteControlModeView.positionKey)).data,
      '03:20',
    );
    expect(
      tester.widget<Text>(find.byKey(RemoteControlModeView.durationKey)).data,
      '45:00',
    );
    expect(
      tester
          .widget<Text>(find.byKey(RemoteControlModeView.playbackStatusKey))
          .data,
      RemoteControlModeView.bufferingLabel,
    );
  });

  testWidgets('Remote Control Mode plays, pauses and seeks the Receiver',
      (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(seconds: 30),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    // A playing Receiver is asked to pause, which is a state rather than a toggle.
    await tester.tap(find.byKey(RemoteControlModeView.playPauseButtonKey));
    await tester.pump();
    expect(castController.playingCommands, <bool>[false]);

    // Every seek is absolute, including the one behind a relative-looking button.
    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Back 10s'),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!();
    await tester.pump();
    expect(castController.seeks, <Duration>[const Duration(seconds: 20)]);
  });

  // The two below drag and tap the sliders themselves rather than calling the callbacks behind
  // them, because the property they are about is what the viewer sees after letting go: the bar
  // moves under a finger and then hands the value straight back to the Receiver. A callback
  // invoked directly never touches the widget and so never shows whether it did.

  testWidgets(
      'the seek bar sends an absolute position and does not move the phone '
      'until the Receiver confirms it', (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(seconds: 30),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    final Finder seekSlider = find.byKey(RemoteControlModeView.seekSliderKey);
    expect(tester.widget<Slider>(seekSlider).value, 30.0);

    await tester.drag(seekSlider, const Offset(160, 0));
    await tester.pumpAndSettle();

    // A seek went out, and it is an absolute position somewhere further into the video.
    expect(castController.seeks, hasLength(1));
    expect(castController.seeks.single.inSeconds, greaterThan(30));

    // The bar is back where the Receiver last said it was, and so is the time under it. There is
    // no optimistic seek: a command the Receiver never applied must not show as having happened.
    expect(tester.widget<Slider>(seekSlider).value, 30.0);
    expect(
      tester.widget<Text>(find.byKey(RemoteControlModeView.positionKey)).data,
      '00:30',
    );

    // It moves when the Receiver says it has, and not before.
    castController.emit(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(minutes: 5),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(seekSlider).value, 300.0);
    expect(
      tester.widget<Text>(find.byKey(RemoteControlModeView.positionKey)).data,
      '05:00',
    );
  });

  testWidgets(
      'the volume bar sets the Receiver player volume and does not move the '
      'phone until the Receiver confirms it', (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(seconds: 30),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    // The Receiver last reported itself at its loudest, which is where the bar stands.
    final Finder volumeSlider = find.byKey(
      RemoteControlModeView.volumeSliderKey,
    );
    expect(tester.widget<Slider>(volumeSlider).value, 1.0);

    // Tapped halfway along a bar that runs from silent to loudest.
    await tester.tap(volumeSlider);
    await tester.pumpAndSettle();

    expect(castController.volumes, hasLength(1));
    expect(castController.volumes.single, lessThan(1.0));
    expect(castController.volumes.single, greaterThan(0.0));

    // The Receiver's player volume is the Receiver's to report, so the bar is back at the last
    // volume it confirmed rather than at the one that was just asked for.
    expect(tester.widget<Slider>(volumeSlider).value, 1.0);

    castController.emit(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(seconds: 30),
          isPlaying: true,
          duration: Duration(minutes: 10),
          volume: 0.25,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(volumeSlider).value, 0.25);
  });

  testWidgets(
      'selecting a timestamp seeks the Receiver to that absolute position',
      (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(seconds: 5),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        extractTimestampsUseCase: ExtractTimestampsUseCase(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Chapter 2'), findsOneWidget);

    tester
        .widget<ListTile>(
          find.byKey(
            RemoteControlModeView.timestampKey(const Duration(seconds: 40)),
          ),
        )
        .onTap!();
    await tester.pump();

    expect(castController.seeks, <Duration>[const Duration(seconds: 40)]);
  });

  testWidgets(
      'Remote Control Mode makes bookmarks, downloads, deletion and the '
      'navigation history unreachable', (WidgetTester tester) async {
    final MockPlayerController controller = MockPlayerController(
      PlayerUiState(
        videoId: 42,
        isLoading: false,
        isPlaying: true,
        isBuffering: false,
        isRecovering: false,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 10),
        sourceKind: null,
        bookmarks: <BookmarkItem>[
          BookmarkItem(
            id: 3,
            videoId: 42,
            positionSeconds: 12,
            caption: 'A bookmark',
            updatedAt: DateTime.utc(2026, 4, 24),
          ),
        ],
        navigationEntries: <PlayerNavigationEntry>[
          PlayerNavigationEntry(
            id: 7,
            fromPosition: const Duration(seconds: 5),
            toPosition: const Duration(seconds: 15),
            createdAtUtc: DateTime.utc(2026, 4, 24),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: controller,
        castState: remoteControlState(
          confirmedState: const CastPlaybackState(
            videoId: 42,
            position: Duration(seconds: 30),
            isPlaying: true,
            duration: Duration(minutes: 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // None of these belongs to a video playing on somebody else's screen, so none of them is built
    // at all while playback lives on the Receiver.
    expect(find.byTooltip('Add bookmark'), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('Bookmarks'), findsNothing);
    expect(find.text('A bookmark'), findsNothing);
    expect(find.text('Navigation'), findsNothing);
    expect(find.text('Back to 00:05'), findsNothing);
  });

  testWidgets('Return Handoff is offered and asks for playback back',
      (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(minutes: 4),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(RemoteControlModeView.returnHandoffLabel), findsOneWidget);
    await tester.tap(find.byKey(RemoteControlModeView.returnHandoffButtonKey));
    await tester.pump();

    expect(castController.returnedHandoffs, 1);
  });

  testWidgets(
      'Remote Control Mode says the television is reconnecting and lets the '
      'viewer stop waiting', (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(minutes: 4),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    // An ordinary Cast Session says nothing about reconnecting.
    expect(find.byKey(RemoteControlModeView.reconnectingKey), findsNothing);

    castController.emit(
      remoteControlState(
        isSessionReconnecting: true,
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(minutes: 4),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(RemoteControlModeView.reconnectingKey), findsOneWidget);
    expect(find.text(RemoteControlModeView.reconnectingLabel), findsOneWidget);

    // Remote Control Mode is still what the phone is, and still shows what the Receiver last
    // confirmed rather than going blank while it waits.
    expect(find.text(RemoteControlModeView.title), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(RemoteControlModeView.positionKey)).data,
      '04:00',
    );

    // And the viewer does not have to wait the minute out.
    await tester.tap(find.byKey(RemoteControlModeView.returnHandoffButtonKey));
    await tester.pump();
    expect(castController.returnedHandoffs, 1);
  });

  testWidgets('leaving Remote Control Mode restores the ordinary local player '
      'surface', (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(minutes: 4),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(RemoteControlModeView.title), findsOneWidget);

    // The Cast Session is over, whichever way it ended.
    castController.emit(CastUiState.initial);
    await tester.pumpAndSettle();

    expect(find.text(RemoteControlModeView.title), findsNothing);
    expect(find.byKey(RemoteControlModeView.seekSliderKey), findsNothing);
    expect(find.byTooltip('Add bookmark'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    expect(find.byType(CastEntryPoint), findsOneWidget);
  });

  testWidgets(
      'entering Remote Control Mode closes fullscreen and takes its local '
      'affordances with it', (WidgetTester tester) async {
    final MockCastController castController =
        MockCastController(CastUiState.initial);

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    // Fullscreen is opened while the Handoff is still being prepared, which is exactly when local
    // playback is still this device's: the viewer goes on watching here until the Receiver says
    // what it reached.
    await tester.tap(find.byTooltip('Fullscreen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Finder fullscreen = find.byKey(
      const Key('fullscreen-player-gesture-area'),
    );
    expect(fullscreen, findsOneWidget);

    // Its controls, with the local-only affordances a Cast Session has to take away.
    final Offset playerCenter = tester.getCenter(fullscreen);
    await tester.tapAt(playerCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(playerCenter);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byTooltip('Exit fullscreen'), findsOneWidget);
    expect(find.byTooltip('Add bookmark'), findsWidgets);

    // The Receiver confirms the state it reached, so playback lives there now.
    castController.emit(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(seconds: 30),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fullscreen is gone rather than left holding a player this device has given up, and every
    // local-only affordance it carried went with it.
    expect(fullscreen, findsNothing);
    expect(find.byType(VideoPlayer), findsNothing);
    expect(find.byTooltip('Add bookmark'), findsNothing);
    expect(find.byTooltip('Exit fullscreen'), findsNothing);
    expect(find.byIcon(Icons.undo), findsNothing);

    // And the viewer lands on the remote itself rather than on a blank screen.
    expect(find.text(RemoteControlModeView.title), findsOneWidget);
    expect(find.byKey(RemoteControlModeView.seekSliderKey), findsOneWidget);
  });

  testWidgets(
      'a page opened in Remote Control Mode offers the Cast Session no local '
      'player', (WidgetTester tester) async {
    final MockCastController castController = MockCastController(
      remoteControlState(
        confirmedState: const CastPlaybackState(
          videoId: 42,
          position: Duration(seconds: 30),
          isPlaying: true,
          duration: Duration(minutes: 10),
        ),
      ),
    );

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: '42',
        controller: buildLocalPlayer(),
        castController: castController,
      ),
    );
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    final CastPlaybackBinding binding =
        container.read(castPlaybackBindingProvider);

    // This page owns no player in Remote Control Mode, so it offers none: a Cast Session that read
    // playback through one, or resumed through one, would build the very player the mode has given
    // up.
    expect(binding.currentPlayer, isNull);
    expect(binding.readPlayback(), isNull);

    // It is offered again the moment the Cast Session ends and the ordinary surface is back.
    castController.emit(CastUiState.initial);
    await tester.pumpAndSettle();

    expect(binding.currentPlayer, isNotNull);
    expect(binding.readPlayback()?.videoId, 42);
  });

  testWidgets('shows share button in player controls',
      (WidgetTester tester) async {
    const String videoIdStr = '1';
    final int videoId = int.parse(videoIdStr);

    final PlayerUiState initialState = PlayerUiState(
      videoId: videoId,
      isLoading: false,
      isPlaying: false,
      isBuffering: false,
      isRecovering: false,
      position: Duration.zero,
      duration: const Duration(minutes: 10),
      sourceKind: null,
      bookmarks: const [],
      navigationEntries: const [],
    );

    final mockController = MockPlayerController(initialState);

    await tester.pumpWidget(
      buildPlayerPage(
        videoId: videoIdStr,
        controller: mockController,
      ),
    );
    await tester.pumpAndSettle();

    final shareButton = find.byIcon(Icons.share_outlined);
    expect(shareButton, findsOneWidget);
  });

  testWidgets(
    'fullscreen controls replace delete with next section and back actions',
    (WidgetTester tester) async {
      final List<String> appControlCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('org.localtube.app/app_control'),
        (MethodCall methodCall) async {
          appControlCalls.add(methodCall.method);
          return null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('org.localtube.app/app_control'),
          null,
        );
      });

      const String videoIdStr = '1';
      final int videoId = int.parse(videoIdStr);
      final mockController = MockPlayerController(
        PlayerUiState(
          videoId: videoId,
          isLoading: false,
          isPlaying: false,
          isBuffering: false,
          isRecovering: false,
          position: const Duration(seconds: 15),
          duration: const Duration(minutes: 10),
          sourceKind: null,
          bookmarks: const [],
          navigationEntries: <PlayerNavigationEntry>[
            PlayerNavigationEntry(
              id: 7,
              fromPosition: const Duration(seconds: 5),
              toPosition: const Duration(seconds: 15),
              createdAtUtc: DateTime.utc(2026, 4, 24),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        buildPlayerPage(
          videoId: videoIdStr,
          controller: mockController,
          extractTimestampsUseCase: ExtractTimestampsUseCase(),
          jumpToNearestTimestampUseCase: JumpToNearestTimestampUseCase(),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Fullscreen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Offset playerCenter =
          tester.getCenter(find.byType(GestureDetector).last);
      await tester.tapAt(playerCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(playerCenter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byTooltip('Next section'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Pause and minimize'), findsOneWidget);
      expect(find.byTooltip('Minimize'), findsOneWidget);

      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Next section'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!();
      await tester.pump();
      expect(mockController.lastSeekPosition, const Duration(seconds: 40));
      expect(mockController.lastSeekTrackNavigation, true);

      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Back'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!();
      await tester.pump();
      expect(mockController.lastSeekToNavigationOriginId, 7);

      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Pause and minimize'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!();
      await tester.pump();
      expect(mockController.pauseCallCount, 1);
      expect(appControlCalls, <String>['moveToBackground']);

      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Minimize'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!();
      await tester.pump();
      expect(mockController.pauseCallCount, 1);
      expect(
        appControlCalls,
        <String>['moveToBackground', 'moveToBackground'],
      );
    },
  );

  testWidgets(
    'locked fullscreen shows a live read-only timeline and hides it with the lock button',
    (WidgetTester tester) async {
      const String videoIdStr = '1';
      final MockPlayerController mockController = MockPlayerController(
        const PlayerUiState(
          videoId: 1,
          isLoading: false,
          isPlaying: true,
          isBuffering: false,
          isRecovering: false,
          position: Duration(seconds: 15),
          duration: Duration(minutes: 10),
          sourceKind: null,
          bookmarks: <BookmarkItem>[],
          navigationEntries: <PlayerNavigationEntry>[],
        ),
      );

      await tester.pumpWidget(
        buildPlayerPage(videoId: videoIdStr, controller: mockController),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Fullscreen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final Finder fullscreenGestureDetector = find.byKey(
        const Key('fullscreen-player-gesture-area'),
      );
      final Offset playerCenter = tester.getCenter(fullscreenGestureDetector);
      await tester.tapAt(playerCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(playerCenter);
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byTooltip('Lock screen'), findsOneWidget);
      await tester.tap(find.byTooltip('Lock screen'));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

      expect(find.byTooltip('Unlock screen'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(find.byTooltip('Next section'), findsNothing);
      expect(find.byTooltip('Exit fullscreen'), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 15);
      expect(tester.widget<Slider>(find.byType(Slider)).max, 600);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(tester.widget<Slider>(find.byType(Slider)).onChangeEnd, isNull);
      expect(find.text('00:15'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.byTooltip('Unlock screen'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('00:15'), findsNothing);
      expect(find.text('10:00'), findsNothing);

      mockController.updatePosition(const Duration(seconds: 30));
      await tester.pump();
      await tester.tapAt(playerCenter);
      await tester.pump();
      expect(mockController.togglePlaybackCallCount, 0);
      expect(find.byTooltip('Unlock screen'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 30);
      expect(find.text('00:30'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 4999));
      expect(find.byTooltip('Unlock screen'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byTooltip('Unlock screen'), findsNothing);
      expect(find.byType(Slider), findsNothing);

      await tester.tapAt(playerCenter);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.tapAt(playerCenter);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(find.byTooltip('Unlock screen'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(mockController.togglePlaybackCallCount, 0);

      mockController.updatePosition(const Duration(seconds: 45));
      await tester.pump();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 45);
      expect(find.text('00:45'), findsOneWidget);
      expect(find.text('00:30'), findsNothing);

      final Offset timelineCenter = tester.getCenter(find.byType(Slider));
      await tester.tapAt(timelineCenter + const Offset(100, 0));
      await tester.pump();
      await tester.dragFrom(timelineCenter, const Offset(200, 0));
      await tester.pump();
      await tester.tapAt(playerCenter);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(playerCenter);
      await tester.pump();
      expect(mockController.lastSeekPosition, isNull);
      expect(mockController.togglePlaybackCallCount, 0);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 45);
      expect(find.byTooltip('Unlock screen'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);

      await tester.tap(find.byTooltip('Unlock screen'));
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));

      expect(find.byTooltip('Lock screen'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('Exit fullscreen'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
      expect(tester.widget<Slider>(find.byType(Slider)).onChangeEnd, isNotNull);

      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pump();
      expect(mockController.lastSeekPosition, isNotNull);
      expect(mockController.lastSeekPosition!.inSeconds, greaterThan(45));

      await tester.tapAt(playerCenter);
      await tester.pump(const Duration(milliseconds: 350));
      expect(mockController.togglePlaybackCallCount, 1);
    },
  );
}
