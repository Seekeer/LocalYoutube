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

  /// How long a downloaded video waits for the server's resume position before it starts from
  /// the position this device saved. A downloaded copy plays without the server, so a server that
  /// is down or slow must not keep it from starting.
  static const Duration serverPositionWait = Duration(seconds: 3);

  /// Resolves what to play: the downloaded copy when it is usable, otherwise
  /// the remote source. [forceRemote] skips the downloaded copy, for when the
  /// player already failed on it; it cannot be combined with [localOnly].
  Future<PlayableVideo> call({
    required int videoId,
    bool localOnly = false,
    bool forceRemote = false,
  }) async {
    assert(!(localOnly && forceRemote));
    final download = await _localDownloadsRepository.findByVideoId(videoId);
    if (localOnly && download?.status == DownloadStatus.damaged) {
      throw const InvalidDownloadException('Previously detected damaged file.');
    }
    final bool canUseLocalFile =
        !forceRemote && download?.status == DownloadStatus.completed;
    Uri? localUri;
    if (canUseLocalFile) {
      try {
        localUri = await _resolveLocalUri(download?.localPath);
        if (localUri != null) {
          await _fileValidator.validate(localUri.toFilePath());
        }
      } on InvalidDownloadException {
        await _saveAsDamaged(download!);
        // Offline there is no other source to play, so the damage is the answer.
        // Online the downloaded copy is only preferred, not required.
        if (localOnly) {
          rethrow;
        }
        localUri = null;
      } on FileSystemException {
        // The file vanished or became unreadable after the existence check.
        // That says nothing about its contents, so it is not marked damaged:
        // online the remote source plays, offline playback is unavailable.
        localUri = null;
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

    final Duration startPosition = localUri != null && !localOnly
        ? await _resolveDownloadedStartPosition(videoId)
        : await _playbackSyncRepository.resolveStartPosition(
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

  /// Marks the downloaded copy damaged after the native player could not open
  /// it while the remote copy of the same video could. Only the completed
  /// download stored at [localFile] is marked, so a download that replaced it
  /// meanwhile is left alone.
  Future<void> markLocalCopyDamaged(
    int videoId, {
    required Uri localFile,
  }) async {
    final DownloadItem? download =
        await _localDownloadsRepository.findByVideoId(videoId);
    if (download == null || download.status != DownloadStatus.completed) {
      return;
    }
    final String path = (download.localPath ?? '').trim();
    if (path.isEmpty || File(path).uri != localFile) {
      return;
    }
    await _saveAsDamaged(download);
  }

  Future<void> _saveAsDamaged(DownloadItem download) {
    return _localDownloadsRepository.save(
      download.copyWith(
        status: DownloadStatus.damaged,
        clearTaskId: true,
        clearSpeedMbps: true,
        clearEta: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// The resume position for a downloaded copy: the server's when it answers in time, otherwise
  /// the one saved on this device. The server's answer still lands locally when it comes late.
  Future<Duration> _resolveDownloadedStartPosition(int videoId) async {
    try {
      return await _playbackSyncRepository
          .resolveStartPosition(videoId)
          .timeout(serverPositionWait);
    } on Object {
      return _playbackSyncRepository.resolveStartPosition(
        videoId,
        localOnly: true,
      );
    }
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
