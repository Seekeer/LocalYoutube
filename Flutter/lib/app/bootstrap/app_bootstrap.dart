import '../../core/logging/remote_log_forwarder.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/token_repository.dart';
import '../../core/config/app_config.dart';
import '../../features/downloads/data/background_downloader_download_service.dart';
import '../../features/downloads/domain/download_models.dart';
import '../../core/crash/crash_reporter.dart';
import '../../core/db/app_database.dart';
import '../../core/db/daos/bookmarks_dao.dart';
import '../../core/db/daos/downloads_dao.dart';
import '../../core/db/daos/playback_positions_dao.dart';
import '../../core/db/daos/session_meta_dao.dart';
import '../../core/db/daos/sync_outbox_dao.dart';
import '../../core/db/daos/video_metadata_dao.dart';
import '../../core/db/daos/videos_cache_dao.dart';
import '../../core/logging/log_service.dart';
import '../../core/network/auth_api.dart';
import '../../core/network/auth_interceptor.dart';
import '../../core/network/api_route.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/retry_policy.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../features/auth/data/auth_local_session_repository.dart';
import '../../features/auth/data/auth_remote_data_source.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/offline_availability_probe.dart';
import '../../features/auth/domain/usecases/login_use_case.dart';
import '../../features/auth/domain/usecases/logout_use_case.dart';
import '../../features/auth/domain/usecases/refresh_session_use_case.dart';
import '../../features/auth/domain/usecases/try_auto_login_use_case.dart';
import '../../features/bookmarks/data/bookmarks_remote_data_source.dart';
import '../../features/bookmarks/data/bookmarks_repository.dart';
import '../../features/bookmarks/data/local_bookmarks_repository.dart';
import '../../features/cast/data/cast_device_identity_repository.dart';
import '../../features/cast/data/cast_receiver_playback_binding.dart';
import '../../features/cast/data/cast_settings_repository.dart';
import '../../features/cast/data/device_model_source.dart';
import '../../features/cast/data/playback_sync_cast_progress_writer.dart';
import '../../features/cast/data/sync_hub_cast_gateway.dart';
import '../../features/cast/domain/cast_clock.dart';
import '../../features/cast/domain/cast_device_identity_service.dart';
import '../../features/cast/domain/cast_gateway.dart';
import '../../features/cast/domain/cast_playback_progress_writer.dart';
import '../../features/cast/domain/cast_progress_write_ownership.dart';
import '../../features/cast/domain/cast_registration_service.dart';
import '../../features/cast/presentation/cast_receiver_controller.dart';
import '../../features/catalog/data/catalog_remote_data_source.dart';
import '../../features/catalog/data/catalog_repository.dart';
import '../../features/catalog/data/local_catalog_repository.dart';
import '../../features/catalog/data/local_thumbnail_service.dart';
import '../../features/catalog/data/local_video_metadata_repository.dart';
import '../../features/downloads/data/download_service_factory.dart';
import '../../features/downloads/data/local_downloads_repository.dart';
import '../../features/downloads/data/offline_history_repository.dart';
import '../../features/downloads/domain/download_service.dart';
import '../../features/player/data/local_playback_repository.dart';
import '../../features/player/data/playback_position_remote_data_source.dart';
import '../../features/player/data/playback_sync_repository.dart';
import '../../features/player/data/stream_authorization_header_provider.dart';
import '../../features/player/domain/usecases/extract_timestamps_use_case.dart';
import '../../features/player/domain/usecases/jump_to_nearest_timestamp_use_case.dart';
import '../../features/player/domain/usecases/play_video_use_case.dart';
import '../../features/sync/data/local_sync_outbox_repository.dart';
import '../../features/sync/data/sync_hub_service.dart';
import '../router/app_router.dart';
import '../router/auth_notifier.dart';
import '../sync/app_sync_coordinator.dart';
import 'bootstrap_providers.dart';

class BootstrapResult {
  const BootstrapResult({
    required this.config,
    required this.router,
    required this.overrides,
    required this.crashReporter,
    this.shutdown,
    this.canChangeServer,
  });

  final Future<void> Function()? shutdown;
  final Future<bool> Function()? canChangeServer;
  final AppConfig config;
  final GoRouter router;
  final List<Override> overrides;
  final CrashReporter crashReporter;
}

class AppBootstrap {
  static Future<BootstrapResult> initialize({
    AppEnvironment? environmentOverride,
    AppConfig? configOverride,
    String? databaseFileName,
    LogService? logServiceOverride,
    SecureStorageService? secureStorageOverride,
    AppDatabase? appDatabaseOverride,
    AuthApi? authApiOverride,
    DownloadService? downloadServiceOverride,
    Dio? dioOverride,
  }) async {
    final AppConfig config = configOverride ??
        AppConfig.fromEnvironment(
          environmentOverride: environmentOverride,
        );
    final LogService logService = logServiceOverride ??
        LogService(
          minimumLevel: _mapLogLevel(config.logLevel),
        );
    await logService.initialize();
    final ApiRoute apiRoute = ApiRoute(
      config: config,
      logService: logService,
    );
    final CrashReporter crashReporter = ReleaseCrashReporter(
      config: config,
      logService: logService,
    );
    await crashReporter.initialize();
    final SecureStorageService secureStorage =
        secureStorageOverride ?? SecureStorageService();
    final AppDatabase appDatabase = appDatabaseOverride ??
        AppDatabase(fileName: databaseFileName ?? 'localtube_app.db');
    await appDatabase.initialize();

    final TokenRepository tokenRepository =
        SecureTokenRepository(secureStorage);
    final remoteLogs = RemoteLogForwarder(
      logService: logService,
      tokens: tokenRepository,
      apiBaseUrl: config.apiBaseUrl,
    );
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.checkingSession,
      logService: logService,
    );

    final AuthApi authApi = authApiOverride ??
        AuthApi(
          config: config,
          logService: logService,
          apiRoute: apiRoute,
        );
    final AuthRemoteDataSource authRemoteDataSource =
        AuthRemoteDataSource(authApi);

    final VideosCacheDao videosCacheDao = VideosCacheDao(appDatabase);
    final PlaybackPositionsDao playbackPositionsDao =
        PlaybackPositionsDao(appDatabase);
    final BookmarksDao bookmarksDao = BookmarksDao(appDatabase);
    final DownloadsDao downloadsDao = DownloadsDao(appDatabase);
    final VideoMetadataDao videoMetadataDao = VideoMetadataDao(appDatabase);
    final SyncOutboxDao syncOutboxDao = SyncOutboxDao(appDatabase);
    final SessionMetaDao sessionMetaDao = SessionMetaDao(appDatabase);

    final AuthLocalSessionRepository authLocalSessionRepository =
        AuthLocalSessionRepository(sessionMetaDao);
    final LocalCatalogRepository localCatalogRepository =
        LocalCatalogRepository(videosCacheDao);
    final LocalVideoMetadataRepository localVideoMetadataRepository =
        LocalVideoMetadataRepository(videoMetadataDao);
    final LocalDownloadsRepository localDownloadsRepository =
        LocalDownloadsRepository(downloadsDao);
    final LocalPlaybackRepository localPlaybackRepository =
        LocalPlaybackRepository(playbackPositionsDao);
    final LocalBookmarksRepository localBookmarksRepository =
        LocalBookmarksRepository(bookmarksDao);
    final LocalSyncOutboxRepository localSyncOutboxRepository =
        LocalSyncOutboxRepository(syncOutboxDao);
    final OfflineHistoryRepository offlineHistoryRepository =
        OfflineHistoryRepository(
      database: appDatabase,
      localVideoMetadataRepository: localVideoMetadataRepository,
    );
    final OfflineAvailabilityProbe offlineAvailabilityProbe =
        OfflineAvailabilityProbe(
      sessionMetaDao: sessionMetaDao,
      videosCacheDao: videosCacheDao,
      downloadsDao: downloadsDao,
      playbackPositionsDao: playbackPositionsDao,
      bookmarksDao: bookmarksDao,
    );

    final Dio dio = dioOverride ??
        DioClient.build(
          config: config,
          retryPolicy: const RetryPolicy(),
          authInterceptorFactory: (Dio client) {
            return AuthInterceptor(
              dio: client,
              authApi: authApi,
              tokenRepository: tokenRepository,
              authNotifier: authNotifier,
              logService: logService,
            );
          },
          logService: logService,
          apiRoute: apiRoute,
        );

    final CatalogRemoteDataSource catalogRemoteDataSource =
        CatalogRemoteDataSource(dio);
    final PlaybackPositionRemoteDataSource playbackPositionRemoteDataSource =
        PlaybackPositionRemoteDataSource(dio);
    final BookmarksRemoteDataSource bookmarksRemoteDataSource =
        BookmarksRemoteDataSource(dio);
    final BookmarksRepository bookmarksRepository = BookmarksRepository(
      remoteDataSource: bookmarksRemoteDataSource,
      localBookmarksRepository: localBookmarksRepository,
      localSyncOutboxRepository: localSyncOutboxRepository,
      logService: logService,
    );
    // Watch history follows the device that is actually playing. During a Cast Session that is the
    // Receiver, which writes what it plays on this very path; this phone stops writing for exactly
    // as long as that is true, and the Cast Controller is what says when.
    final CastProgressWriteOwnershipFlag castProgressWriteOwnership =
        CastProgressWriteOwnershipFlag();
    final PlaybackSyncRepository playbackSyncRepository =
        PlaybackSyncRepository(
      localPlaybackRepository: localPlaybackRepository,
      remoteDataSource: playbackPositionRemoteDataSource,
      localSyncOutboxRepository: localSyncOutboxRepository,
      logService: logService,
      isProgressWrittenElsewhere: () =>
          castProgressWriteOwnership.isReceiverOwned,
    );
    final StreamAuthorizationHeaderProvider streamAuthHeaderBuilder =
        StreamAuthorizationHeaderProvider(
      authApi: authApi,
      tokenRepository: tokenRepository,
      logService: logService,
    );

    final DownloadService downloadService = downloadServiceOverride ??
        createDownloadService(
          localDownloadsRepository: localDownloadsRepository,
          appConfig: config,
          tokenRepository: tokenRepository,
          logService: logService,
          apiRoute: apiRoute,
        );
    await downloadService.initialize();
    final LocalThumbnailService localThumbnailService = LocalThumbnailService(
      storageNamespace: config.serverStorageNamespace,
      dio: dio,
      localVideoMetadataRepository: localVideoMetadataRepository,
      logService: logService,
    );

    final AuthRepository authRepository = AuthRepository(
      remoteDataSource: authRemoteDataSource,
      localSessionRepository: authLocalSessionRepository,
      offlineAvailabilityProbe: offlineAvailabilityProbe,
      tokenRepository: tokenRepository,
      authNotifier: authNotifier,
      logService: logService,
    );

    final LoginUseCase loginUseCase = LoginUseCase(authRepository);
    final RefreshSessionUseCase refreshSessionUseCase =
        RefreshSessionUseCase(authRepository);
    final TryAutoLoginUseCase tryAutoLoginUseCase =
        TryAutoLoginUseCase(authRepository);
    final LogoutUseCase logoutUseCase = LogoutUseCase(authRepository);
    final PlayVideoUseCase playVideoUseCase = PlayVideoUseCase(
      localDownloadsRepository: localDownloadsRepository,
      playbackSyncRepository: playbackSyncRepository,
      appConfig: config,
      apiRoute: apiRoute,
    );
    final ExtractTimestampsUseCase extractTimestampsUseCase =
        ExtractTimestampsUseCase();
    final JumpToNearestTimestampUseCase jumpToNearestTimestampUseCase =
        JumpToNearestTimestampUseCase();

    final CatalogRepository catalogRepository = CatalogRepository(
      remoteDataSource: catalogRemoteDataSource,
      localCatalogRepository: localCatalogRepository,
      localVideoMetadataRepository: localVideoMetadataRepository,
      localThumbnailService: localThumbnailService,
      offlineHistoryRepository: offlineHistoryRepository,
      downloadService: downloadService,
      logService: logService,
    );

    // Resolve access from local storage only. Network recovery starts after the
    // first frame in AppSyncLifecycleListener, so it cannot hold the splash.
    await authRepository.restoreLocalSession();

    final GoRouter router = buildAppRouter(
      authNotifier: authNotifier,
    );

    final SyncHubService syncHubService = SyncHubService(
      appConfig: config,
      tokenRepository: tokenRepository,
      authNotifier: authNotifier,
      logService: logService,
      apiRoute: apiRoute,
    );
    await syncHubService.initialize();

    // The Cast Session identity of this installation. Generated once, persisted, and reused across
    // reconnects and app restarts; the SignalR connection id never plays that role.
    final CastDeviceIdentityRepository castDeviceIdentityRepository =
        SecureCastDeviceIdentityRepository(secureStorage);
    final CastDeviceIdentityService castDeviceIdentityService =
        CastDeviceIdentityService(
      identityRepository: castDeviceIdentityRepository,
      deviceModelSource: const PlatformDeviceModelSource(),
    );
    final CastSettingsRepository castSettingsRepository =
        SecureCastSettingsRepository(secureStorage);
    final CastGateway castGateway = SyncHubCastGateway(syncHubService);
    final CastRegistrationService castRegistrationService =
        CastRegistrationService(
      gateway: castGateway,
      identityService: castDeviceIdentityService,
      settingsRepository: castSettingsRepository,
      logService: logService,
    );
    // Registration is what makes this installation visible to the account, so it starts with the
    // app rather than with a screen. It is not awaited: a slow secure-storage read or a device that
    // is offline must not hold up the first frame, and the service registers again on every connect.
    unawaited(castRegistrationService.initialize());

    // The Receiver's half of a Cast Session. A Handoff arrives on the connection rather than from
    // a screen, so a Receiver that only listened while some particular page was open would be
    // unreachable exactly when the viewer wants to cast to it. The displaced video's progress goes
    // through the app's ordinary playback-progress path.
    final CastReceiverPlaybackBinding castReceiverPlaybackBinding =
        CastReceiverPlaybackBinding();
    final CastPlaybackProgressWriter castPlaybackProgressWriter =
        PlaybackSyncCastProgressWriter(playbackSyncRepository);
    final CastReceiverController castReceiverController =
        CastReceiverController(
      gateway: castGateway,
      playback: castReceiverPlaybackBinding,
      progressWriter: castPlaybackProgressWriter,
      // The same stable identity the registration announces. A Receiver needs it to tell a session
      // it ought to be playing from one its own phone is merely the Controller of.
      identityRepository: castDeviceIdentityRepository,
      // The cadence a Receiver reports on runs on the machine's own clock here, and on one a test
      // advances itself there. Nothing else about it differs.
      clock: const SystemCastClock(),
      logService: logService,
    );

    final AppSyncCoordinator appSyncCoordinator = AppSyncCoordinator(
      bookmarksRepository: bookmarksRepository,
      playbackSyncRepository: playbackSyncRepository,
      logService: logService,
    );

    logService.info(
      'Bootstrap initialized (${config.environment.key}, log=${config.logLevel.key}, networkLogs=${config.enableNetworkLogs})',
    );

    return BootstrapResult(
      config: config,
      router: router,
      crashReporter: crashReporter,
      canChangeServer: () async {
        final items = await downloadService.watchDownloads().first;
        return !items.any((item) =>
            item.status.isActive || item.status == DownloadStatus.paused);
      },
      shutdown: () async {
        await remoteLogs.dispose();
        await castRegistrationService.dispose();
        await syncHubService.dispose();
        if (downloadService is BackgroundDownloaderDownloadService) {
          await downloadService.dispose();
        }
        dio.close(force: true);
        router.dispose();
        await appDatabase.close();
      },
      overrides: <Override>[
        appConfigProvider.overrideWithValue(config),
        apiRouteProvider.overrideWithValue(apiRoute),
        logServiceProvider.overrideWithValue(logService),
        crashReporterProvider.overrideWithValue(crashReporter),
        secureStorageServiceProvider.overrideWithValue(secureStorage),
        appDatabaseProvider.overrideWithValue(appDatabase),
        tokenRepositoryProvider.overrideWithValue(tokenRepository),
        authApiProvider.overrideWithValue(authApi),
        authRemoteDataSourceProvider.overrideWithValue(authRemoteDataSource),
        authLocalSessionRepositoryProvider
            .overrideWithValue(authLocalSessionRepository),
        dioProvider.overrideWithValue(dio),
        authNotifierProvider.overrideWith((Ref ref) => authNotifier),
        authRepositoryProvider.overrideWithValue(authRepository),
        downloadServiceProvider.overrideWithValue(downloadService),
        loginUseCaseProvider.overrideWithValue(loginUseCase),
        refreshSessionUseCaseProvider.overrideWithValue(refreshSessionUseCase),
        tryAutoLoginUseCaseProvider.overrideWithValue(tryAutoLoginUseCase),
        logoutUseCaseProvider.overrideWithValue(logoutUseCase),
        playVideoUseCaseProvider.overrideWithValue(playVideoUseCase),
        extractTimestampsUseCaseProvider
            .overrideWithValue(extractTimestampsUseCase),
        jumpToNearestTimestampUseCaseProvider
            .overrideWithValue(jumpToNearestTimestampUseCase),
        videosCacheDaoProvider.overrideWithValue(videosCacheDao),
        playbackPositionsDaoProvider.overrideWithValue(playbackPositionsDao),
        bookmarksDaoProvider.overrideWithValue(bookmarksDao),
        downloadsDaoProvider.overrideWithValue(downloadsDao),
        videoMetadataDaoProvider.overrideWithValue(videoMetadataDao),
        syncOutboxDaoProvider.overrideWithValue(syncOutboxDao),
        sessionMetaDaoProvider.overrideWithValue(sessionMetaDao),
        localCatalogRepositoryProvider
            .overrideWithValue(localCatalogRepository),
        localVideoMetadataRepositoryProvider
            .overrideWithValue(localVideoMetadataRepository),
        localThumbnailServiceProvider.overrideWithValue(localThumbnailService),
        localDownloadsRepositoryProvider.overrideWithValue(
          localDownloadsRepository,
        ),
        offlineHistoryRepositoryProvider
            .overrideWithValue(offlineHistoryRepository),
        localPlaybackRepositoryProvider.overrideWithValue(
          localPlaybackRepository,
        ),
        playbackPositionRemoteDataSourceProvider
            .overrideWithValue(playbackPositionRemoteDataSource),
        playbackSyncRepositoryProvider.overrideWithValue(
          playbackSyncRepository,
        ),
        streamAuthHeaderProvider.overrideWithValue(streamAuthHeaderBuilder),
        localBookmarksRepositoryProvider
            .overrideWithValue(localBookmarksRepository),
        bookmarksRemoteDataSourceProvider
            .overrideWithValue(bookmarksRemoteDataSource),
        bookmarksRepositoryProvider.overrideWithValue(bookmarksRepository),
        localSyncOutboxRepositoryProvider
            .overrideWithValue(localSyncOutboxRepository),
        syncHubServiceProvider.overrideWithValue(syncHubService),
        castDeviceIdentityRepositoryProvider
            .overrideWithValue(castDeviceIdentityRepository),
        castDeviceIdentityServiceProvider
            .overrideWithValue(castDeviceIdentityService),
        castSettingsRepositoryProvider
            .overrideWithValue(castSettingsRepository),
        castGatewayProvider.overrideWithValue(castGateway),
        castRegistrationServiceProvider
            .overrideWithValue(castRegistrationService),
        castReceiverPlaybackBindingProvider
            .overrideWithValue(castReceiverPlaybackBinding),
        castPlaybackProgressWriterProvider
            .overrideWithValue(castPlaybackProgressWriter),
        castProgressWriteOwnershipProvider
            .overrideWithValue(castProgressWriteOwnership),
        castReceiverControllerProvider
            .overrideWith((Ref ref) => castReceiverController),
        appSyncCoordinatorProvider.overrideWithValue(appSyncCoordinator),
        catalogRemoteDataSourceProvider
            .overrideWithValue(catalogRemoteDataSource),
        catalogRepositoryProvider.overrideWithValue(catalogRepository),
      ],
    );
  }

  static LogLevel _mapLogLevel(AppLogLevel level) {
    switch (level) {
      case AppLogLevel.debug:
        return LogLevel.debug;
      case AppLogLevel.info:
        return LogLevel.info;
      case AppLogLevel.warning:
        return LogLevel.warning;
      case AppLogLevel.error:
        return LogLevel.error;
    }
  }
}
