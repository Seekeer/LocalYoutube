import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/bookmarks_dao.dart';
import 'package:localtube_flutter/core/db/daos/downloads_dao.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/session_meta_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/auth_api.dart';
import 'package:localtube_flutter/features/auth/data/auth_attempt_result.dart';
import 'package:localtube_flutter/features/auth/data/auth_local_session_repository.dart';
import 'package:localtube_flutter/features/auth/data/auth_remote_data_source.dart';
import 'package:localtube_flutter/features/auth/data/auth_repository.dart';
import 'package:localtube_flutter/features/auth/data/offline_availability_probe.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_remote_data_source.dart';
import 'package:localtube_flutter/features/catalog/data/catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_catalog_repository.dart';
import 'package:localtube_flutter/features/catalog/data/local_thumbnail_service.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/catalog/domain/catalog_models.dart';
import 'package:localtube_flutter/features/downloads/data/local_downloads_repository.dart';
import 'package:localtube_flutter/features/downloads/data/offline_history_repository.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:localtube_flutter/features/downloads/domain/download_service.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/player/domain/player_models.dart';
import 'package:localtube_flutter/features/player/domain/usecases/play_video_use_case.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'android happy path: login -> catalog -> play -> download -> offline play -> sync',
    (WidgetTester tester) async {
      final AppDatabase database =
          AppDatabase(executor: NativeDatabase.memory());
      await database.initialize();
      final AuthNotifier authNotifier = AuthNotifier();

      final _InMemoryTokenRepository tokenRepository =
          _InMemoryTokenRepository();
      final _FakeAuthRemoteDataSource authRemoteDataSource =
          _FakeAuthRemoteDataSource();
      final AuthLocalSessionRepository localSessionRepository =
          AuthLocalSessionRepository(SessionMetaDao(database));
      final AuthRepository authRepository = AuthRepository(
        remoteDataSource: authRemoteDataSource,
        localSessionRepository: localSessionRepository,
        offlineAvailabilityProbe: _NeverOfflineAvailabilityProbe(),
        tokenRepository: tokenRepository,
        authNotifier: authNotifier,
        logService: _NoopLogService(),
      );

      final AuthAttemptResult loginResult = await authRepository.login(
        userName: 'integration_user',
        password: 'integration_password',
      );
      expect(loginResult.isSuccessOnline, isTrue);
      expect(authNotifier.accessMode, AppAccessMode.onlineAuthenticated);
      expect(await tokenRepository.hasAccessToken(), isTrue);

      final LocalCatalogRepository localCatalogRepository =
          LocalCatalogRepository(VideosCacheDao(database));
      final LocalDownloadsRepository localDownloadsRepository =
          LocalDownloadsRepository(DownloadsDao(database));
      final LocalVideoMetadataRepository localVideoMetadataRepository =
          LocalVideoMetadataRepository(VideoMetadataDao(database));
      final LocalPlaybackRepository localPlaybackRepository =
          LocalPlaybackRepository(PlaybackPositionsDao(database));
      final LocalSyncOutboxRepository localSyncOutboxRepository =
          LocalSyncOutboxRepository(SyncOutboxDao(database));
      final _FakePlaybackPositionRemoteDataSource playbackRemoteDataSource =
          _FakePlaybackPositionRemoteDataSource();

      final CatalogRepository catalogRepository = CatalogRepository(
        remoteDataSource: _FakeCatalogRemoteDataSource(),
        localCatalogRepository: localCatalogRepository,
        localVideoMetadataRepository: localVideoMetadataRepository,
        localThumbnailService: LocalThumbnailService(
          dio: Dio(),
          localVideoMetadataRepository: localVideoMetadataRepository,
          logService: _NoopLogService(),
        ),
        offlineHistoryRepository: OfflineHistoryRepository(
          database: database,
          localVideoMetadataRepository: localVideoMetadataRepository,
        ),
        downloadService: _NoopDownloadService(),
        logService: _NoopLogService(),
      );
      final PlaybackSyncRepository playbackSyncRepository =
          PlaybackSyncRepository(
        localPlaybackRepository: localPlaybackRepository,
        remoteDataSource: playbackRemoteDataSource,
        localSyncOutboxRepository: localSyncOutboxRepository,
        logService: _NoopLogService(),
      );
      final PlayVideoUseCase playVideoUseCase = PlayVideoUseCase(
        localDownloadsRepository: localDownloadsRepository,
        playbackSyncRepository: playbackSyncRepository,
        appConfig: const AppConfig(
          apiBaseUrl: 'https://example.localtube',
          connectTimeoutMs: 1000,
          receiveTimeoutMs: 1000,
          sendTimeoutMs: 1000,
        ),
      );

      final (List<CatalogItem> catalogItems, Failure? catalogFailure) =
          await catalogRepository.refreshSection(CatalogSection.latest);
      expect(catalogFailure, isNull);
      expect(catalogItems, isNotEmpty);
      expect(catalogItems.first.id, 501);

      final PlayableVideo onlinePlayable = await playVideoUseCase.call(
        videoId: 501,
      );
      expect(onlinePlayable.sourceKind, PlayableSourceKind.remoteUrl);
      expect(
        onlinePlayable.sourceUri.toString(),
        'https://example.localtube/files/getFileById?fileId=501',
      );

      final Directory tempDir =
          await Directory.systemTemp.createTemp('localtube_step16_integration');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final File localFile = File(
        '${tempDir.path}${Platform.pathSeparator}video_501.bin',
      );
      await localFile.writeAsBytes(const <int>[1, 2, 3, 4]);

      await localDownloadsRepository.save(
        DownloadItem(
          videoId: 501,
          status: DownloadStatus.completed,
          progress: 1,
          remoteUrl: '/files/getFileById?fileId=501',
          title: 'Integration Video',
          queuedAt: DateTime.now().toUtc(),
          localPath: localFile.path,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await localPlaybackRepository.savePosition(
        videoId: 501,
        positionSeconds: 31.5,
      );

      playbackRemoteDataSource.throwOnGet = true;
      final PlayableVideo offlinePlayable = await playVideoUseCase.call(
        videoId: 501,
      );
      expect(offlinePlayable.sourceKind, PlayableSourceKind.localFile);
      expect(offlinePlayable.sourceUri, localFile.uri);
      expect(
          offlinePlayable.startPosition, const Duration(milliseconds: 31500));

      playbackRemoteDataSource.throwOnSet = true;
      await playbackSyncRepository.savePosition(
        videoId: 501,
        positionSeconds: 45,
      );
      final List<Map<String, Object?>> pendingBeforeSync =
          await localSyncOutboxRepository.listPending(
        limit: 100,
        operationTypes: const <String>['playback_position_set'],
      );
      expect(pendingBeforeSync, isNotEmpty);

      playbackRemoteDataSource.throwOnSet = false;
      playbackRemoteDataSource.throwOnGet = false;
      await playbackSyncRepository.processOutbox();

      final List<Map<String, Object?>> pendingAfterSync =
          await localSyncOutboxRepository.listPending(
        limit: 100,
        operationTypes: const <String>['playback_position_set'],
      );
      expect(pendingAfterSync, isEmpty);

      final RemotePlaybackPosition? remoteSnapshot =
          await playbackRemoteDataSource.getPosition(501);
      expect(remoteSnapshot, isNotNull);
      expect(remoteSnapshot!.positionSeconds, greaterThanOrEqualTo(45));
    },
  );
}

class _InMemoryTokenRepository implements TokenRepository {
  SessionTokens? _value;

  @override
  Future<void> clearSession() async {
    _value = null;
  }

  @override
  Future<void> clearAllAuthState() async {
    _value = null;
  }

  @override
  Future<bool> hasAccessToken() async {
    final SessionTokens? value = _value;
    return value != null && value.accessToken.isNotEmpty;
  }

  @override
  Future<SessionTokens?> read() async => _value;

  @override
  Future<void> save(SessionTokens tokens) async {
    _value = tokens;
  }
}

class _FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  _FakeAuthRemoteDataSource()
      : super(
          AuthApi(
            config: const AppConfig(
              apiBaseUrl: 'https://example.localtube',
              connectTimeoutMs: 500,
              receiveTimeoutMs: 500,
              sendTimeoutMs: 500,
            ),
          ),
        );

  @override
  Future<SessionTokens?> login({
    required String userName,
    required String password,
  }) async {
    return SessionTokens(
      userName: userName,
      accessToken: 'access_$userName',
      refreshToken: 'refresh_$userName',
    );
  }

  @override
  Future<SessionTokens?> refresh({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) async {
    return SessionTokens(
      userName: userName,
      accessToken: 'access_refreshed_$userName',
      refreshToken: 'refresh_refreshed_$userName',
    );
  }
}

class _FakeCatalogRemoteDataSource extends CatalogRemoteDataSource {
  _FakeCatalogRemoteDataSource() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> loadSection(CatalogSection section) async {
    if (section != CatalogSection.latest) {
      return <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 501,
        'title': 'Integration Video',
        'description': 'happy path sample',
      },
    ];
  }
}

class _FakePlaybackPositionRemoteDataSource
    extends PlaybackPositionRemoteDataSource {
  _FakePlaybackPositionRemoteDataSource() : super(Dio());

  bool throwOnSet = false;
  bool throwOnGet = false;
  final Map<int, RemotePlaybackPosition> _remote =
      <int, RemotePlaybackPosition>{};

  @override
  Future<RemotePlaybackPosition?> getPosition(int videoId) async {
    if (throwOnGet) {
      throw DioException(
        requestOptions: RequestOptions(path: '/files/getPositionMaui/$videoId'),
      );
    }
    return _remote[videoId];
  }

  @override
  Future<bool> setPosition({
    required int videoId,
    required double positionSeconds,
    required DateTime updatedAt,
  }) async {
    if (throwOnSet) {
      throw DioException(
        requestOptions: RequestOptions(path: '/files/setPositionMaui/$videoId'),
      );
    }
    _remote[videoId] = RemotePlaybackPosition(
      positionSeconds: positionSeconds,
      updatedAt: updatedAt.toUtc(),
    );
    return true;
  }
}

class _NoopDownloadService implements DownloadService {
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
    return const Stream<List<DownloadItem>>.empty();
  }
}

class _NeverOfflineAvailabilityProbe extends OfflineAvailabilityProbe {
  _NeverOfflineAvailabilityProbe()
      : super(
          sessionMetaDao: SessionMetaDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          videosCacheDao: VideosCacheDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          downloadsDao: DownloadsDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          playbackPositionsDao: PlaybackPositionsDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          bookmarksDao: BookmarksDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
        );

  @override
  Future<bool> canEnterOfflineFallback() async => false;
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
