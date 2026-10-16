import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_remote_data_source.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_thumbnail_service.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/catalog/domain/catalog_models.dart';
import 'package:localtube_flutter/features/catalog/presentation/catalog_controller.dart';
import 'package:localtube_flutter/features/downloads/data/offline_history_repository.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:localtube_flutter/features/downloads/domain/download_service.dart';

void main() {
  test('reuses warm cache for repeated section loads', () async {
    final _FakeCatalogRepository repository = _FakeCatalogRepository(
      remoteItemsBySection: <CatalogSection, List<CatalogItem>>{
        CatalogSection.latest: const <CatalogItem>[
          CatalogItem(
            id: 10,
            title: 'Latest 10',
            raw: <String, dynamic>{'id': 10, 'title': 'Latest 10'},
          ),
        ],
      },
    );
    final CatalogController controller = CatalogController(repository);
    addTearDown(controller.dispose);

    await controller.loadSection(CatalogSection.latest);
    await controller.loadSection(CatalogSection.latest);

    expect(repository.refreshCallCount, 1);
    expect(controller.state.items, hasLength(1));
    expect(controller.state.items.first.id, 10);
  });

  test('debounces section switching and requests only the last section',
      () async {
    final _FakeCatalogRepository repository = _FakeCatalogRepository(
      remoteItemsBySection: <CatalogSection, List<CatalogItem>>{
        CatalogSection.latest: const <CatalogItem>[
          CatalogItem(
            id: 1,
            title: 'Latest',
            raw: <String, dynamic>{'id': 1, 'title': 'Latest'},
          ),
        ],
        CatalogSection.fresh: const <CatalogItem>[
          CatalogItem(
            id: 2,
            title: 'Fresh',
            raw: <String, dynamic>{'id': 2, 'title': 'Fresh'},
          ),
        ],
      },
    );
    final CatalogController controller = CatalogController(repository);
    addTearDown(controller.dispose);

    controller.scheduleLoadSection(CatalogSection.latest);
    controller.scheduleLoadSection(CatalogSection.fresh);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(repository.refreshCallCount, 1);
    expect(
        repository.requestedSections, <CatalogSection>[CatalogSection.fresh]);
    expect(controller.state.section, CatalogSection.fresh);
    expect(controller.state.items.first.id, 2);
  });

  test('deduplicates parallel loads for the same section', () async {
    final Completer<(List<CatalogItem>, Failure?)> freshRefresh =
        Completer<(List<CatalogItem>, Failure?)>();
    final _FakeCatalogRepository repository = _FakeCatalogRepository(
      remoteItemsBySection: <CatalogSection, List<CatalogItem>>{
        CatalogSection.fresh: const <CatalogItem>[
          CatalogItem(
            id: 3,
            title: 'Fresh',
            raw: <String, dynamic>{'id': 3, 'title': 'Fresh'},
          ),
        ],
      },
      pendingRefreshes: <CatalogSection,
          Completer<(List<CatalogItem>, Failure?)>>{
        CatalogSection.fresh: freshRefresh,
      },
    );
    final CatalogController controller = CatalogController(repository);
    addTearDown(controller.dispose);

    final Future<void> first = controller.loadSection(CatalogSection.fresh);
    final Future<void> second = controller.loadSection(CatalogSection.fresh);

    await Future<void>.delayed(Duration.zero);

    expect(repository.refreshCallCount, 1);
    expect(
      repository.requestedSections,
      <CatalogSection>[CatalogSection.fresh],
    );

    freshRefresh.complete((
      repository.remoteItemsBySection[CatalogSection.fresh]!,
      null,
    ));
    await Future.wait(<Future<void>>[first, second]);

    expect(controller.state.section, CatalogSection.fresh);
    expect(controller.state.items.single.id, 3);
  });

  test('refresh reuses in-flight load for the same section', () async {
    final Completer<(List<CatalogItem>, Failure?)> freshRefresh =
        Completer<(List<CatalogItem>, Failure?)>();
    final _FakeCatalogRepository repository = _FakeCatalogRepository(
      remoteItemsBySection: <CatalogSection, List<CatalogItem>>{
        CatalogSection.fresh: const <CatalogItem>[
          CatalogItem(
            id: 4,
            title: 'Fresh refresh',
            raw: <String, dynamic>{'id': 4, 'title': 'Fresh refresh'},
          ),
        ],
      },
      pendingRefreshes: <CatalogSection,
          Completer<(List<CatalogItem>, Failure?)>>{
        CatalogSection.fresh: freshRefresh,
      },
    );
    final CatalogController controller = CatalogController(repository);
    addTearDown(controller.dispose);

    final Future<void> first = controller.loadSection(CatalogSection.fresh);
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = controller.refresh();

    expect(repository.refreshCallCount, 1);
    expect(
      repository.requestedSections,
      <CatalogSection>[CatalogSection.fresh],
    );

    freshRefresh.complete((
      repository.remoteItemsBySection[CatalogSection.fresh]!,
      null,
    ));
    await Future.wait(<Future<void>>[first, second]);

    expect(controller.state.items.single.id, 4);
  });

  test('allows parallel remote loads for different sections', () async {
    final Completer<(List<CatalogItem>, Failure?)> latestRefresh =
        Completer<(List<CatalogItem>, Failure?)>();
    final Completer<(List<CatalogItem>, Failure?)> freshRefresh =
        Completer<(List<CatalogItem>, Failure?)>();
    final _FakeCatalogRepository repository = _FakeCatalogRepository(
      remoteItemsBySection: <CatalogSection, List<CatalogItem>>{
        CatalogSection.latest: const <CatalogItem>[
          CatalogItem(
            id: 5,
            title: 'Latest',
            raw: <String, dynamic>{'id': 5, 'title': 'Latest'},
          ),
        ],
        CatalogSection.fresh: const <CatalogItem>[
          CatalogItem(
            id: 6,
            title: 'Fresh',
            raw: <String, dynamic>{'id': 6, 'title': 'Fresh'},
          ),
        ],
      },
      pendingRefreshes: <CatalogSection,
          Completer<(List<CatalogItem>, Failure?)>>{
        CatalogSection.latest: latestRefresh,
        CatalogSection.fresh: freshRefresh,
      },
    );
    final CatalogController controller = CatalogController(repository);
    addTearDown(controller.dispose);

    final Future<void> latest = controller.loadSection(CatalogSection.latest);
    await Future<void>.delayed(Duration.zero);
    final Future<void> fresh = controller.loadSection(CatalogSection.fresh);
    await Future<void>.delayed(Duration.zero);

    expect(repository.refreshCallCount, 2);
    expect(
      repository.requestedSections,
      <CatalogSection>[CatalogSection.latest, CatalogSection.fresh],
    );

    latestRefresh.complete((
      repository.remoteItemsBySection[CatalogSection.latest]!,
      null,
    ));
    freshRefresh.complete((
      repository.remoteItemsBySection[CatalogSection.fresh]!,
      null,
    ));
    await Future.wait(<Future<void>>[latest, fresh]);

    expect(controller.state.section, CatalogSection.fresh);
    expect(controller.state.items.single.id, 6);
  });

  test('can refresh again after the previous request completes', () async {
    final _FakeCatalogRepository repository = _FakeCatalogRepository(
      remoteItemsBySection: <CatalogSection, List<CatalogItem>>{
        CatalogSection.fresh: const <CatalogItem>[
          CatalogItem(
            id: 7,
            title: 'Fresh',
            raw: <String, dynamic>{'id': 7, 'title': 'Fresh'},
          ),
        ],
      },
    );
    final CatalogController controller = CatalogController(repository);
    addTearDown(controller.dispose);

    await controller.loadSection(CatalogSection.fresh);
    await controller.loadSection(CatalogSection.fresh, forceRefresh: true);

    expect(repository.refreshCallCount, 2);
    expect(
      repository.requestedSections,
      <CatalogSection>[CatalogSection.fresh, CatalogSection.fresh],
    );
  });
}

class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository({
    required this.remoteItemsBySection,
    this.pendingRefreshes =
        const <CatalogSection, Completer<(List<CatalogItem>, Failure?)>>{},
  }) : super(
          remoteDataSource: CatalogRemoteDataSource(Dio()),
          localCatalogRepository: _DummyLocalCatalogRepository(),
          localVideoMetadataRepository: _DummyLocalVideoMetadataRepository(),
          localThumbnailService: _DummyLocalThumbnailService(),
          offlineHistoryRepository: _DummyOfflineHistoryRepository(),
          downloadService: _NoopDownloadService(),
          logService: _NoopLogService(),
        );

  final Map<CatalogSection, List<CatalogItem>> remoteItemsBySection;
  final Map<CatalogSection, Completer<(List<CatalogItem>, Failure?)>>
      pendingRefreshes;

  int refreshCallCount = 0;
  final List<CatalogSection> requestedSections = <CatalogSection>[];

  @override
  Future<List<CatalogItem>> readCachedSection(CatalogSection section) async {
    return const <CatalogItem>[];
  }

  @override
  Future<(List<CatalogItem>, Failure?)> refreshSection(
    CatalogSection section,
  ) async {
    refreshCallCount++;
    requestedSections.add(section);
    final Completer<(List<CatalogItem>, Failure?)>? pendingRefresh =
        pendingRefreshes[section];
    if (pendingRefresh != null) {
      return pendingRefresh.future;
    }
    return (remoteItemsBySection[section] ?? const <CatalogItem>[], null);
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

class _NoopDownloadService implements DownloadService {
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
  Stream<List<DownloadItem>> watchDownloads() {
    return const Stream<List<DownloadItem>>.empty();
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
