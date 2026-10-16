import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/downloads_dao.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/api_route.dart';
import 'package:localtube_flutter/features/downloads/data/local_downloads_repository.dart';
import 'package:localtube_flutter/features/downloads/data/download_file_validator.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/player/domain/player_models.dart';
import 'package:localtube_flutter/features/player/domain/usecases/play_video_use_case.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

void main() {
  late AppDatabase database;
  late LocalDownloadsRepository localDownloadsRepository;
  late LocalPlaybackRepository localPlaybackRepository;
  late PlaybackSyncRepository playbackSyncRepository;
  late _FakePlaybackPositionRemoteDataSource remoteDataSource;
  late PlayVideoUseCase playVideoUseCase;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();

    localDownloadsRepository = LocalDownloadsRepository(
      DownloadsDao(database),
    );
    localPlaybackRepository = LocalPlaybackRepository(
      PlaybackPositionsDao(database),
    );
    remoteDataSource = _FakePlaybackPositionRemoteDataSource();
    playbackSyncRepository = PlaybackSyncRepository(
      localPlaybackRepository: localPlaybackRepository,
      remoteDataSource: remoteDataSource,
      localSyncOutboxRepository:
          LocalSyncOutboxRepository(SyncOutboxDao(database)),
      logService: _NoopLogService(),
    );
    playVideoUseCase = PlayVideoUseCase(
      localDownloadsRepository: localDownloadsRepository,
      playbackSyncRepository: playbackSyncRepository,
      appConfig: const AppConfig(
        apiBaseUrl: 'https://example.localtube/',
        connectTimeoutMs: 1000,
        receiveTimeoutMs: 1000,
        sendTimeoutMs: 1000,
      ),
    );
  });

  test('prefers local file source and restores saved position', () async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'localtube_player_test',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final File file = File(
      '${tempDir.path}${Platform.pathSeparator}video_100.bin',
    );
    await file.writeAsBytes(const <int>[1, 2, 3, 4]);

    await localDownloadsRepository.save(
      DownloadItem(
        videoId: 100,
        status: DownloadStatus.completed,
        progress: 1,
        remoteUrl: '/files/getFileById?fileId=100',
        title: 'Video 100',
        queuedAt: DateTime.now().toUtc(),
        localPath: file.path,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await localPlaybackRepository.savePosition(
      videoId: 100,
      positionSeconds: 12.5,
    );

    final PlayableVideo playable = await playVideoUseCase.call(
      videoId: 100,
      localOnly: true,
    );

    expect(playable.sourceKind, PlayableSourceKind.localFile);
    expect(playable.sourceUri, file.uri);
    expect(playable.startPosition, const Duration(milliseconds: 12500));
    expect(remoteDataSource.getCallCount, 0);
  });

  test('rejects damaged local MP4 and preserves file and resume position',
      () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('damaged_local_video_');
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/video.mp4');
    const List<int> damagedBytes = <int>[0, 0, 1, 0, 109, 100, 97, 116];
    await file.writeAsBytes(damagedBytes);
    await localDownloadsRepository.save(
      DownloadItem(
        videoId: 100,
        status: DownloadStatus.completed,
        progress: 1,
        remoteUrl: '/api/files/getFileById?fileId=100',
        queuedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        localPath: file.path,
      ),
    );
    await localPlaybackRepository.savePosition(
      videoId: 100,
      positionSeconds: 1129.529,
    );

    for (int attempt = 0; attempt < 2; attempt++) {
      await expectLater(
        playVideoUseCase.call(videoId: 100, localOnly: true),
        throwsA(isA<InvalidDownloadException>()),
      );
    }
    expect((await localDownloadsRepository.findByVideoId(100))!.status,
        DownloadStatus.damaged);
    expect(await file.readAsBytes(), damagedBytes);
    expect(await localPlaybackRepository.getPosition(100), 1129.529);
    expect(remoteDataSource.getCallCount, 0);
  });

  test('falls back to resolved remote url when local file is missing',
      () async {
    await localDownloadsRepository.save(
      DownloadItem(
        videoId: 42,
        status: DownloadStatus.completed,
        progress: 1,
        remoteUrl: '/files/getFileById?fileId=42',
        title: 'Video 42',
        queuedAt: DateTime.now().toUtc(),
        localPath: 'C:/missing/video_42.bin',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await localPlaybackRepository.savePosition(
      videoId: 42,
      positionSeconds: -3,
    );

    final PlayableVideo playable = await playVideoUseCase.call(videoId: 42);

    expect(playable.sourceKind, PlayableSourceKind.remoteUrl);
    expect(
      playable.sourceUri.toString(),
      'https://example.localtube/api/files/getFileById?fileId=42',
    );
    expect(playable.startPosition, Duration.zero);
  });

  test('local-only playback fails without resolving a remote URL', () async {
    await localDownloadsRepository.save(
      DownloadItem(
        videoId: 42,
        status: DownloadStatus.completed,
        progress: 1,
        remoteUrl: '/files/getFileById?fileId=42',
        title: 'Video 42',
        queuedAt: DateTime.now().toUtc(),
        localPath: 'C:/missing/video_42.bin',
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    expect(
      () => playVideoUseCase.call(videoId: 42, localOnly: true),
      throwsA(isA<OfflinePlaybackUnavailableException>()),
    );
  });

  test('builds default remote url when download entry is absent', () async {
    final PlayableVideo playable = await playVideoUseCase.call(videoId: 7);

    expect(playable.sourceKind, PlayableSourceKind.remoteUrl);
    expect(
      playable.sourceUri.toString(),
      'https://example.localtube/api/files/getFileById?fileId=7',
    );
    expect(playable.startPosition, Duration.zero);
  });

  test('uses the LAN API URL for native video playback', () async {
    const AppConfig config = AppConfig(
      apiBaseUrl: 'https://api.example.invalid:9999',
      connectTimeoutMs: 1000,
      receiveTimeoutMs: 1000,
      sendTimeoutMs: 1000,
      enableLocalApiRoute: true,
      localApiHost: '192.0.2.10',
      localApiPort: 55,
    );
    final PlayVideoUseCase routedUseCase = PlayVideoUseCase(
      localDownloadsRepository: localDownloadsRepository,
      playbackSyncRepository: playbackSyncRepository,
      appConfig: config,
      apiRoute: ApiRoute(
        config: config,
        logService: _NoopLogService(),
        localProbe: (_, __, ___) async => true,
      ),
    );

    final PlayableVideo playable = await routedUseCase.call(videoId: 7);

    expect(playable.sourceUri.toString(),
        'http://192.0.2.10:55/api/files/getFileById?fileId=7');
  });

  test('rebases stale absolute backend url to active api base', () async {
    await localDownloadsRepository.save(
      DownloadItem(
        videoId: 73,
        status: DownloadStatus.failed,
        progress: 0,
        remoteUrl: 'http://10.0.2.2:9999/files/getFileById?fileId=73',
        title: 'Video 73',
        queuedAt: DateTime.now().toUtc(),
        localPath: '',
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    final PlayableVideo playable = await playVideoUseCase.call(videoId: 73);

    expect(playable.sourceKind, PlayableSourceKind.remoteUrl);
    expect(
      playable.sourceUri.toString(),
      'https://example.localtube/api/files/getFileById?fileId=73',
    );
  });

  test('uses fresher remote resume position when it wins by updated date',
      () async {
    const int videoId = 17;
    await localPlaybackRepository.savePosition(
      videoId: videoId,
      positionSeconds: 12,
      updatedAt: DateTime.utc(2026, 2, 10, 8, 0, 0),
    );
    remoteDataSource.remoteByVideoId[videoId] = RemotePlaybackPosition(
      positionSeconds: 44.5,
      updatedAt: DateTime.utc(2026, 2, 10, 9, 0, 0),
    );

    final PlayableVideo playable =
        await playVideoUseCase.call(videoId: videoId);

    expect(playable.startPosition, const Duration(milliseconds: 44500));
    final snapshot = await localPlaybackRepository.getSnapshot(videoId);
    expect(snapshot?.positionSeconds, 44.5);
  });
}

class _FakePlaybackPositionRemoteDataSource
    extends PlaybackPositionRemoteDataSource {
  _FakePlaybackPositionRemoteDataSource() : super(Dio());

  final Map<int, RemotePlaybackPosition> remoteByVideoId =
      <int, RemotePlaybackPosition>{};
  int getCallCount = 0;

  @override
  Future<RemotePlaybackPosition?> getPosition(int videoId) async {
    getCallCount += 1;
    return remoteByVideoId[videoId];
  }

  @override
  Future<bool> setPosition({
    required int videoId,
    required double positionSeconds,
    required DateTime updatedAt,
  }) async {
    remoteByVideoId[videoId] = RemotePlaybackPosition(
      positionSeconds: positionSeconds,
      updatedAt: updatedAt.toUtc(),
    );
    return true;
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
