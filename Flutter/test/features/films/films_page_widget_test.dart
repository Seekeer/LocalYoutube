import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_remote_data_source.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_thumbnail_service.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/catalog/domain/catalog_models.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
import 'package:localtube_flutter/features/downloads/data/offline_history_repository.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:localtube_flutter/features/downloads/domain/download_service.dart';
import 'package:localtube_flutter/features/films/data/films_remote_data_source.dart';
import 'package:localtube_flutter/features/films/domain/film_models.dart';
import 'package:localtube_flutter/features/films/presentation/films_controller.dart';
import 'package:localtube_flutter/features/films/presentation/films_page.dart';

void main() {
  late _FakeFilmsRemoteDataSource remote;
  late _FakeCatalogRepository catalog;

  setUp(() {
    remote = _FakeFilmsRemoteDataSource(<Film>[
      Film.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Сталкер',
        'year': 1979,
        'genres': 'фантастика, драма',
        'director': 'Андрей Тарковский',
        'description': 'Зона исполняет желания.',
        'durationMinutes': 163,
      }),
      Film.fromJson(<String, dynamic>{
        'id': 2,
        'name': 'Бриллиантовая рука',
        'year': 1968,
        'genres': 'комедия',
      }),
      Film.fromJson(<String, dynamic>{
        'id': 3,
        'name': 'Просмотренный',
        'year': 2015,
        'isFinished': true,
      }),
    ]);
    catalog = _FakeCatalogRepository();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    List<DownloadItem> downloads = const <DownloadItem>[],
    Size size = const Size(1400, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          filmsRemoteDataSourceProvider.overrideWithValue(remote),
          catalogRepositoryProvider.overrideWithValue(catalog),
          downloadServiceProvider
              .overrideWithValue(_DummyDownloadService(downloads)),
          logServiceProvider.overrideWithValue(_NoopLogService()),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com',
              connectTimeoutMs: 15000,
              receiveTimeoutMs: 30000,
              sendTimeoutMs: 15000,
            ),
          ),
        ],
        child: const MaterialApp(home: FilmsPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows unwatched films with their details, newest first', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Сталкер'), findsOneWidget);
    expect(find.text('Бриллиантовая рука'), findsOneWidget);
    expect(find.text('Просмотренный'), findsNothing);
    expect(find.text('1979 · 2 часа 43 мин'), findsOneWidget);
    expect(find.text('Режиссёр: Андрей Тарковский'), findsOneWidget);
    expect(find.text('Найдено: 2 из 3'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('film-card-1'))).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(const Key('film-card-2'))).dy,
      ),
    );

    await tester.tap(find.byKey(const Key('films-show-watched-switch')));
    await tester.pump();
    expect(find.text('Просмотренный'), findsOneWidget);
  });

  for (final double width in <double>[360, 560, 1100, 1700]) {
    testWidgets('cards fit a ${width.toInt()} px window', (
      WidgetTester tester,
    ) async {
      await pumpPage(
        tester,
        size: Size(width, 1800),
        downloads: <DownloadItem>[
          _download(1, DownloadStatus.downloading, 0.4),
        ],
      );
      await tester.tap(find.byKey(const Key('films-show-watched-switch')));
      await tester.pump();

      // A RenderFlex overflow fails the test on its own.
      expect(find.byKey(const Key('film-play-1')), findsOneWidget);
    });
  }

  testWidgets('genre chips and search narrow the list', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'комедия'));
    await tester.pump();
    expect(find.text('Сталкер'), findsNothing);
    expect(find.text('Бриллиантовая рука'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'комедия'));
    await tester.enterText(find.byKey(const Key('films-search-field')), 'стал');
    await tester.pump();
    expect(find.text('Сталкер'), findsOneWidget);
    expect(find.text('Бриллиантовая рука'), findsNothing);
  });

  testWidgets('download queues the film for this computer', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('film-download-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(catalog.queued.single.id, 1);
    expect(catalog.queued.single.title, 'Сталкер');
    expect(catalog.queued.single.remoteUrl, '/api/files/getFileById?fileId=1');
    expect(find.text('«Сталкер» поставлен на скачивание'), findsOneWidget);
  });

  testWidgets('download button reflects the local download state', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      downloads: <DownloadItem>[
        _download(1, DownloadStatus.completed, 1),
        _download(2, DownloadStatus.downloading, 0.4),
      ],
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('film-download-1')),
        matching: find.text('Скачано'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('film-download-2')),
        matching: find.text('Скачивается 40%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('marking watched hides the film', (WidgetTester tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('film-watched-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(remote.watchedIds, <int>[2]);
    expect(find.text('Бриллиантовая рука'), findsNothing);
  });

  testWidgets('delete asks first and removes the film from the server', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('film-delete-1')));
    await tester.pumpAndSettle();
    expect(find.text('Удалить фильм?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(catalog.deletedIds, isEmpty);

    await tester.tap(find.byKey(const Key('film-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('films-delete-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(catalog.deletedIds, <int>[1]);
    expect(find.text('Сталкер'), findsNothing);
  });
}

DownloadItem _download(int videoId, DownloadStatus status, double progress) {
  return DownloadItem(
    videoId: videoId,
    status: status,
    progress: progress,
    remoteUrl: '/api/files/getFileById?fileId=$videoId',
    queuedAt: DateTime.utc(2026, 11, 1),
    updatedAt: DateTime.utc(2026, 11, 1),
  );
}

class _FakeFilmsRemoteDataSource extends FilmsRemoteDataSource {
  _FakeFilmsRemoteDataSource(this.films) : super(Dio());

  final List<Film> films;
  final List<int> watchedIds = <int>[];

  @override
  Future<List<Film>> loadFilms() async => films;

  @override
  Future<void> markWatched(int videoId) async => watchedIds.add(videoId);
}

class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository()
      : super(
          remoteDataSource: CatalogRemoteDataSource(Dio()),
          localCatalogRepository: LocalCatalogRepository(
            VideosCacheDao(_database),
          ),
          localVideoMetadataRepository: _metadataRepository(),
          localThumbnailService: LocalThumbnailService(
            dio: Dio(),
            localVideoMetadataRepository: _metadataRepository(),
            logService: _NoopLogService(),
          ),
          offlineHistoryRepository: OfflineHistoryRepository(
            database: _database,
            localVideoMetadataRepository: _metadataRepository(),
          ),
          downloadService: _DummyDownloadService(const <DownloadItem>[]),
          logService: _NoopLogService(),
        );

  final List<CatalogItem> queued = <CatalogItem>[];
  final List<int> deletedIds = <int>[];

  @override
  Future<Failure?> queueDownload(CatalogItem item) async {
    queued.add(item);
    return null;
  }

  @override
  Future<Failure?> deleteServer(int videoId) async {
    deletedIds.add(videoId);
    return null;
  }
}

/// One in-memory database for the fakes: the catalog never touches it here.
final AppDatabase _database = AppDatabase(executor: NativeDatabase.memory());

LocalVideoMetadataRepository _metadataRepository() {
  return LocalVideoMetadataRepository(VideoMetadataDao(_database));
}

class _DummyDownloadService implements DownloadService {
  _DummyDownloadService(this.items);

  final List<DownloadItem> items;

  @override
  Future<void> deleteLocal(int videoId) async {}

  @override
  Future<void> enqueue({
    required int videoId,
    required String remoteUrl,
    String? title,
  }) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pause(int videoId) async {}

  @override
  Future<void> resume(int videoId) async {}

  @override
  Future<void> stop(int videoId) async {}

  @override
  Stream<List<DownloadItem>> watchDownloads() =>
      Stream<List<DownloadItem>>.value(items);
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
