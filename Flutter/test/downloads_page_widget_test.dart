import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_remote_data_source.dart';
import 'package:localtube_flutter/features/catalog/data/local_catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:localtube_flutter/features/downloads/domain/download_service.dart';
import 'package:localtube_flutter/features/downloads/presentation/downloads_page.dart';

void main() {
  testWidgets('renders active downloads and dispatches pause action', (
    WidgetTester tester,
  ) async {
    final AppDatabase database = AppDatabase(executor: NativeDatabase.memory());
    final _FakeDownloadService downloadService = _FakeDownloadService(
      initialItems: <DownloadItem>[
        DownloadItem(
          videoId: 77,
          status: DownloadStatus.downloading,
          progress: 0.4,
          remoteUrl: '/files/getFileById?fileId=77',
          title: 'Video 77',
          queuedAt: DateTime.utc(2026, 2, 16, 0, 0, 0),
          updatedAt: DateTime.utc(2026, 2, 16, 0, 0, 0),
        ),
        DownloadItem(
          videoId: 78,
          status: DownloadStatus.damaged,
          progress: 1,
          remoteUrl: '/api/files/getFileById?fileId=78',
          title: 'Damaged video',
          queuedAt: DateTime.utc(2026, 2, 16),
          updatedAt: DateTime.utc(2026, 2, 16),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authNotifierProvider.overrideWith(
            (Ref ref) =>
                AuthNotifier(initialMode: AppAccessMode.onlineAuthenticated),
          ),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com',
              connectTimeoutMs: 15000,
              receiveTimeoutMs: 30000,
              sendTimeoutMs: 15000,
            ),
          ),
          downloadServiceProvider.overrideWithValue(downloadService),
          localCatalogRepositoryProvider
              .overrideWithValue(_FakeLocalCatalogRepository(database)),
          localVideoMetadataRepositoryProvider
              .overrideWithValue(_FakeLocalVideoMetadataRepository(database)),
          catalogRemoteDataSourceProvider
              .overrideWithValue(_FakeCatalogRemoteDataSource()),
        ],
        child: const MaterialApp(
          home: DownloadsPage(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Video 77'), findsOneWidget);
    expect(
      find.text(
          '\u0421\u043a\u0430\u0447\u0438\u0432\u0430\u0435\u043c\u043e\u0435'),
      findsOneWidget,
    );
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Downloaded video is damaged. Download it again.'),
        findsOneWidget);
    expect(find.byTooltip('Redownload'), findsOneWidget);
    await tester.tap(find.byTooltip('Redownload'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(downloadService.resumedVideoIds, contains(78));

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(downloadService.pausedVideoIds, contains(77));
  });
}

class _FakeDownloadService implements DownloadService {
  _FakeDownloadService({required this.initialItems});

  final List<DownloadItem> initialItems;

  final List<int> pausedVideoIds = <int>[];
  final List<int> resumedVideoIds = <int>[];

  @override
  Future<void> initialize() async {}

  @override
  Stream<List<DownloadItem>> watchDownloads() {
    return Stream<List<DownloadItem>>.value(initialItems);
  }

  @override
  Future<void> enqueue(
      {required int videoId, required String remoteUrl, String? title}) async {}

  @override
  Future<void> pause(int videoId) async {
    pausedVideoIds.add(videoId);
  }

  @override
  Future<void> resume(int videoId) async {
    resumedVideoIds.add(videoId);
  }

  @override
  Future<void> stop(int videoId) async {}

  @override
  Future<void> deleteLocal(int videoId) async {}
}

class _FakeLocalCatalogRepository extends LocalCatalogRepository {
  _FakeLocalCatalogRepository(AppDatabase database)
      : super(
          VideosCacheDao(
            database,
          ),
        );

  @override
  Future<List<Map<String, dynamic>>> readSection(String sectionKey) async {
    return const <Map<String, dynamic>>[];
  }
}

class _FakeLocalVideoMetadataRepository extends LocalVideoMetadataRepository {
  _FakeLocalVideoMetadataRepository(AppDatabase database)
      : super(
          VideoMetadataDao(
            database,
          ),
        );

  @override
  Future<LocalVideoMetadata?> findByVideoId(int videoId) async => null;
}

class _FakeCatalogRemoteDataSource extends CatalogRemoteDataSource {
  _FakeCatalogRemoteDataSource() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> loadSection(dynamic section) async {
    return const <Map<String, dynamic>>[];
  }
}
