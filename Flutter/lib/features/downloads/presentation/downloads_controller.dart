import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../domain/download_models.dart';
import '../domain/download_service.dart';

class DownloadsState {
  const DownloadsState({
    required this.items,
    required this.isLoading,
    this.errorMessage,
  });

  final List<DownloadItem> items;
  final bool isLoading;
  final String? errorMessage;

  factory DownloadsState.initial() =>
      const DownloadsState(items: <DownloadItem>[], isLoading: true);

  DownloadsState copyWith({
    List<DownloadItem>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadsController extends StateNotifier<DownloadsState> {
  DownloadsController(this._downloadService) : super(DownloadsState.initial()) {
    _initialize();
  }

  final DownloadService _downloadService;
  StreamSubscription<List<DownloadItem>>? _subscription;
  bool _isInitializing = false;

  Future<void> _initialize() async {
    if (_isInitializing) {
      return;
    }
    _isInitializing = true;
    try {
      await _downloadService.initialize();
      _subscription = _downloadService.watchDownloads().listen((items) {
        state = state.copyWith(
          items: items,
          isLoading: false,
          clearError: true,
        );
      });
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Downloads initialization failed: $error',
      );
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> reload() async {
    await _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );
    await _initialize();
  }

  Future<void> pause(int videoId) => _runGuarded(
        () => _downloadService.pause(videoId),
        failureMessage: 'Unable to pause download',
      );

  Future<void> resume(int videoId) => _runGuarded(
        () => _downloadService.resume(videoId),
        failureMessage: 'Unable to resume download',
      );

  Future<void> stop(int videoId) => _runGuarded(
        () => _downloadService.stop(videoId),
        failureMessage: 'Unable to stop download',
      );

  Future<void> delete(int videoId) => _runGuarded(
        () => _downloadService.deleteLocal(videoId),
        failureMessage: 'Unable to delete local download',
      );

  Future<void> _runGuarded(
    Future<void> Function() action, {
    required String failureMessage,
  }) async {
    try {
      await action();
      state = state.copyWith(clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: '$failureMessage: $error');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<DownloadsController, DownloadsState>
    downloadsControllerProvider =
    StateNotifierProvider<DownloadsController, DownloadsState>(
  (Ref ref) => DownloadsController(ref.watch(downloadServiceProvider)),
);
