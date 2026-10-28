import 'dart:async';
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
  late _ControlledThumbnailService thumbnails;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();
    metadataRepository =
        LocalVideoMetadataRepository(VideoMetadataDao(database));
    playbackPositionsDao = PlaybackPositionsDao(database);
    downloadsDao = DownloadsDao(database);

    addTearDown(database.close);
    thumbnails = _ControlledThumbnailService(metadataRepository);
    repository = CatalogRepository(
      remoteDataSource: _FreshRemoteDataSource(),
      localCatalogRepository: LocalCatalogRepository(VideosCacheDao(database)),
      localVideoMetadataRepository: metadataRepository,
      localThumbnailService: thumbnails,
      offlineHistoryRepository: OfflineHistoryRepository(
        database: database,
        localVideoMetadataRepository: metadataRepository,
      ),
      downloadService: _NoopDownloadService(),
      logService: _NoopLogService(),
    );
  });

  test('fresh list completes while offline thumbnails are still pending',
      () async {
    final refresh = repository.refreshSection(CatalogSection.fresh);
    await thumbnails.started.future;
    try {
      final result = await refresh.timeout(const Duration(milliseconds: 200));
      expect(result.$2, isNull);
      expect(result.$1.single.id, 86);
      expect(
          (await repository.readCachedSection(CatalogSection.fresh)).single.id,
          86);
      expect((await metadataRepository.findByVideoId(86))?.title, 'New video');
    } finally {
      thumbnails.release.complete();
      await refresh;
      await thumbnails.finished.future;
    }
  });

  test('measure fresh list with a 500ms offline thumbnail stage', () async {
    thumbnails.release.complete();
    thumbnails.delay = const Duration(milliseconds: 500);
    final Stopwatch timer = Stopwatch()..start();
    final result = await repository.refreshSection(CatalogSection.fresh);
    timer.stop();
    stdout.writeln('fresh refresh: ${timer.elapsedMicroseconds / 1000} ms '
        '(simulated thumbnail stage: 500 ms)');
    expect(result.$2, isNull);
    await thumbnails.finished.future;
  });

  test('repeated refreshes coalesce pending artwork into one next batch',
      () async {
    await repository.refreshSection(CatalogSection.fresh);
    await thumbnails.started.future;
    await repository.refreshSection(CatalogSection.fresh);
    await repository.refreshSection(CatalogSection.fresh);
    expect(thumbnails.batches, hasLength(1));
    thumbnails.release.complete();
    await thumbnails.secondFinished.future;
    expect(thumbnails.batches, hasLength(2));
    expect(
        thumbnails.batches.last.map((CatalogItem item) => item.id), <int>[86]);
  });

  test('artwork failure does not fail refresh or stop pending artwork',
      () async {
    thumbnails.failFirst = true;
    final first = await repository.refreshSection(CatalogSection.fresh);
    await thumbnails.started.future;
    final second = await repository.refreshSection(CatalogSection.fresh);
    thumbnails.release.complete();
    await thumbnails.secondFinished.future;
    expect(first.$2, isNull);
    expect(second.$2, isNull);
    expect(thumbnails.batches, hasLength(2));
    expect((await repository.readCachedSection(CatalogSection.fresh)).single.id,
        86);
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

class _FreshRemoteDataSource extends CatalogRemoteDataSource {
  _FreshRemoteDataSource() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> loadSection(
          CatalogSection section) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{'id': 86, 'title': 'New video'}
      ];
}

class _ControlledThumbnailService extends LocalThumbnailService {
  _ControlledThumbnailService(LocalVideoMetadataRepository metadata)
      : super(
            dio: Dio(),
            localVideoMetadataRepository: metadata,
            logService: _NoopLogService());

  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  final Completer<void> finished = Completer<void>();
  Duration delay = Duration.zero;
  bool failFirst = false;
  final List<List<CatalogItem>> batches = <List<CatalogItem>>[];
  final Completer<void> secondFinished = Completer<void>();

  @override
  Future<void> syncForItems(List<CatalogItem> items) async {
    batches.add(items);
    if (!started.isCompleted) started.complete();
    await release.future;
    await Future<void>.delayed(delay);
    if (!finished.isCompleted) finished.complete();
    if (batches.length == 2) secondFinished.complete();
    if (failFirst && batches.length == 1) {
      throw StateError('Artwork unavailable');
    }
  }
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
