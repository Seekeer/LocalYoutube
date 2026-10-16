import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/token_repository.dart';
import '../../core/config/app_config.dart';
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
import '../../core/storage/secure_storage_service.dart';
import '../../features/auth/data/auth_local_session_repository.dart';
import '../../features/auth/data/auth_remote_data_source.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/usecases/login_use_case.dart';
import '../../features/auth/domain/usecases/logout_use_case.dart';
import '../../features/auth/domain/usecases/refresh_session_use_case.dart';
import '../../features/auth/domain/usecases/try_auto_login_use_case.dart';
import '../../features/bookmarks/data/bookmarks_remote_data_source.dart';
import '../../features/bookmarks/data/bookmarks_repository.dart';
import '../../features/bookmarks/data/local_bookmarks_repository.dart';
import '../../features/cast/data/cast_device_identity_repository.dart';
import '../../features/cast/data/cast_settings_repository.dart';
import '../../features/cast/domain/cast_device_identity_service.dart';
import '../../features/cast/domain/cast_gateway.dart';
import '../../features/cast/domain/cast_playback_progress_writer.dart';
import '../../features/cast/domain/cast_progress_write_ownership.dart';
import '../../features/cast/domain/cast_registration_service.dart';
import '../../features/catalog/data/catalog_remote_data_source.dart';
import '../../features/catalog/data/catalog_repository.dart';
import '../../features/catalog/data/local_catalog_repository.dart';
import '../../features/catalog/data/local_thumbnail_service.dart';
import '../../features/catalog/data/local_video_metadata_repository.dart';
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
import '../router/auth_notifier.dart';
import '../sync/app_sync_coordinator.dart';
import '../../core/network/api_route.dart';

final Provider<AppConfig> appConfigProvider =
    Provider<AppConfig>((Ref ref) => throw UnimplementedError());

final Provider<ApiRoute> apiRouteProvider =
    Provider<ApiRoute>((Ref ref) => throw UnimplementedError());

final Provider<LogService> logServiceProvider =
    Provider<LogService>((Ref ref) => throw UnimplementedError());

final Provider<CrashReporter> crashReporterProvider =
    Provider<CrashReporter>((Ref ref) => throw UnimplementedError());

final Provider<SecureStorageService> secureStorageServiceProvider =
    Provider<SecureStorageService>((Ref ref) => throw UnimplementedError());

final Provider<AppDatabase> appDatabaseProvider =
    Provider<AppDatabase>((Ref ref) => throw UnimplementedError());

final Provider<TokenRepository> tokenRepositoryProvider =
    Provider<TokenRepository>((Ref ref) => throw UnimplementedError());

final Provider<AuthApi> authApiProvider =
    Provider<AuthApi>((Ref ref) => throw UnimplementedError());

final Provider<Dio> dioProvider =
    Provider<Dio>((Ref ref) => throw UnimplementedError());

final ChangeNotifierProvider<AuthNotifier> authNotifierProvider =
    ChangeNotifierProvider<AuthNotifier>(
        (Ref ref) => throw UnimplementedError());

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => throw UnimplementedError());

final Provider<CatalogRepository> catalogRepositoryProvider =
    Provider<CatalogRepository>((Ref ref) => throw UnimplementedError());

final Provider<DownloadService> downloadServiceProvider =
    Provider<DownloadService>((Ref ref) => throw UnimplementedError());

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>((Ref ref) => throw UnimplementedError());

final Provider<AuthLocalSessionRepository> authLocalSessionRepositoryProvider =
    Provider<AuthLocalSessionRepository>(
        (Ref ref) => throw UnimplementedError());

final Provider<CatalogRemoteDataSource> catalogRemoteDataSourceProvider =
    Provider<CatalogRemoteDataSource>((Ref ref) => throw UnimplementedError());

final Provider<LocalCatalogRepository> localCatalogRepositoryProvider =
    Provider<LocalCatalogRepository>((Ref ref) => throw UnimplementedError());

final Provider<LocalVideoMetadataRepository>
    localVideoMetadataRepositoryProvider =
    Provider<LocalVideoMetadataRepository>(
        (Ref ref) => throw UnimplementedError());

final Provider<LocalThumbnailService> localThumbnailServiceProvider =
    Provider<LocalThumbnailService>((Ref ref) => throw UnimplementedError());

final Provider<LocalDownloadsRepository> localDownloadsRepositoryProvider =
    Provider<LocalDownloadsRepository>((Ref ref) => throw UnimplementedError());

final Provider<OfflineHistoryRepository> offlineHistoryRepositoryProvider =
    Provider<OfflineHistoryRepository>((Ref ref) => throw UnimplementedError());

final Provider<LocalPlaybackRepository> localPlaybackRepositoryProvider =
    Provider<LocalPlaybackRepository>((Ref ref) => throw UnimplementedError());

final Provider<PlaybackPositionRemoteDataSource>
    playbackPositionRemoteDataSourceProvider =
    Provider<PlaybackPositionRemoteDataSource>(
        (Ref ref) => throw UnimplementedError());

final Provider<PlaybackSyncRepository> playbackSyncRepositoryProvider =
    Provider<PlaybackSyncRepository>((Ref ref) => throw UnimplementedError());

final Provider<StreamAuthorizationHeaderProvider> streamAuthHeaderProvider =
    Provider<StreamAuthorizationHeaderProvider>(
        (Ref ref) => throw UnimplementedError());

final Provider<LocalBookmarksRepository> localBookmarksRepositoryProvider =
    Provider<LocalBookmarksRepository>((Ref ref) => throw UnimplementedError());

final Provider<BookmarksRemoteDataSource> bookmarksRemoteDataSourceProvider =
    Provider<BookmarksRemoteDataSource>(
        (Ref ref) => throw UnimplementedError());

final Provider<BookmarksRepository> bookmarksRepositoryProvider =
    Provider<BookmarksRepository>((Ref ref) => throw UnimplementedError());

final Provider<LocalSyncOutboxRepository> localSyncOutboxRepositoryProvider =
    Provider<LocalSyncOutboxRepository>(
        (Ref ref) => throw UnimplementedError());

final Provider<SyncHubService> syncHubServiceProvider =
    Provider<SyncHubService>((Ref ref) => throw UnimplementedError());

final Provider<CastDeviceIdentityRepository> castDeviceIdentityRepositoryProvider =
    Provider<CastDeviceIdentityRepository>(
        (Ref ref) => throw UnimplementedError());

final Provider<CastDeviceIdentityService> castDeviceIdentityServiceProvider =
    Provider<CastDeviceIdentityService>(
        (Ref ref) => throw UnimplementedError());

final Provider<CastSettingsRepository> castSettingsRepositoryProvider =
    Provider<CastSettingsRepository>((Ref ref) => throw UnimplementedError());

final Provider<CastGateway> castGatewayProvider =
    Provider<CastGateway>((Ref ref) => throw UnimplementedError());

final Provider<CastRegistrationService> castRegistrationServiceProvider =
    Provider<CastRegistrationService>((Ref ref) => throw UnimplementedError());

/// How a Receiver keeps the progress of a video a cast is about to replace. Supplied by the
/// composition root because it is the app's ordinary playback-progress path, not a cast-specific
/// one.
final Provider<CastPlaybackProgressWriter> castPlaybackProgressWriterProvider =
    Provider<CastPlaybackProgressWriter>(
        (Ref ref) => throw UnimplementedError());

/// Which device's playback progress this installation writes. Supplied by the composition root
/// because the playback-progress path that reads it is built there too, and both have to be looking
/// at the same answer.
final Provider<CastProgressWriteOwnership> castProgressWriteOwnershipProvider =
    Provider<CastProgressWriteOwnership>(
        (Ref ref) => throw UnimplementedError());

final Provider<AppSyncCoordinator> appSyncCoordinatorProvider =
    Provider<AppSyncCoordinator>((Ref ref) => throw UnimplementedError());

final Provider<VideosCacheDao> videosCacheDaoProvider =
    Provider<VideosCacheDao>((Ref ref) => throw UnimplementedError());

final Provider<PlaybackPositionsDao> playbackPositionsDaoProvider =
    Provider<PlaybackPositionsDao>((Ref ref) => throw UnimplementedError());

final Provider<BookmarksDao> bookmarksDaoProvider =
    Provider<BookmarksDao>((Ref ref) => throw UnimplementedError());

final Provider<DownloadsDao> downloadsDaoProvider =
    Provider<DownloadsDao>((Ref ref) => throw UnimplementedError());

final Provider<VideoMetadataDao> videoMetadataDaoProvider =
    Provider<VideoMetadataDao>((Ref ref) => throw UnimplementedError());

final Provider<SyncOutboxDao> syncOutboxDaoProvider =
    Provider<SyncOutboxDao>((Ref ref) => throw UnimplementedError());

final Provider<SessionMetaDao> sessionMetaDaoProvider =
    Provider<SessionMetaDao>((Ref ref) => throw UnimplementedError());

final Provider<LoginUseCase> loginUseCaseProvider =
    Provider<LoginUseCase>((Ref ref) => throw UnimplementedError());

final Provider<RefreshSessionUseCase> refreshSessionUseCaseProvider =
    Provider<RefreshSessionUseCase>((Ref ref) => throw UnimplementedError());

final Provider<TryAutoLoginUseCase> tryAutoLoginUseCaseProvider =
    Provider<TryAutoLoginUseCase>((Ref ref) => throw UnimplementedError());

final Provider<LogoutUseCase> logoutUseCaseProvider =
    Provider<LogoutUseCase>((Ref ref) => throw UnimplementedError());

final Provider<PlayVideoUseCase> playVideoUseCaseProvider =
    Provider<PlayVideoUseCase>((Ref ref) => throw UnimplementedError());

final Provider<ExtractTimestampsUseCase> extractTimestampsUseCaseProvider =
    Provider<ExtractTimestampsUseCase>((Ref ref) => throw UnimplementedError());

final Provider<JumpToNearestTimestampUseCase>
    jumpToNearestTimestampUseCaseProvider =
    Provider<JumpToNearestTimestampUseCase>(
  (Ref ref) => throw UnimplementedError(),
);
