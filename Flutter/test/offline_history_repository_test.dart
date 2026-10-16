import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/downloads_dao.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/downloads/data/offline_history_repository.dart';

void main() {
  late AppDatabase database;
  late LocalVideoMetadataRepository metadataRepository;
  late DownloadsDao downloadsDao;
  late PlaybackPositionsDao playbackPositionsDao;
  late OfflineHistoryRepository repository;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();
    metadataRepository =
        LocalVideoMetadataRepository(VideoMetadataDao(database));
    downloadsDao = DownloadsDao(database);
    playbackPositionsDao = PlaybackPositionsDao(database);
    repository = OfflineHistoryRepository(
      database: database,
      localVideoMetadataRepository: metadataRepository,
    );
  });

  test('listHistory sorts by playback updated_at descending', () async {
    await metadataRepository.upsertRouteMetadata(
      videoId: 1,
      title: 'First',
      description: 'One',
    );
    await metadataRepository.upsertRouteMetadata(
      videoId: 2,
      title: 'Second',
      description: 'Two',
    );
    await playbackPositionsDao.savePosition(
      videoId: 1,
      positionSeconds: 10,
      updatedAt: DateTime.utc(2026, 3, 16, 10),
    );
    await playbackPositionsDao.savePosition(
      videoId: 2,
      positionSeconds: 20,
      updatedAt: DateTime.utc(2026, 3, 16, 11),
    );

    final List<OfflineHistoryItem> items = await repository.listHistory();

    expect(items.map((OfflineHistoryItem item) => item.videoId).toList(),
        <int>[2, 1]);
  });

  test('findLatestPlayable skips completed items with missing file', () async {
    final Directory tempDir =
        await Directory.systemTemp.createTemp('offline_history_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final File availableFile = File(
      '${tempDir.path}${Platform.pathSeparator}video_2.bin',
    );
    await availableFile.writeAsBytes(const <int>[1, 2, 3]);

    await metadataRepository.upsertRouteMetadata(
      videoId: 1,
      title: 'Missing',
      description: 'No file',
    );
    await metadataRepository.upsertRouteMetadata(
      videoId: 2,
      title: 'Playable',
      description: 'Has file',
    );

    await downloadsDao.upsertDownload(
      videoId: 1,
      status: 'completed',
      progress: 1,
      remoteUrl: '/api/files/getFileById?fileId=1',
      localPath: '${tempDir.path}${Platform.pathSeparator}missing.bin',
      queuedAt: DateTime.utc(2026, 3, 16, 10),
    );
    await downloadsDao.upsertDownload(
      videoId: 2,
      status: 'completed',
      progress: 1,
      remoteUrl: '/api/files/getFileById?fileId=2',
      localPath: availableFile.path,
      queuedAt: DateTime.utc(2026, 3, 16, 9),
    );
    await playbackPositionsDao.savePosition(
      videoId: 1,
      positionSeconds: 120,
      updatedAt: DateTime.utc(2026, 3, 16, 12),
    );
    await playbackPositionsDao.savePosition(
      videoId: 2,
      positionSeconds: 30,
      updatedAt: DateTime.utc(2026, 3, 16, 11),
    );

    final OfflineHistoryItem? latestPlayable =
        await repository.findLatestPlayable();

    expect(latestPlayable, isNotNull);
    expect(latestPlayable!.videoId, 2);
    expect(latestPlayable.isPlayableOffline, isTrue);
  });
}
