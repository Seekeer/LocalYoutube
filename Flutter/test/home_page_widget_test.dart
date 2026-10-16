import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_remote_data_source.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_thumbnail_service.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/catalog/domain/catalog_models.dart';
import 'package:localtube_flutter/features/downloads/data/offline_history_repository.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:localtube_flutter/features/downloads/domain/download_service.dart';
import 'package:localtube_flutter/features/home/presentation/home_page.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';

void main() {
  testWidgets('renders catalog items loaded by controller', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _FakeCatalogRepository repository = _FakeCatalogRepository(
      remoteItems: <CatalogItem>[
        const CatalogItem(
          id: 101,
          title: 'Widget Test Video',
          raw: <String, dynamic>{
            'id': 101,
            'title': 'Widget Test Video',
            'description': 'Short description',
            'seasonName': 'Season 1',
            'duration': '01:50:33',
          },
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
          catalogRepositoryProvider.overrideWithValue(repository),
          downloadServiceProvider.overrideWithValue(
            _DummyDownloadService(
              items: <DownloadItem>[
                DownloadItem(
                  videoId: 101,
                  status: DownloadStatus.completed,
                  progress: 1,
                  remoteUrl: '/files/getFileById?fileId=101',
                  title: 'Widget Test Video',
                  queuedAt: DateTime.utc(2026, 2, 16),
                  updatedAt: DateTime.utc(2026, 2, 16),
                  localPath: '/tmp/video_101.bin',
                ),
              ],
            ),
          ),
          localCatalogRepositoryProvider
              .overrideWithValue(_DummyLocalCatalogRepository()),
          catalogRemoteDataSourceProvider
              .overrideWithValue(_DummyCatalogRemoteDataSource()),
          localPlaybackRepositoryProvider
              .overrideWithValue(_DummyLocalPlaybackRepository()),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com',
              connectTimeoutMs: 15000,
              receiveTimeoutMs: 30000,
              sendTimeoutMs: 15000,
            ),
          ),
        ],
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('Последние'),
      findsWidgets,
    );
    expect(find.text('Widget Test Video'), findsOneWidget);
    expect(find.text('Season 1 | 1:50:33'), findsOneWidget);
    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository({
    this.remoteItems = const <CatalogItem>[],
  }) : super(
          remoteDataSource: CatalogRemoteDataSource(Dio()),
          localCatalogRepository: _DummyLocalCatalogRepository(),
          localVideoMetadataRepository: _DummyLocalVideoMetadataRepository(),
          localThumbnailService: _DummyLocalThumbnailService(),
          offlineHistoryRepository: _DummyOfflineHistoryRepository(),
          downloadService: _DummyDownloadService(),
          logService: _NoopLogService(),
        );

  final List<CatalogItem> remoteItems;

  @override
  Future<List<CatalogItem>> readCachedSection(CatalogSection section) async {
    return const <CatalogItem>[];
  }

  @override
  Future<(List<CatalogItem>, Failure?)> refreshSection(
    CatalogSection section,
  ) async {
    return (remoteItems, null);
  }
}

class _DummyLocalCatalogRepository extends LocalCatalogRepository {
  _DummyLocalCatalogRepository()
      : super(
          VideosCacheDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
        );
}

class _DummyLocalVideoMetadataRepository extends LocalVideoMetadataRepository {
  _DummyLocalVideoMetadataRepository()
      : super(
          VideoMetadataDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
        );
}

class _DummyLocalThumbnailService extends LocalThumbnailService {
  _DummyLocalThumbnailService()
      : super(
          dio: Dio(),
          localVideoMetadataRepository: _DummyLocalVideoMetadataRepository(),
          logService: _NoopLogService(),
        );

  @override
  Future<void> syncForItems(List<CatalogItem> items) async {}
}

class _DummyOfflineHistoryRepository extends OfflineHistoryRepository {
  _DummyOfflineHistoryRepository()
      : super(
          database: AppDatabase(executor: NativeDatabase.memory()),
          localVideoMetadataRepository: _DummyLocalVideoMetadataRepository(),
        );
}

class _DummyDownloadService implements DownloadService {
  _DummyDownloadService({
    this.items = const <DownloadItem>[],
  });

  final List<DownloadItem> items;

  @override
  Future<void> deleteLocal(int videoId) async {}

  @override
  Future<void> enqueue(
      {required int videoId, required String remoteUrl, String? title}) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pause(int videoId) async {}

  @override
  Future<void> resume(int videoId) async {}

  @override
  Future<void> stop(int videoId) async {}

  @override
  Stream<List<DownloadItem>> watchDownloads() {
    return Stream<List<DownloadItem>>.value(items);
  }
}

class _DummyCatalogRemoteDataSource extends CatalogRemoteDataSource {
  _DummyCatalogRemoteDataSource() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> loadSection(CatalogSection section) async {
    return const <Map<String, dynamic>>[];
  }
}

class _DummyLocalPlaybackRepository extends LocalPlaybackRepository {
  _DummyLocalPlaybackRepository()
      : super(
          PlaybackPositionsDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
        );

  @override
  Future<List<PlaybackPositionSnapshot>> listRecent({int limit = 50}) async {
    return const <PlaybackPositionSnapshot>[];
  }
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
