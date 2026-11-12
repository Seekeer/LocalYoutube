import 'dart:async';

import '../../core/logging/log_service.dart';
import '../../features/bookmarks/data/bookmarks_repository.dart';
import '../../features/player/data/playback_sync_repository.dart';

class AppSyncCoordinator {
  AppSyncCoordinator({
    required BookmarksRepository bookmarksRepository,
    required PlaybackSyncRepository playbackSyncRepository,
    required LogService logService,
    Future<void> Function()? cacheTranscripts,
    Future<void> Function()? syncNoteDrafts,
    Duration syncPeriod = const Duration(seconds: 6),
  })  : _bookmarksRepository = bookmarksRepository,
        _playbackSyncRepository = playbackSyncRepository,
        _logService = logService,
        _syncPeriod = syncPeriod,
        _cacheTranscripts = cacheTranscripts,
        _syncNoteDrafts = syncNoteDrafts;

  final BookmarksRepository _bookmarksRepository;
  final PlaybackSyncRepository _playbackSyncRepository;
  final LogService _logService;
  final Duration _syncPeriod;
  final Future<void> Function()? _cacheTranscripts;

  /// Recognizes dictation clips kept offline and applies offline Topics.
  /// Recognized text stays a Draft until the person confirms it.
  Future<void> Function()? _syncNoteDrafts;

  /// Note Drafts sync through the same repository the screens use, which
  /// knows the manual Autonomous Mode; that lives in the provider scope, so
  /// it is bound once the app is running.
  void bindNoteDraftsSync(Future<void> Function()? syncNoteDrafts) {
    _syncNoteDrafts = syncNoteDrafts;
  }

  Timer? _timer;
  bool _isInitialized = false;
  bool _isSyncing = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    _timer = Timer.periodic(
      _syncPeriod,
      (_) => unawaited(triggerSync(reason: 'periodic')),
    );
    await triggerSync(reason: 'bootstrap');
  }

  Future<void> triggerSync({required String reason}) async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      await _playbackSyncRepository.processOutbox();
      await _bookmarksRepository.processOutbox();
      await _cacheTranscripts?.call();
      try {
        await _syncNoteDrafts?.call();
      } catch (error, stackTrace) {
        _logService.error('Note drafts sync failed', error, stackTrace);
      }
      if (reason == 'network-online' || reason == 'app-resumed') {
        await _playbackSyncRepository.reconcileRecent(limit: 20);
      }
    } catch (error, stackTrace) {
      _logService.error(
          'AppSyncCoordinator triggerSync failed', error, stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
  }
}
