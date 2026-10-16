import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../core/errors/failure.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog_models.dart';

class CatalogState {
  const CatalogState({
    required this.section,
    required this.items,
    required this.isLoading,
    required this.isFromCache,
    required this.playlistAssignments,
    this.error,
  });

  final CatalogSection section;
  final List<CatalogItem> items;
  final bool isLoading;
  final bool isFromCache;
  final Map<int, String> playlistAssignments;
  final Failure? error;

  factory CatalogState.initial() => const CatalogState(
        section: CatalogSection.latest,
        items: <CatalogItem>[],
        isLoading: false,
        isFromCache: false,
        playlistAssignments: <int, String>{},
      );

  CatalogState copyWith({
    CatalogSection? section,
    List<CatalogItem>? items,
    bool? isLoading,
    bool? isFromCache,
    Map<int, String>? playlistAssignments,
    Failure? error,
    bool clearError = false,
    bool clearPlaylistAssignments = false,
  }) {
    return CatalogState(
      section: section ?? this.section,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isFromCache: isFromCache ?? this.isFromCache,
      playlistAssignments: clearPlaylistAssignments
          ? const <int, String>{}
          : playlistAssignments ?? this.playlistAssignments,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(this._repository) : super(CatalogState.initial());

  static const Duration _sectionSwitchDebounce = Duration(milliseconds: 250);
  static const Duration _memoryCacheTtl = Duration(minutes: 5);

  final CatalogRepository _repository;
  final Map<CatalogSection, _CatalogSectionSnapshot> _memoryCache =
      <CatalogSection, _CatalogSectionSnapshot>{};
  final Map<CatalogSection, Future<_SectionRefreshResult>>
      _inFlightLoadsBySection =
      <CatalogSection, Future<_SectionRefreshResult>>{};
  Timer? _scheduledLoadTimer;
  int _lastRequestId = 0;

  void scheduleLoadSection(CatalogSection section) {
    _scheduledLoadTimer?.cancel();
    _scheduledLoadTimer = Timer(
      _sectionSwitchDebounce,
      () => unawaited(loadSection(section)),
    );
  }

  Future<void> loadSection(
    CatalogSection section, {
    bool forceRefresh = false,
  }) async {
    _scheduledLoadTimer?.cancel();
    final int requestId = ++_lastRequestId;
    final DateTime nowUtc = DateTime.now().toUtc();
    final _CatalogSectionSnapshot? warmSnapshot = _memoryCache[section];
    final bool useWarmSnapshot = !forceRefresh &&
        warmSnapshot != null &&
        nowUtc.difference(warmSnapshot.updatedAtUtc) <= _memoryCacheTtl;

    final List<CatalogItem> cached = useWarmSnapshot
        ? warmSnapshot.items
        : await _repository.readCachedSection(section);
    if (_lastRequestId != requestId) {
      return;
    }

    _cacheSection(section, cached, nowUtc: nowUtc);
    state = state.copyWith(
      section: section,
      items: cached,
      isFromCache: cached.isNotEmpty,
      isLoading: !useWarmSnapshot,
      clearError: true,
      clearPlaylistAssignments: true,
    );
    if (useWarmSnapshot) {
      return;
    }

    final Future<_SectionRefreshResult> inFlightLoad =
        _inFlightLoadsBySection.putIfAbsent(
      section,
      () async {
        final (List<CatalogItem> remoteItems, Failure? failure) =
            await _repository.refreshSection(section);
        return _SectionRefreshResult(
          items: remoteItems,
          failure: failure,
        );
      },
    );

    final _SectionRefreshResult refreshResult;
    try {
      refreshResult = await inFlightLoad;
    } finally {
      if (identical(_inFlightLoadsBySection[section], inFlightLoad)) {
        _inFlightLoadsBySection.remove(section);
      }
    }

    if (_lastRequestId != requestId) {
      return;
    }

    if (refreshResult.failure != null) {
      state = state.copyWith(
        isLoading: false,
        isFromCache: cached.isNotEmpty,
        error: refreshResult.failure,
      );
      return;
    }

    _cacheSection(section, refreshResult.items, nowUtc: DateTime.now().toUtc());
    state = state.copyWith(
      items: refreshResult.items,
      isLoading: false,
      isFromCache: false,
      clearError: true,
    );
  }

  Future<void> refresh() => loadSection(state.section, forceRefresh: true);

  Future<Failure?> download(CatalogItem item) =>
      _repository.queueDownload(item);

  Future<Failure?> deleteLocal(CatalogItem item) =>
      _repository.deleteLocal(item.id);

  Future<Failure?> deleteServer(CatalogItem item) =>
      _repository.deleteServer(item.id);

  Future<(List<PlaylistSummary>, Failure?)> loadPlaylists() {
    return _repository.loadPlaylists();
  }

  Future<Failure?> addToPlaylist({
    required CatalogItem item,
    required PlaylistSummary playlist,
  }) async {
    final Failure? failure = await _repository.addToPlaylist(
      videoId: item.id,
      playlistId: playlist.id,
    );
    if (failure != null) {
      return failure;
    }

    _markVideoAsAddedToPlaylist(videoId: item.id, playlistName: playlist.name);
    await _markPlaylistAsUpdated(playlist.id);
    return null;
  }

  Future<Failure?> createPlaylistAndAdd({
    required CatalogItem item,
    required String playlistName,
  }) async {
    final (PlaylistSummary? playlist, Failure? failure) =
        await _repository.createPlaylist(playlistName);
    if (failure != null || playlist == null) {
      return failure ?? const UnknownFailure('Unable to create playlist');
    }

    await _insertPlaylistIfVisible(playlist);
    return addToPlaylist(item: item, playlist: playlist);
  }

  Future<int> downloadTopN(int topN) {
    return _repository.queueTopDownloads(state.items, topN: topN);
  }

  void _markVideoAsAddedToPlaylist({
    required int videoId,
    required String playlistName,
  }) {
    state = state.copyWith(
      playlistAssignments: <int, String>{
        ...state.playlistAssignments,
        videoId: playlistName,
      },
    );
  }

  Future<void> _insertPlaylistIfVisible(PlaylistSummary playlist) async {
    if (state.section != CatalogSection.playlists) {
      return;
    }
    final bool alreadyVisible = state.items.any(
      (CatalogItem item) => item.id == playlist.id,
    );
    if (alreadyVisible) {
      return;
    }

    final List<CatalogItem> updatedItems = <CatalogItem>[
      CatalogItem.fromPlaylist(playlist, description: 'Created just now'),
      ...state.items,
    ];

    state = state.copyWith(items: updatedItems);
    _cacheSection(CatalogSection.playlists, updatedItems);
    await _repository.persistSectionSnapshot(
      CatalogSection.playlists,
      updatedItems,
    );
  }

  Future<void> _markPlaylistAsUpdated(int playlistId) async {
    if (state.section != CatalogSection.playlists) {
      return;
    }

    bool changed = false;
    final List<CatalogItem> updatedItems = state.items.map((CatalogItem item) {
      if (item.id != playlistId) {
        return item;
      }
      changed = true;
      return item.copyWith(
        raw: <String, dynamic>{
          ...item.raw,
          'description': 'Updated just now',
        },
      );
    }).toList(growable: false);

    if (!changed) {
      return;
    }

    state = state.copyWith(items: updatedItems);
    _cacheSection(CatalogSection.playlists, updatedItems);
    await _repository.persistSectionSnapshot(
      CatalogSection.playlists,
      updatedItems,
    );
  }

  void _cacheSection(
    CatalogSection section,
    List<CatalogItem> items, {
    DateTime? nowUtc,
  }) {
    _memoryCache[section] = _CatalogSectionSnapshot(
      items: items,
      updatedAtUtc: nowUtc ?? DateTime.now().toUtc(),
    );
  }

  @override
  void dispose() {
    _scheduledLoadTimer?.cancel();
    super.dispose();
  }
}

class _CatalogSectionSnapshot {
  const _CatalogSectionSnapshot({
    required this.items,
    required this.updatedAtUtc,
  });

  final List<CatalogItem> items;
  final DateTime updatedAtUtc;
}

class _SectionRefreshResult {
  const _SectionRefreshResult({
    required this.items,
    required this.failure,
  });

  final List<CatalogItem> items;
  final Failure? failure;
}

final StateNotifierProvider<CatalogController, CatalogState>
    catalogControllerProvider =
    StateNotifierProvider<CatalogController, CatalogState>(
  (Ref ref) => CatalogController(ref.watch(catalogRepositoryProvider)),
);
