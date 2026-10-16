import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/network/network_status.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_controller.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/catalog/domain/catalog_models.dart';
import 'package:localtube_flutter/features/player/domain/usecases/extract_timestamps_use_case.dart';
import 'package:localtube_flutter/features/player/domain/usecases/jump_to_nearest_timestamp_use_case.dart';
import 'package:localtube_flutter/features/player/presentation/player_controller.dart';
import 'package:localtube_flutter/features/player/presentation/player_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:video_player/video_player.dart';

class _TestPlayerController extends StateNotifier<PlayerUiState>
    implements PlayerController {
  _TestPlayerController(super.state);

  int pauseCallCount = 0;

  @override
  VideoPlayerController? get videoController => null;

  @override
  Future<void> addManualBookmark() async {}

  @override
  Future<void> applyExternalStartPosition(Duration position) async {}

  @override
  Future<void> deleteBookmark(int id) async {}

  @override
  Future<void> onLifecycleStateChanged(AppLifecycleState state) async {}

  @override
  Future<void> pause() async {
    pauseCallCount += 1;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position, {bool trackNavigation = true}) async {}

  @override
  Future<void> seekRelative(Duration offset) async {}

  @override
  Future<void> seekToNavigationOrigin(int id) async {}

  @override
  Future<void> setPlayerVolume(double volume) async {}

  @override
  Future<void> setPreferredTitle(String? title) async {}

  @override
  Future<void> togglePlayback() async {}
}

class _TestCastController extends StateNotifier<CastUiState>
    implements CastController {
  _TestCastController() : super(CastUiState.initial);

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
  Future<void> returnHandoff() async {}

  @override
  Future<void> setReceiverPlaying(bool isPlaying) async {}

  @override
  Future<void> seekReceiver(Duration position) async {}

  @override
  Future<void> setReceiverVolume(double volume) async {}
}

class _TestAuthNotifier extends Mock implements AuthNotifier {
  @override
  bool get isOfflineFallback => false;
}

class _TestAppConfig extends Fake implements AppConfig {
  @override
  String get apiBaseUrl => 'http://10.0.2.2:51254';

  @override
  int get connectTimeoutMs => 10000;

  @override
  String get crashReportUrl => '';

  @override
  int get receiveTimeoutMs => 20000;

  @override
  int get sendTimeoutMs => 10000;
}

class _TestLocalVideoMetadataRepository
    implements LocalVideoMetadataRepository {
  @override
  Future<LocalVideoMetadata?> findByVideoId(int videoId) async => null;

  @override
  Future<void> updateThumbnail({
    required int videoId,
    required String thumbnailLocalPath,
    DateTime? updatedAt,
  }) async {}

  @override
  Future<void> upsertCatalogItem(CatalogItem item) async {}

  @override
  Future<void> upsertCatalogItems(List<CatalogItem> items) async {}

  @override
  Future<void> upsertRouteMetadata({
    required int videoId,
    String? title,
    String? description,
  }) async {}

  @override
  Future<Map<int, String>> listThumbnailPaths() async {
    return const <int, String>{};
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fullscreen minimize controls run on Android emulator', (
    WidgetTester tester,
  ) async {
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

    const int videoId = 1;
    final _TestPlayerController controller = _TestPlayerController(
      const PlayerUiState(
        videoId: videoId,
        isLoading: false,
        isPlaying: true,
        isBuffering: false,
        isRecovering: false,
        position: Duration(seconds: 12),
        duration: Duration(minutes: 2),
        sourceKind: null,
        bookmarks: <Never>[],
        navigationEntries: <PlayerNavigationEntry>[],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith((Ref ref) => _TestAppConfig()),
          playerControllerProvider(videoId).overrideWith(
            (Ref ref) => controller,
          ),
          localVideoMetadataRepositoryProvider.overrideWith(
            (Ref ref) => _TestLocalVideoMetadataRepository(),
          ),
          extractTimestampsUseCaseProvider.overrideWith(
            (Ref ref) => ExtractTimestampsUseCase(),
          ),
          jumpToNearestTimestampUseCaseProvider.overrideWith(
            (Ref ref) => JumpToNearestTimestampUseCase(),
          ),
          castControllerProvider.overrideWith(
            (Ref ref) => _TestCastController(),
          ),
          networkStatusProvider.overrideWith(
            (Ref ref) => const Stream<NetworkStatus>.empty(),
          ),
          authNotifierProvider.overrideWith((Ref ref) => _TestAuthNotifier()),
        ],
        child: const MaterialApp(
          home: PlayerPage(
            videoId: '$videoId',
            videoDescription: '00:10 Intro',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Fullscreen'));
    await tester.pumpAndSettle();

    final Offset playerCenter = tester.getCenter(find.byType(GestureDetector));
    await tester.tapAt(playerCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(playerCenter);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Pause and minimize'), findsOneWidget);
    expect(find.byTooltip('Minimize'), findsOneWidget);

    tester
        .widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Pause and minimize'),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed!();
    await tester.pump();
    expect(controller.pauseCallCount, 1);
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
    expect(controller.pauseCallCount, 1);
    expect(
      appControlCalls,
      <String>['moveToBackground', 'moveToBackground'],
    );
  });
}
