import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/logging/log_service.dart';
import '../../downloads/data/offline_history_repository.dart';
import '../../downloads/domain/download_service.dart';
import '../domain/catalog_models.dart';
import 'catalog_remote_data_source.dart';
import 'local_catalog_repository.dart';
import 'local_thumbnail_service.dart';
import 'local_video_metadata_repository.dart';

class CatalogRepository {
  CatalogRepository({
    required CatalogRemoteDataSource remoteDataSource,
    required LocalCatalogRepository localCatalogRepository,
    required LocalVideoMetadataRepository localVideoMetadataRepository,
    required LocalThumbnailService localThumbnailService,
    required OfflineHistoryRepository offlineHistoryRepository,
    required DownloadService downloadService,
    required LogService logService,
  })  : _remoteDataSource = remoteDataSource,
        _localCatalogRepository = localCatalogRepository,
        _localVideoMetadataRepository = localVideoMetadataRepository,
        _localThumbnailService = localThumbnailService,
        _offlineHistoryRepository = offlineHistoryRepository,
        _downloadService = downloadService,
        _logService = logService;

  final CatalogRemoteDataSource _remoteDataSource;
  final LocalCatalogRepository _localCatalogRepository;
  final LocalVideoMetadataRepository _localVideoMetadataRepository;
  final LocalThumbnailService _localThumbnailService;
  final OfflineHistoryRepository _offlineHistoryRepository;
  final DownloadService _downloadService;
  final LogService _logService;

  Future<List<CatalogItem>> readCachedSection(CatalogSection section) async {
    if (section == CatalogSection.history) {
      return _readOfflineHistorySection();
    }
    final List<Map<String, dynamic>> rawItems =
        await _localCatalogRepository.readSection(section.key);
    return rawItems
        .map(CatalogItem.fromJson)
        .where((CatalogItem item) => item.id > 0)
        .toList(growable: false);
  }

  Future<(List<CatalogItem>, Failure?)> refreshSection(
    CatalogSection section,
  ) async {
    try {
      final List<Map<String, dynamic>> rawItems =
          await _remoteDataSource.loadSection(section);

      await _localCatalogRepository.saveSection(section.key, rawItems);

      final List<CatalogItem> items = rawItems
          .map(CatalogItem.fromJson)
          .where((CatalogItem item) => item.id > 0)
          .toList(growable: false);
      await _localVideoMetadataRepository.upsertCatalogItems(items);
      await _localThumbnailService.syncForItems(items);
      return (items, null);
    } catch (error, stackTrace) {
      _logService.error(
        'refreshSection(${section.key}) failed',
        error,
        stackTrace,
      );
      return (<CatalogItem>[], mapToFailure(error));
    }
  }

  Future<(List<PlaylistSummary>, Failure?)> loadPlaylists() async {
    final List<CatalogItem> cachedItems = await readCachedSection(
      CatalogSection.playlists,
    );
    final List<PlaylistSummary> cachedPlaylists = cachedItems
        .map(PlaylistSummary.fromCatalogItem)
        .toList(growable: false);

    try {
      final List<PlaylistSummary> remotePlaylists =
          await _remoteDataSource.loadPlaylists();
      await _localCatalogRepository.saveSection(
        CatalogSection.playlists.key,
        remotePlaylists
            .map((PlaylistSummary playlist) => playlist.toJson())
            .toList(growable: false),
      );
      return (remotePlaylists, null);
    } catch (error, stackTrace) {
      _logService.error('loadPlaylists failed', error, stackTrace);
      if (cachedPlaylists.isNotEmpty) {
        return (cachedPlaylists, null);
      }
      return (<PlaylistSummary>[], mapToFailure(error));
    }
  }

  Future<(PlaylistSummary?, Failure?)> createPlaylist(String name) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return (null, const ValidationFailure('Playlist name is required'));
    }
    if (trimmedName.length > 64) {
      return (
        null,
        const ValidationFailure('Playlist name must be <= 64 chars'),
      );
    }

    try {
      final int playlistId = await _remoteDataSource.createPlaylist(
        trimmedName,
      );
      if (playlistId <= 0) {
        return (
          null,
          const UnknownFailure('Invalid playlist id returned by server'),
        );
      }

      final PlaylistSummary created = PlaylistSummary(
        id: playlistId,
        name: trimmedName,
      );

      await _appendCreatedPlaylistToCache(created);
      return (created, null);
    } catch (error, stackTrace) {
      _logService.error('createPlaylist failed', error, stackTrace);
      return (null, mapToFailure(error));
    }
  }

  Future<Failure?> queueDownload(CatalogItem item) async {
    try {
      await _localVideoMetadataRepository.upsertCatalogItem(item);
      await _offlineHistoryRepository.ensureMetadataForDownload(
        videoId: item.id,
        title: item.title,
      );
      await _downloadService.enqueue(
        videoId: item.id,
        remoteUrl: item.remoteUrl,
        title: item.title,
      );
      return null;
    } catch (error, stackTrace) {
      _logService.error('queueDownload failed', error, stackTrace);
      return mapToFailure(error);
    }
  }

  Future<Failure?> deleteLocal(int videoId) async {
    try {
      await _downloadService.deleteLocal(videoId);
      return null;
    } catch (error, stackTrace) {
      _logService.error('deleteLocal failed', error, stackTrace);
      return mapToFailure(error);
    }
  }

  Future<Failure?> deleteServer(int videoId) async {
    try {
      await _remoteDataSource.deleteServerVideo(videoId);
      return null;
    } catch (error, stackTrace) {
      _logService.error('deleteServer failed', error, stackTrace);
      return mapToFailure(error);
    }
  }

  Future<Failure?> addToPlaylist({
    required int videoId,
    required int playlistId,
  }) async {
    try {
      await _remoteDataSource.addToPlaylist(
        fileId: videoId,
        playlistId: playlistId,
      );
      return null;
    } catch (error, stackTrace) {
      _logService.error('addToPlaylist failed', error, stackTrace);
      return mapToFailure(error);
    }
  }

  Future<void> persistSectionSnapshot(
    CatalogSection section,
    List<CatalogItem> items,
  ) async {
    try {
      await _localCatalogRepository.saveSection(
        section.key,
        items.map((CatalogItem item) => item.toJson()).toList(growable: false),
      );
    } catch (error, stackTrace) {
      _logService.error(
        'persistSectionSnapshot(${section.key}) failed',
        error,
        stackTrace,
      );
    }
  }

  Future<int> queueTopDownloads(
    List<CatalogItem> items, {
    required int topN,
  }) async {
    final int limit = topN < items.length ? topN : items.length;
    int queuedCount = 0;
    for (int i = 0; i < limit; i++) {
      final Failure? failure = await queueDownload(items[i]);
      if (failure == null) {
        queuedCount++;
      }
    }
    return queuedCount;
  }

  Future<void> _appendCreatedPlaylistToCache(PlaylistSummary playlist) async {
    final List<CatalogItem> cached = await readCachedSection(
      CatalogSection.playlists,
    );
    if (cached.any((CatalogItem item) => item.id == playlist.id)) {
      return;
    }

    final List<CatalogItem> updated = <CatalogItem>[
      CatalogItem.fromPlaylist(playlist, description: 'Created just now'),
      ...cached,
    ];

    await persistSectionSnapshot(CatalogSection.playlists, updated);
  }

  Future<List<CatalogItem>> _readOfflineHistorySection() async {
    final List<OfflineHistoryItem> history =
        await _offlineHistoryRepository.listHistory();
    return history
        .map(
            (OfflineHistoryItem item) => CatalogItem.fromJson(<String, dynamic>{
                  'id': item.videoId,
                  'title': item.title,
                  'description': item.description,
                  if (item.durationSeconds != null)
                    'duration': item.durationSeconds,
                  if ((item.seasonName ?? '').trim().isNotEmpty)
                    'seasonName': item.seasonName,
                  'positionSeconds': item.positionSeconds,
                  'lastWatchedAt': item.lastWatchedAt.toIso8601String(),
                  'isPlayableOffline': item.isPlayableOffline,
                  if ((item.thumbnailLocalPath ?? '').trim().isNotEmpty)
                    'thumbnailLocalPath': item.thumbnailLocalPath,
                  if ((item.localVideoPath ?? '').trim().isNotEmpty)
                    'localVideoPath': item.localVideoPath,
                }))
        .where((CatalogItem item) => item.id > 0)
        .toList(growable: false);
  }
}
