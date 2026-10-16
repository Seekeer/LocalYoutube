import 'dart:io';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_route.dart';
import '../../../downloads/domain/download_models.dart';
import '../../../downloads/data/local_downloads_repository.dart';
import '../../../downloads/data/download_file_validator.dart';
import '../../data/playback_sync_repository.dart';
import '../player_models.dart';

class PlayVideoUseCase {
  PlayVideoUseCase({
    required LocalDownloadsRepository localDownloadsRepository,
    required PlaybackSyncRepository playbackSyncRepository,
    required AppConfig appConfig,
    ApiRoute? apiRoute,
    DownloadFileValidator fileValidator = const DownloadFileValidator(),
  })  : _localDownloadsRepository = localDownloadsRepository,
        _playbackSyncRepository = playbackSyncRepository,
        _appConfig = appConfig,
        _apiRoute = apiRoute,
        _fileValidator = fileValidator;

  final LocalDownloadsRepository _localDownloadsRepository;
  final PlaybackSyncRepository _playbackSyncRepository;
  final AppConfig _appConfig;
  final ApiRoute? _apiRoute;
  final DownloadFileValidator _fileValidator;

  Future<PlayableVideo> call(
      {required int videoId, bool localOnly = false}) async {
    final download = await _localDownloadsRepository.findByVideoId(videoId);
    if (localOnly && download?.status == DownloadStatus.damaged) {
      throw const InvalidDownloadException('Previously detected damaged file.');
    }
    final bool canUseLocalFile = download?.status == DownloadStatus.completed;
    Uri? localUri;
    if (canUseLocalFile) {
      try {
        localUri = await _resolveLocalUri(download?.localPath);
        if (localUri != null) {
          await _fileValidator.validate(localUri.toFilePath());
        }
      } on InvalidDownloadException {
        await _localDownloadsRepository.save(
          download!.copyWith(
            status: DownloadStatus.damaged,
            clearTaskId: true,
            clearSpeedMbps: true,
            clearEta: true,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        rethrow;
      }
    }
    if (localOnly && localUri == null) {
      throw OfflinePlaybackUnavailableException(videoId: videoId);
    }
    final Uri sourceUri;
    if (localUri != null) {
      sourceUri = localUri;
    } else {
      final Uri remoteUri = _resolveRemoteUri(
        download?.remoteUrl,
        videoId: videoId,
      );
      sourceUri = _apiRoute == null
          ? remoteUri
          : await _apiRoute.routeMediaUri(remoteUri);
    }

    final Duration startPosition =
        await _playbackSyncRepository.resolveStartPosition(
      videoId,
      localOnly: localOnly,
    );
    final String resolvedTitle = (download?.title ?? '').trim();

    return PlayableVideo(
      videoId: videoId,
      sourceUri: sourceUri,
      sourceKind: localUri == null
          ? PlayableSourceKind.remoteUrl
          : PlayableSourceKind.localFile,
      startPosition: startPosition,
      title: resolvedTitle.isEmpty ? 'Video #$videoId' : resolvedTitle,
    );
  }

  Future<Uri?> _resolveLocalUri(String? rawPath) async {
    final String path = (rawPath ?? '').trim();
    if (path.isEmpty) {
      return null;
    }
    final File file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.uri;
  }

  Uri _resolveRemoteUri(
    String? rawRemoteUrl, {
    required int videoId,
  }) {
    final String remoteUrl;
    if ((rawRemoteUrl ?? '').trim().isEmpty) {
      remoteUrl = '/api/files/getFileById?fileId=$videoId';
    } else {
      remoteUrl = rawRemoteUrl!.trim();
    }

    final Uri baseUri = Uri.parse(_appConfig.apiBaseUrl);
    final Uri parsed = Uri.parse(remoteUrl);
    final String normalizedPath = _normalizeBackendPath(parsed.path);
    final String querySuffix = parsed.hasQuery ? '?${parsed.query}' : '';

    if (parsed.hasScheme) {
      final bool sameOrigin = parsed.scheme == baseUri.scheme &&
          parsed.host == baseUri.host &&
          parsed.port == baseUri.port;
      if (sameOrigin || _looksLikeBackendPath(parsed.path)) {
        return baseUri.resolve('$normalizedPath$querySuffix');
      }
      return parsed;
    }
    return baseUri.resolve('$normalizedPath$querySuffix');
  }

  bool _looksLikeBackendPath(String path) {
    final String normalized = _normalizeBackendPath(path);
    return normalized.startsWith('/api/');
  }

  String _normalizeBackendPath(String path) {
    final String withLeadingSlash = path.startsWith('/') ? path : '/$path';
    if (withLeadingSlash.startsWith('/api/')) {
      return withLeadingSlash;
    }
    if (withLeadingSlash.startsWith('/files/')) {
      return '/api$withLeadingSlash';
    }
    return withLeadingSlash;
  }
}
