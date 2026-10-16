import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/downloads_dao.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
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

void main() {
  late AppDatabase database;
  late CatalogRepository repository;
  late LocalVideoMetadataRepository metadataRepository;
  late PlaybackPositionsDao playbackPositionsDao;
  late DownloadsDao downloadsDao;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();
    metadataRepository =
        LocalVideoMetadataRepository(VideoMetadataDao(database));
    playbackPositionsDao = PlaybackPositionsDao(database);
    downloadsDao = DownloadsDao(database);

    repository = CatalogRepository(
      remoteDataSource: CatalogRemoteDataSource(Dio()),
      localCatalogRepository: LocalCatalogRepository(VideosCacheDao(database)),
      localVideoMetadataRepository: metadataRepository,
      localThumbnailService: _DummyLocalThumbnailService(
        metadataRepository: metadataRepository,
      ),
      offlineHistoryRepository: OfflineHistoryRepository(
        database: database,
        localVideoMetadataRepository: metadataRepository,
      ),
      downloadService: _NoopDownloadService(),
      logService: _NoopLogService(),
    );
  });

  test('history cache is sourced from offline playback history', () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('catalog_history_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final File localVideo = File(
      '${tempDir.path}${Platform.pathSeparator}video_77.bin',
    );
    await localVideo.writeAsBytes(const <int>[1, 2, 3]);

    await metadataRepository.upsertCatalogItem(
      const CatalogItem(
        id: 77,
        title: 'Offline watched',
        raw: <String, dynamic>{
          'id': 77,
          'title': 'Offline watched',
          'description': 'Saved locally',
          'durationSeconds': 321,
          'seasonName': 'Season A',
        },
      ),
    );
    await downloadsDao.upsertDownload(
      videoId: 77,
      status: DownloadStatus.completed.value,
      progress: 1,
      remoteUrl: '/api/files/getFileById?fileId=77',
      localPath: localVideo.path,
      queuedAt: DateTime.utc(2026, 3, 17, 10),
    );
    await playbackPositionsDao.savePosition(
      videoId: 77,
      positionSeconds: 45,
      updatedAt: DateTime.utc(2026, 3, 17, 11),
    );

    final List<CatalogItem> items =
        await repository.readCachedSection(CatalogSection.history);

    expect(items, hasLength(1));
    expect(items.single.id, 77);
    expect(items.single.title, 'Offline watched');
    expect(items.single.description, 'Saved locally');
    expect(items.single.raw['duration'], 321);
    expect(items.single.raw['seasonName'], 'Season A');
    expect(items.single.raw['isPlayableOffline'], isTrue);
  });
}

class _DummyLocalThumbnailService extends LocalThumbnailService {
  _DummyLocalThumbnailService({
    required LocalVideoMetadataRepository metadataRepository,
  }) : super(
          dio: Dio(),
          localVideoMetadataRepository: metadataRepository,
          logService: _NoopLogService(),
        );

  @override
  Future<void> syncForItems(List<CatalogItem> items) async {}
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
