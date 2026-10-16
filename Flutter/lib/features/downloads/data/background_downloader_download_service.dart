import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import '../../../core/auth/token_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logging/log_service.dart';
import '../../../core/network/api_route.dart';
import '../domain/download_models.dart';
import '../domain/download_service.dart';
import 'local_downloads_repository.dart';
import 'download_file_validator.dart';

enum DownloadPlatformKind { android, windows, generic }

class BackgroundDownloaderDownloadService implements DownloadService {
  static const Duration _progressWriteMinInterval = Duration(milliseconds: 750);
  static const double _progressWriteMinDelta = 0.02;

  BackgroundDownloaderDownloadService({
    required LocalDownloadsRepository localDownloadsRepository,
    required AppConfig appConfig,
    required TokenRepository tokenRepository,
    required LogService logService,
    required DownloadPlatformKind platformKind,
    ApiRoute? apiRoute,
    DownloadFileValidator fileValidator = const DownloadFileValidator(),
    FileDownloader? downloader,
  })  : _localDownloadsRepository = localDownloadsRepository,
        _appConfig = appConfig,
        _tokenRepository = tokenRepository,
        _logService = logService,
        _platformKind = platformKind,
        _apiRoute = apiRoute,
        _fileValidator = fileValidator,
        _downloader = downloader ?? FileDownloader();

  final LocalDownloadsRepository _localDownloadsRepository;
  final AppConfig _appConfig;
  final TokenRepository _tokenRepository;
  final LogService _logService;
  final DownloadPlatformKind _platformKind;
  final ApiRoute? _apiRoute;
  final DownloadFileValidator _fileValidator;
  final StreamController<List<DownloadItem>> _updatesController =
      StreamController<List<DownloadItem>>.broadcast();
  final FileDownloader _downloader;
  List<DownloadItem> _lastSnapshot = const <DownloadItem>[];
  final Map<int, DownloadItem> _itemsByVideoId = <int, DownloadItem>{};
  final Map<int, _ProgressWriteState> _progressWriteState =
      <int, _ProgressWriteState>{};

  bool _initialized = false;
  Future<void>? _initializeFuture;
  Future<void>? _notificationPermissionFuture;
  StreamSubscription<TaskUpdate>? _updateSubscription;

  @override
  Future<void> initialize() {
    if (_initialized) {
      return Future<void>.value();
    }
    _initializeFuture ??= _initializeInternal();
    return _initializeFuture!;
  }

  Future<void> _initializeInternal() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _configurePlatform();
    _downloader.trackTasks();
    _downloader.resumeFromBackground();

    _updateSubscription = _downloader.updates.listen(
      (TaskUpdate update) async {
        if (update.task.group != FileDownloader.defaultGroup) return;
        try {
          if (update is TaskStatusUpdate) {
            await _handleStatusUpdate(update);
          } else if (update is TaskProgressUpdate) {
            await _handleProgressUpdate(update);
          }
        } catch (error, stackTrace) {
          _logService.error(
              'Download update handling failed', error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _logService.error('Download updates stream failed', error, stackTrace);
      },
    );

    await _emitSnapshot();
  }

  Future<void> _configurePlatform() async {
    if (_platformKind != DownloadPlatformKind.android) {
      return;
    }

    await _downloader.configure(
      globalConfig: <(String, dynamic)>[(Config.runInForeground, true)],
    );
    _downloader.configureNotificationForGroup(
      FileDownloader.defaultGroup,
      running: const TaskNotification(
        'LocalTube download',
        'Downloading {filename}',
      ),
      complete: const TaskNotification(
        'LocalTube download',
        '{filename} completed',
      ),
      error: const TaskNotification(
        'LocalTube download',
        '{filename} failed',
      ),
      progressBar: true,
      tapOpensFile: false,
    );
  }

  Future<void> _ensureNotificationPermission() {
    if (_platformKind != DownloadPlatformKind.android) {
      return Future<void>.value();
    }
    // Coalesce concurrent downloads and avoid repeated prompts after a denial.
    return _notificationPermissionFuture ??= _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    PermissionStatus status =
        await _downloader.permissions.status(PermissionType.notifications);
    if (status != PermissionStatus.granted) {
      status =
          await _downloader.permissions.request(PermissionType.notifications);
    }
    // This plugin does not start its foreground service without notifications.
    if (status != PermissionStatus.granted) {
      _logService.warn(
        'Download notifications are not allowed; Android may suspend downloads '
        'when the screen is locked. Enable notifications in app settings.',
      );
    }
  }

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    await initialize();
    // Playback validation can update a download directly in the repository.
    await _emitSnapshot();
    yield _lastSnapshot;
    yield* _updatesController.stream;
  }

  @override
  Future<void> enqueue({
    required int videoId,
    required String remoteUrl,
    String? title,
  }) async {
    await initialize();

    final DownloadItem? existing =
        await _localDownloadsRepository.findByVideoId(
      videoId,
    );
    if (existing != null && existing.status.isActive) {
      return;
    }

    await _ensureNotificationPermission();

    final DownloadTask task = await _buildTask(
      videoId: videoId,
      remoteUrl: remoteUrl,
      title: title ?? existing?.title,
      taskId: existing?.taskId,
    );

    await _localDownloadsRepository.queueDownload(
      videoId: videoId,
      remoteUrl: remoteUrl,
      title: title ?? existing?.title,
      queuedAt: DateTime.now().toUtc(),
      taskId: task.taskId,
      localPath: existing?.localPath,
    );

    final bool accepted = await _downloader.enqueue(task);
    if (!accepted) {
      await _localDownloadsRepository.save(
        DownloadItem(
          videoId: videoId,
          status: DownloadStatus.failed,
          progress: existing?.progress ?? 0,
          remoteUrl: remoteUrl,
          title: title ?? existing?.title,
          queuedAt: DateTime.now().toUtc(),
          localPath: existing?.localPath,
          speedMbps: null,
          eta: null,
          taskId: task.taskId,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }

    await _emitSnapshot();
  }

  @override
  Future<void> pause(int videoId) async {
    await initialize();
    final DownloadItem? item = await _getCachedItemByVideoId(videoId);
    if (item == null || item.taskId == null || item.taskId!.isEmpty) {
      return;
    }

    final DownloadTask task = await _taskForItem(item);
    final bool paused = await _downloader.pause(task);
    if (!paused) {
      return;
    }

    await _localDownloadsRepository.save(
      item.copyWith(
        status: DownloadStatus.paused,
        clearSpeedMbps: true,
        clearEta: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await _emitSnapshot();
  }

  @override
  Future<void> resume(int videoId) async {
    await initialize();
    final DownloadItem? item = await _getCachedItemByVideoId(videoId);
    if (item == null) {
      return;
    }

    await _ensureNotificationPermission();

    DownloadTask task = await _taskForItem(item);
    final DownloadTask routedTask = await _buildTask(
      videoId: item.videoId,
      remoteUrl: item.remoteUrl,
      title: item.title,
    );
    if (task.url != routedTask.url) {
      if (item.taskId != null && item.taskId!.isNotEmpty) {
        await _downloader.cancelTaskWithId(item.taskId!);
      }
      task = routedTask;
    }
    bool resumed = false;
    try {
      final bool canResume = await _downloader.taskCanResume(task);
      if (canResume) {
        resumed = await _downloader.resume(task);
      }
    } catch (error, stackTrace) {
      _logService.error(
          'Resume failed, fallback to enqueue', error, stackTrace);
    }

    if (!resumed) {
      resumed = await _downloader.enqueue(task);
    }

    await _localDownloadsRepository.save(
      item.copyWith(
        status: resumed ? DownloadStatus.downloading : DownloadStatus.failed,
        taskId: task.taskId,
        progress: task.taskId == item.taskId ? item.progress : 0,
        clearSpeedMbps: !resumed,
        clearEta: !resumed,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await _emitSnapshot();
  }

  @override
  Future<void> stop(int videoId) async {
    await initialize();
    final DownloadItem? item = await _getCachedItemByVideoId(videoId);
    if (item == null) {
      return;
    }

    bool stoppedAsPause = false;
    if (item.taskId != null && item.taskId!.isNotEmpty) {
      final DownloadTask task = await _taskForItem(item);
      try {
        stoppedAsPause = await _downloader.pause(task);
      } catch (error, stackTrace) {
        _logService.error('Pause on stop failed', error, stackTrace);
      }
      if (!stoppedAsPause) {
        await _downloader.cancelTaskWithId(item.taskId!);
      }
    }

    await _localDownloadsRepository.save(
      item.copyWith(
        status: DownloadStatus.paused,
        taskId: stoppedAsPause ? item.taskId : null,
        clearSpeedMbps: true,
        clearEta: true,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await _emitSnapshot();
  }

  @override
  Future<void> deleteLocal(int videoId) async {
    await initialize();
    final DownloadItem? item = await _getCachedItemByVideoId(videoId);
    if (item == null) {
      return;
    }

    if (item.taskId != null && item.taskId!.isNotEmpty) {
      await _downloader.cancelTaskWithId(item.taskId!);
    }

    final String? localPath = item.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final File file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _localDownloadsRepository.delete(videoId);
    _itemsByVideoId.remove(videoId);
    _progressWriteState.remove(videoId);
    await _emitSnapshot();
  }

  Future<DownloadTask> _taskForItem(DownloadItem item) async {
    final String taskId = item.taskId ?? '';
    if (taskId.isNotEmpty) {
      final Task? tracked = await _downloader.taskForId(taskId);
      if (tracked is DownloadTask) {
        return tracked;
      }
    }

    return _buildTask(
      videoId: item.videoId,
      remoteUrl: item.remoteUrl,
      title: item.title,
      taskId: item.taskId,
    );
  }

  Future<DownloadTask> _buildTask({
    required int videoId,
    required String remoteUrl,
    String? title,
    String? taskId,
  }) async {
    final Uri publicUri = _resolveUri(remoteUrl);
    final Uri requestUri = _apiRoute == null
        ? publicUri
        : await _apiRoute.routeMediaUri(publicUri);
    final Map<String, String> headers = <String, String>{};
    final session = await _tokenRepository.read();
    if (session != null && session.accessToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    return DownloadTask(
      taskId: taskId,
      url: requestUri.toString(),
      filename: _buildDownloadFilename(videoId: videoId, title: title),
      directory: 'downloads',
      baseDirectory: BaseDirectory.applicationDocuments,
      headers: headers,
      updates: Updates.statusAndProgress,
      allowPause: true,
      retries: _platformKind == DownloadPlatformKind.android ? 5 : 3,
      requiresWiFi: false,
      metaData: videoId.toString(),
    );
  }

  Uri _resolveUri(String remoteUrl) {
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

  Future<int?> _resolveVideoId(Task task) async {
    final String metadata = task.metaData.trim();
    final int? fromMetadata = int.tryParse(metadata);
    if (fromMetadata != null && fromMetadata > 0) {
      return fromMetadata;
    }

    final String taskId = task.taskId.trim();
    if (taskId.isEmpty) {
      return null;
    }
    final DownloadItem? existing = await _localDownloadsRepository.findByTaskId(
      taskId,
    );
    return existing?.videoId;
  }

  Future<DownloadItem?> _getCachedItemByVideoId(int videoId) async {
    final DownloadItem? cached = _itemsByVideoId[videoId];
    if (cached != null) {
      return cached;
    }
    return _localDownloadsRepository.findByVideoId(videoId);
  }

  Future<void> _handleStatusUpdate(TaskStatusUpdate update) async {
    final int? videoId = await _resolveVideoId(update.task);
    if (videoId == null) {
      return;
    }

    final DownloadItem? current = await _getCachedItemByVideoId(videoId);
    if (current?.taskId != null && current!.taskId != update.task.taskId) {
      return;
    }
    DownloadStatus status = _mapTaskStatus(update.status);

    DownloadItem next = current ??
        DownloadItem(
          videoId: videoId,
          status: status,
          progress: 0,
          remoteUrl: _normalizeRemoteUrl(update.task.url),
          title: null,
          speedMbps: null,
          eta: null,
          queuedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

    String? localPath = next.localPath;
    double progress = next.progress;
    String? taskId = update.task.taskId;

    if (status == DownloadStatus.completed) {
      progress = 1;
      localPath = await update.task.filePath();
      taskId = null;
      try {
        await _fileValidator.validate(localPath);
      } on InvalidDownloadException catch (error) {
        status = DownloadStatus.damaged;
        _logService.warn(
          'Download integrity check failed for video=$videoId: ${error.reason}',
        );
      } on FileSystemException catch (error, stackTrace) {
        status = DownloadStatus.failed;
        _logService.error(
            'Download file could not be checked', error, stackTrace);
      }
    }

    if (status == DownloadStatus.failed) {
      taskId = null;
    }

    next = next.copyWith(
      status: status,
      progress: progress,
      localPath: localPath,
      taskId: taskId,
      clearTaskId: taskId == null,
      clearSpeedMbps: status != DownloadStatus.downloading,
      clearEta: status != DownloadStatus.downloading,
      updatedAt: DateTime.now().toUtc(),
    );
    await _localDownloadsRepository.save(next);
    _itemsByVideoId[videoId] = next;
    if (status != DownloadStatus.downloading) {
      _progressWriteState.remove(videoId);
    }
    await _emitSnapshot();
  }

  Future<void> _handleProgressUpdate(TaskProgressUpdate update) async {
    final int? videoId = await _resolveVideoId(update.task);
    if (videoId == null) {
      return;
    }

    final DownloadItem? current = await _getCachedItemByVideoId(videoId);
    if (current?.taskId != null && current!.taskId != update.task.taskId) {
      return;
    }
    // A final progress callback must not make a checked file active again.
    if (current != null &&
        (current.status == DownloadStatus.completed ||
            current.status == DownloadStatus.damaged) &&
        current.taskId != update.task.taskId) {
      return;
    }
    final DateTime nowUtc = DateTime.now().toUtc();
    final double nextProgress = update.progress.clamp(0, 1).toDouble();
    final _ProgressWriteState? lastWrite = _progressWriteState[videoId];
    final bool shouldPersist = lastWrite == null ||
        nextProgress >= 1 ||
        (nextProgress - lastWrite.progress).abs() >= _progressWriteMinDelta ||
        nowUtc.difference(lastWrite.savedAtUtc) >= _progressWriteMinInterval;
    if (!shouldPersist) {
      return;
    }

    final DownloadItem next = (current ??
            DownloadItem(
              videoId: videoId,
              status: DownloadStatus.downloading,
              progress: 0,
              remoteUrl: _normalizeRemoteUrl(update.task.url),
              title: null,
              speedMbps: null,
              eta: null,
              queuedAt: nowUtc,
              updatedAt: nowUtc,
            ))
        .copyWith(
      status: DownloadStatus.downloading,
      progress: nextProgress,
      speedMbps: update.hasNetworkSpeed && update.networkSpeed >= 0
          ? update.networkSpeed
          : null,
      eta: update.hasTimeRemaining && !update.timeRemaining.isNegative
          ? update.timeRemaining
          : null,
      taskId: update.task.taskId,
      updatedAt: nowUtc,
    );
    await _localDownloadsRepository.save(next);
    _itemsByVideoId[videoId] = next;
    _progressWriteState[videoId] = _ProgressWriteState(
      progress: nextProgress,
      savedAtUtc: nowUtc,
    );
    await _emitSnapshot();
  }

  DownloadStatus _mapTaskStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.enqueued:
        return DownloadStatus.queued;
      case TaskStatus.running:
      case TaskStatus.waitingToRetry:
        return DownloadStatus.downloading;
      case TaskStatus.paused:
      case TaskStatus.canceled:
        return DownloadStatus.paused;
      case TaskStatus.complete:
        return DownloadStatus.completed;
      case TaskStatus.failed:
      case TaskStatus.notFound:
        return DownloadStatus.failed;
    }
  }

  String _normalizeRemoteUrl(String url) {
    try {
      final Uri resolved = Uri.parse(url);
      final Uri baseUri = Uri.parse(_appConfig.apiBaseUrl);
      final String normalizedPath = _normalizeBackendPath(resolved.path);
      final String querySuffix = resolved.hasQuery ? '?${resolved.query}' : '';
      final bool sameOrigin = resolved.hasScheme &&
          resolved.scheme == baseUri.scheme &&
          resolved.host == baseUri.host &&
          resolved.port == baseUri.port;
      if (!resolved.hasScheme ||
          sameOrigin ||
          _looksLikeBackendPath(resolved.path)) {
        return '$normalizedPath$querySuffix';
      }
    } catch (_) {}
    return url;
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

  String _buildDownloadFilename({
    required int videoId,
    String? title,
  }) {
    final String sanitizedTitle = _sanitizeFilename(title);
    if (sanitizedTitle.isEmpty) {
      return 'video_$videoId.mp4';
    }
    if (_hasKnownVideoExtension(sanitizedTitle)) {
      return sanitizedTitle;
    }
    return '$sanitizedTitle.mp4';
  }

  String _sanitizeFilename(String? source) {
    final String value = (source ?? '').trim();
    if (value.isEmpty) {
      return '';
    }

    final String sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');

    if (sanitized.isEmpty) {
      return '';
    }

    const int maxLength = 96;
    if (sanitized.length <= maxLength) {
      return sanitized;
    }
    return sanitized.substring(0, maxLength).trimRight();
  }

  bool _hasKnownVideoExtension(String filename) {
    final String lower = filename.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  Future<void> _emitSnapshot() async {
    final List<DownloadItem> downloads =
        await _localDownloadsRepository.listAll();
    _lastSnapshot = downloads;
    _itemsByVideoId
      ..clear()
      ..addEntries(
        downloads.map(
          (DownloadItem item) => MapEntry(item.videoId, item),
        ),
      );
    _progressWriteState.removeWhere(
      (int videoId, _ProgressWriteState value) =>
          !_itemsByVideoId.containsKey(videoId) ||
          _itemsByVideoId[videoId]!.status != DownloadStatus.downloading,
    );
    if (!_updatesController.isClosed) {
      _updatesController.add(downloads);
    }
  }

  Future<void> dispose() async {
    _progressWriteState.clear();
    _itemsByVideoId.clear();
    await _updateSubscription?.cancel();
    await _updatesController.close();
  }
}

class _ProgressWriteState {
  const _ProgressWriteState({
    required this.progress,
    required this.savedAtUtc,
  });

  final double progress;
  final DateTime savedAtUtc;
}

class AndroidDownloadService extends BackgroundDownloaderDownloadService {
  AndroidDownloadService({
    required super.localDownloadsRepository,
    required super.appConfig,
    required super.tokenRepository,
    required super.logService,
    super.apiRoute,
  }) : super(
          platformKind: DownloadPlatformKind.android,
        );
}

class WindowsDownloadService extends BackgroundDownloaderDownloadService {
  WindowsDownloadService({
    required super.localDownloadsRepository,
    required super.appConfig,
    required super.tokenRepository,
    required super.logService,
    super.apiRoute,
  }) : super(
          platformKind: DownloadPlatformKind.windows,
        );
}

class GenericDownloadService extends BackgroundDownloaderDownloadService {
  GenericDownloadService({
    required super.localDownloadsRepository,
    required super.appConfig,
    required super.tokenRepository,
    required super.logService,
    super.apiRoute,
  }) : super(
          platformKind: DownloadPlatformKind.generic,
        );
}
