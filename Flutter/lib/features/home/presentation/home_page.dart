import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/auth_notifier.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/errors/failure.dart';
import '../../../core/network/network_status.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../../shared/widgets/video_list_item.dart';
import '../../../shared/widgets/watch_progress.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_controller.dart';
import '../../downloads/domain/download_models.dart';
import '../../downloads/domain/download_service.dart';
import '../../player/presentation/player_navigation_result.dart';

final AutoDisposeStreamProvider<Map<int, DownloadItem>>
    _catalogDownloadsByVideoIdProvider =
    StreamProvider.autoDispose<Map<int, DownloadItem>>((Ref ref) async* {
  final DownloadService downloadService = ref.read(downloadServiceProvider);
  await for (final List<DownloadItem> items
      in downloadService.watchDownloads()) {
    yield <int, DownloadItem>{
      for (final DownloadItem item in items) item.videoId: item,
    };
  }
});

final AutoDisposeStreamProvider<Map<int, double>>
    _catalogWatchProgressByVideoIdProvider =
    StreamProvider.autoDispose<Map<int, double>>((Ref ref) async* {
  final StreamController<Map<int, double>> controller =
      StreamController<Map<int, double>>();
  Timer? timer;

  Future<void> emitSnapshot() async {
    final snapshots =
        await ref.read(localPlaybackRepositoryProvider).listRecent(limit: 1000);
    if (controller.isClosed) {
      return;
    }
    controller.add(<int, double>{
      for (final snapshot in snapshots)
        snapshot.videoId:
            snapshot.positionSeconds < 0 ? 0 : snapshot.positionSeconds,
    });
  }

  ref.onDispose(() async {
    timer?.cancel();
    await controller.close();
  });

  await emitSnapshot();
  timer = Timer.periodic(const Duration(seconds: 2), (_) {
    unawaited(emitSnapshot());
  });

  yield* controller.stream;
});

final AutoDisposeFutureProvider<Map<int, String>>
    _catalogSeasonNamesByIdProvider =
    FutureProvider.autoDispose<Map<int, String>>((Ref ref) async {
  final localCatalogRepository = ref.read(localCatalogRepositoryProvider);
  List<Map<String, dynamic>> rawItems =
      await localCatalogRepository.readSection(CatalogSection.series.key);
  if (rawItems.isEmpty) {
    try {
      rawItems = await ref
          .read(catalogRemoteDataSourceProvider)
          .loadSection(CatalogSection.series);
    } catch (_) {}
  }
  final Map<int, String> result = <int, String>{};

  for (final Map<String, dynamic> rawItem in rawItems) {
    final int? id = _parseRawIntValue(rawItem['id'] ?? rawItem['Id']);
    if (id == null || id <= 0) {
      continue;
    }
    final String name = (rawItem['name'] ??
            rawItem['Name'] ??
            rawItem['title'] ??
            rawItem['Title'] ??
            '')
        .toString()
        .trim();
    if (name.isEmpty) {
      continue;
    }
    result[id] = name;
  }

  return result;
});

final AutoDisposeFutureProvider<Map<int, String>>
    _catalogThumbnailPathsByIdProvider =
    FutureProvider.autoDispose<Map<int, String>>((Ref ref) async {
  final List<CatalogItem> items = ref.watch(
    catalogControllerProvider.select((CatalogState state) => state.items),
  );
  if (items.isEmpty) {
    return const <int, String>{};
  }
  try {
    return await ref
        .read(localVideoMetadataRepositoryProvider)
        .listThumbnailPaths();
  } catch (_) {
    return const <int, String>{};
  }
});

int? _parseRawIntValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString().trim());
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    this.authNotifier,
    this.initialSection = CatalogSection.latest,
  });

  final AuthNotifier? authNotifier;
  final CatalogSection initialSection;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final Map<CatalogSection, Set<int>> _locallyRemovedIdsBySection =
      <CatalogSection, Set<int>>{};
  bool _fabExtended = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(catalogControllerProvider.notifier)
          .loadSection(widget.initialSection);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CatalogState state = ref.watch(catalogControllerProvider);
    final Map<int, DownloadItem> downloadsByVideoId =
        ref.watch(_catalogDownloadsByVideoIdProvider).valueOrNull ??
            const <int, DownloadItem>{};
    final Map<int, double> watchProgressByVideoId =
        ref.watch(_catalogWatchProgressByVideoIdProvider).valueOrNull ??
            const <int, double>{};
    final Map<int, String> seasonNamesById =
        ref.watch(_catalogSeasonNamesByIdProvider).valueOrNull ??
            const <int, String>{};
    final Map<int, String> thumbnailPathsById =
        ref.watch(_catalogThumbnailPathsByIdProvider).valueOrNull ??
            const <int, String>{};
    final bool isOffline = ref.watch(networkStatusProvider).maybeWhen(
          data: (NetworkStatus status) => status == NetworkStatus.offline,
          orElse: () => false,
        );
    final bool isOfflineFallback =
        ref.watch(authNotifierProvider).isOfflineFallback;
    final bool remoteActionsDisabled = isOffline || isOfflineFallback;

    final bool canDownloadTop = state.items.isNotEmpty &&
        !remoteActionsDisabled &&
        _supportsDownload(state.section);

    return Scaffold(
      appBar: AppBar(
        // The chips below already say which list this is.
        title: const Text('Видео'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.downloads),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(left: 12),
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.downloading_rounded),
            label: const Text('Загрузки'),
          ),
          const SizedBox(width: LtSizes.gutter),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _SectionChips(
            selected: state.section,
            onSelected: (CatalogSection section) => ref
                .read(catalogControllerProvider.notifier)
                .scheduleLoadSection(section),
          ),
        ),
      ),
      floatingActionButton: canDownloadTop
          ? FloatingActionButton.extended(
              key: const Key('catalog-download-top'),
              isExtended: _fabExtended,
              onPressed: () => _downloadTopN(context, count: 5),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Скачать первые 5'),
              tooltip: 'Поставить на скачивание пять видео сверху списка',
            )
          : null,
      body: Column(
        children: <Widget>[
          if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (isOffline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StateFeedbackBanner(
                message: 'Нет сети — показано то, что сохранено на телефоне.',
                tone: StateFeedbackTone.warning,
              ),
            ),
          if (state.isFromCache && !isOffline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StateFeedbackBanner(
                message: 'Сервер не ответил — показан сохранённый список.',
                leadingIcon: Icons.history_rounded,
              ),
            ),
          if (state.error != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: StateFeedbackBanner(
                message: state.error!.message,
                tone: StateFeedbackTone.error,
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(catalogControllerProvider.notifier).refresh(),
              // The download button shrinks to its icon while the list
              // scrolls down, so it covers less of the rows.
              child: NotificationListener<UserScrollNotification>(
                onNotification: (UserScrollNotification n) {
                  final bool extend = n.direction != ScrollDirection.reverse;
                  if (n.direction != ScrollDirection.idle &&
                      extend != _fabExtended) {
                    setState(() => _fabExtended = extend);
                  }
                  return false;
                },
                child: _buildCatalogBody(
                  context: context,
                  state: state,
                  isOffline: isOffline,
                  remoteActionsDisabled: remoteActionsDisabled,
                  downloadsByVideoId: downloadsByVideoId,
                  watchProgressByVideoId: watchProgressByVideoId,
                  seasonNamesById: seasonNamesById,
                  thumbnailPathsById: thumbnailPathsById,
                  hasFab: canDownloadTop,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogBody({
    required BuildContext context,
    required CatalogState state,
    required bool isOffline,
    required bool remoteActionsDisabled,
    required Map<int, DownloadItem> downloadsByVideoId,
    required Map<int, double> watchProgressByVideoId,
    required Map<int, String> seasonNamesById,
    required Map<int, String> thumbnailPathsById,
    bool hasFab = false,
  }) {
    final List<CatalogItem> visibleItems = _buildVisibleItems(
      state: state,
    );

    if (state.isLoading && visibleItems.isEmpty) {
      return ListView(
        key: const PageStorageKey<String>('catalog-loading'),
        children: const <Widget>[
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (visibleItems.isEmpty) {
      final bool hasError = state.error != null;
      final String title = hasError
          ? 'Не удалось загрузить список'
          : isOffline
              ? 'Нет сети'
              : 'Здесь пока пусто';
      final String message = hasError
          ? state.error!.message
          : state.items.isNotEmpty && _supportsDownload(state.section)
              ? 'Все видео этого раздела уже скачаны.'
              : isOffline
                  ? 'Для этого раздела на телефоне ничего не сохранено.'
                  : 'Выберите другой раздел или потяните список вниз, чтобы обновить.';

      return ListView(
        key: PageStorageKey<String>('catalog-empty-${state.section.key}'),
        children: <Widget>[
          const SizedBox(height: 72),
          StateFeedbackPlaceholder(
            icon: hasError
                ? Icons.cloud_off_rounded
                : isOffline
                    ? Icons.wifi_off_rounded
                    : Icons.video_library_outlined,
            title: title,
            message: message,
            actionLabel: hasError ? 'Повторить' : null,
            onAction: hasError
                ? () => ref.read(catalogControllerProvider.notifier).refresh()
                : null,
          ),
        ],
      );
    }

    final bool isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return ListView.builder(
      key: PageStorageKey<String>('catalog-list-${state.section.key}'),
      scrollCacheExtent: const ScrollCacheExtent.pixels(800),
      padding: ltListPadding(context, extraBottom: hasFab ? 96 : 16),
      itemCount: visibleItems.length,
      itemBuilder: (BuildContext context, int index) {
        final CatalogItem item = visibleItems[index];
        final bool shouldShowThumbnail = _supportsThumbnail(state.section);
        final bool canDownload = _supportsDownload(state.section);
        final DownloadItem? downloadItem = downloadsByVideoId[item.id];
        final bool isDownloaded = _isDownloaded(downloadItem);
        final double? watchedFraction = _resolveWatchedFraction(
          item: item,
          watchProgressByVideoId: watchProgressByVideoId,
        );
        final _ThumbnailSize thumbnailSize = _thumbnailSizeFor(
          isPortrait: isPortrait,
        );
        final String? thumbnailUrl =
            shouldShowThumbnail ? _buildThumbnailUrl(item.id) : null;

        final Widget listItem = isPortrait && shouldShowThumbnail
            ? PortraitVideoListItem(
                key: ValueKey<int>(item.id),
                localImagePath: thumbnailPathsById[item.id],
                imageUrl: thumbnailUrl,
                allowNetworkFallback: true,
                title: item.title,
                metadataLine: _buildPortraitMetadata(
                  item,
                  seasonNamesById: seasonNamesById,
                ),
                durationLabel: _formatCatalogDuration(item.raw),
                secondaryLine: _playlistMarker(
                  state.playlistAssignments[item.id],
                ),
                accentLine: watchProgressLabel(
                  watchedFraction,
                  _readDuration(item.raw),
                ),
                accentColor: watchProgressColor(context, watchedFraction),
                watchedFraction: watchedFraction,
                isDownloaded: isDownloaded,
                onTap: () => unawaited(_openPlayer(context, item)),
                // The swipe actions, also as a menu anyone can find.
                trailing: canDownload
                    ? _RowMenu(
                        isDownloaded: isDownloaded,
                        remoteActionsEnabled: !remoteActionsDisabled,
                        onDownload: () => _queueDownload(context, item),
                        onExportToJellyfin: () =>
                            unawaited(_exportToJellyfin(context, item)),
                        onDeleteLocal: () => unawaited(
                          _deleteFromDownloads(
                            context,
                            item,
                            section: state.section,
                          ),
                        ),
                        onDeleteEverywhere: () => unawaited(
                          _deleteEverywhere(
                            context,
                            item,
                            section: state.section,
                          ),
                        ),
                      )
                    : null,
              )
            : ListTile(
                key: ValueKey<int>(item.id),
                minLeadingWidth:
                    thumbnailUrl == null ? null : thumbnailSize.width,
                contentPadding: EdgeInsets.fromLTRB(
                  LtSizes.gutter,
                  4,
                  thumbnailUrl == null ? LtSizes.gutter : 4,
                  4,
                ),
                leading: thumbnailUrl == null
                    ? null
                    : VideoThumbnail(
                        imageUrl: thumbnailUrl,
                        localImagePath: thumbnailPathsById[item.id],
                        allowNetworkFallback: true,
                        width: thumbnailSize.width,
                        height: thumbnailSize.height,
                        watchedFraction: watchedFraction,
                        isDownloaded: isDownloaded,
                      ),
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: isPortrait
                    ? null
                    : _buildLandscapeSubtitle(
                        item,
                        state.playlistAssignments[item.id],
                      ),
                onTap: () => unawaited(_openPlayer(context, item)),
                trailing: thumbnailUrl == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : isPortrait || !canDownload
                        ? null
                        : _LandscapeActions(
                            onDownload: () => _queueDownload(context, item),
                            onDeleteFromDownloads: () => unawaited(
                              _deleteFromDownloads(
                                context,
                                item,
                                section: state.section,
                              ),
                            ),
                            onDeleteEverywhere: () => unawaited(
                              _deleteEverywhere(context, item,
                                  section: state.section),
                            ),
                            onExportToJellyfin: () =>
                                unawaited(_exportToJellyfin(context, item)),
                            remoteActionsEnabled: !remoteActionsDisabled,
                          ),
              );

        if (!canDownload || !isPortrait) {
          return listItem;
        }

        final LtPalette palette = LtPalette.of(context);
        // Swipe right only downloads; Jellyfin lives in the row's ⋮ menu.
        final ActionPane? startActionPane = remoteActionsDisabled || isDownloaded
            ? null
            : ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.28,
                // A full swipe queues the download.
                dismissible: DismissiblePane(
                  onDismissed: () {},
                  closeOnCancel: true,
                  confirmDismiss: () async {
                    await _queueDownload(context, item);
                    return false;
                  },
                ),
                children: <Widget>[
                  SlidableAction(
                    onPressed: (_) => _queueDownload(context, item),
                    backgroundColor: palette.mint.strong,
                    foregroundColor: Colors.white,
                    icon: Icons.download_rounded,
                    label: 'Скачать',
                  ),
                ],
              );

        final ActionPane? endActionPane =
            (remoteActionsDisabled && !isDownloaded)
                ? null
                : ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.28,
                    dismissible: DismissiblePane(
                      onDismissed: () {},
                      closeOnCancel: true,
                      confirmDismiss: () async {
                        if (isDownloaded) {
                          await _deleteFromDownloads(
                            context,
                            item,
                            section: state.section,
                          );
                        } else {
                          await _deleteEverywhere(
                            context,
                            item,
                            section: state.section,
                          );
                        }
                        return false;
                      },
                    ),
                    children: <Widget>[
                      SlidableAction(
                        onPressed: (_) => unawaited(
                          isDownloaded
                              ? _deleteFromDownloads(
                                  context,
                                  item,
                                  section: state.section,
                                )
                              : _deleteEverywhere(
                                  context,
                                  item,
                                  section: state.section,
                                ),
                        ),
                        backgroundColor: palette.danger.strong,
                        foregroundColor: Colors.white,
                        icon: Icons.delete_outline_rounded,
                        label: isDownloaded ? 'С телефона' : 'Удалить',
                      ),
                    ],
                  );

        return Slidable(
          key:
              ValueKey<String>('catalog-slide-${state.section.key}-${item.id}'),
          startActionPane: startActionPane,
          endActionPane: endActionPane,
          child: listItem,
        );
      },
    );
  }

  String? _playlistMarker(String? playlistName) {
    final String name = (playlistName ?? '').trim();
    return name.isEmpty ? null : 'В плейлисте «$name»';
  }

  Future<void> _downloadTopN(BuildContext context, {required int count}) async {
    final int queued =
        await ref.read(catalogControllerProvider.notifier).downloadTopN(count);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          queued > 0
              ? 'Поставлено на скачивание: $queued'
              : 'Нечего ставить на скачивание',
        ),
      ),
    );
  }

  Future<void> _queueDownload(BuildContext context, CatalogItem item) async {
    final failure = await ref.read(catalogControllerProvider.notifier).download(
          item,
        );
    if (!context.mounted) {
      return;
    }
    _showResult(context, failure, successMessage: 'Поставлено на скачивание');
  }

  Future<void> _exportToJellyfin(BuildContext context, CatalogItem item) async {
    final (String? message, Failure? failure) = await ref
        .read(catalogControllerProvider.notifier)
        .exportToJellyfin(item);
    if (!context.mounted) {
      return;
    }
    _showResult(
      context,
      failure,
      successMessage: message ?? 'Добавлено в Jellyfin',
    );
  }

  Future<bool> _deleteFromDownloads(
    BuildContext context,
    CatalogItem item, {
    CatalogSection? section,
  }) async {
    final Failure? failure =
        await ref.read(catalogControllerProvider.notifier).deleteLocal(item);
    if (!context.mounted) {
      return false;
    }
    _showResult(context, failure, successMessage: 'Удалено с телефона');
    final bool isSuccess = failure == null;
    if (isSuccess && section != null) {
      _markItemAsRemoved(section, item.id);
    }
    return isSuccess;
  }

  Future<bool> _deleteEverywhere(
    BuildContext context,
    CatalogItem item, {
    CatalogSection? section,
  }) async {
    // Deleting from the server cannot be undone, and a swipe is easy to make by accident.
    final bool confirmed = await ltConfirm(
      context,
      title: 'Удалить видео с сервера?',
      message: '«${item.title}» исчезнет из библиотеки на всех устройствах.',
      confirmLabel: 'Удалить',
      confirmKey: const Key('catalog-delete-confirm'),
    );
    if (!confirmed || !context.mounted) {
      return false;
    }
    final CatalogController controller = ref.read(
      catalogControllerProvider.notifier,
    );
    final Failure? serverFailure = await controller.deleteServer(item);
    if (!context.mounted) {
      return false;
    }
    if (serverFailure != null) {
      _showResult(context, serverFailure, successMessage: '');
      return false;
    }
    final Failure? localFailure = await controller.deleteLocal(item);
    if (!context.mounted) {
      return false;
    }
    if (localFailure != null) {
      _showResult(context, localFailure, successMessage: '');
      return false;
    }
    _showResult(
      context,
      null,
      successMessage: 'Удалено с сервера и с телефона',
    );
    if (section != null) {
      _markItemAsRemoved(section, item.id);
    }
    return true;
  }

  void _showResult(
    BuildContext context,
    Failure? failure, {
    required String successMessage,
  }) {
    final String message = failure == null ? successMessage : failure.message;
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget? _buildLandscapeSubtitle(CatalogItem item, String? playlistName) {
    final String description = item.description.trim();
    if (playlistName == null || playlistName.trim().isEmpty) {
      if (description.isEmpty) {
        return null;
      }
      return Text(
        description,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }
    final String marker = 'В плейлисте «${playlistName.trim()}»';
    if (description.isEmpty) {
      return Text(
        marker,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      '$description\n$marker',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<CatalogItem> _buildVisibleItems({
    required CatalogState state,
  }) {
    final Set<int> locallyRemovedIds =
        _locallyRemovedIdsBySection[state.section] ?? const <int>{};
    return state.items.where((CatalogItem item) {
      if (locallyRemovedIds.contains(item.id)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  void _markItemAsRemoved(CatalogSection section, int itemId) {
    setState(() {
      final Set<int> removedIds = _locallyRemovedIdsBySection.putIfAbsent(
        section,
        () => <int>{},
      );
      removedIds.add(itemId);
    });
  }

  bool _isDownloaded(DownloadItem? item) {
    return item != null && item.status == DownloadStatus.completed;
  }

  String _buildPortraitMetadata(
    CatalogItem item, {
    required Map<int, String> seasonNamesById,
  }) {
    String seasonName = _readRawString(
      item.raw,
      const <String>[
        'seasonName',
        'SeasonName',
        'season',
        'Season',
      ],
    );
    if (seasonName.isEmpty) {
      final int? seasonId = _readRawInt(
        item.raw,
        const <String>['seasonId', 'SeasonId'],
      );
      if (seasonId != null) {
        seasonName = seasonNamesById[seasonId] ?? '';
      }
    }
    final String seriesName = _readRawString(
      item.raw,
      const <String>['seriesName', 'SeriesName', 'serieName', 'SerieName'],
    );
    // A title such as «Фиксики — Пылесос» already names its series.
    final bool titleNamesSeries = seriesName.isNotEmpty &&
        item.title.toLowerCase().startsWith(seriesName.toLowerCase());
    final List<String> parts = <String>[
      if (seriesName.isNotEmpty &&
          seriesName != seasonName &&
          !titleNamesSeries)
        seriesName,
      if (seasonName.isNotEmpty) seasonName,
    ];
    return parts.join(' · ');
  }

  double? _resolveWatchedFraction({
    required CatalogItem item,
    required Map<int, double> watchProgressByVideoId,
  }) {
    final double watchedSeconds = watchProgressByVideoId[item.id] ?? 0;
    if (watchedSeconds <= 0) {
      return null;
    }

    final Duration? duration = _readDuration(item.raw);
    if (duration == null) {
      return null;
    }

    final double durationSeconds = duration.inMilliseconds / 1000;
    if (durationSeconds <= 0) {
      return null;
    }

    final double normalized = watchedSeconds / durationSeconds;
    if (!normalized.isFinite) {
      return null;
    }
    final double fraction = normalized.clamp(0.0, 1.0).toDouble();
    if (fraction <= 0) {
      return null;
    }
    return fraction;
  }

  String _readRawString(Map<String, dynamic> raw, List<String> keys) {
    for (final String key in keys) {
      final Object? value = raw[key];
      if (value == null) {
        continue;
      }
      final String normalized = value.toString().trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  int? _readRawInt(Map<String, dynamic> raw, List<String> keys) {
    for (final String key in keys) {
      final int? value = _parseRawIntValue(raw[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  Duration? _readDuration(Map<String, dynamic> raw) {
    final Object? value = raw['duration'] ??
        raw['Duration'] ??
        raw['durationSeconds'] ??
        raw['DurationSeconds'];
    final Duration? duration = _tryParseDuration(value);
    if (duration == null || duration <= Duration.zero) {
      return null;
    }
    return duration;
  }

  Duration? _tryParseDuration(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return Duration(seconds: value.round());
    }

    final String raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    final bool isNegative = raw.startsWith('-');
    final String normalized = isNegative ? raw.substring(1) : raw;
    final List<String> parts = normalized.split(':');
    if (parts.length < 2) {
      return null;
    }

    int days = 0;
    String hoursPart = parts[0];
    if (hoursPart.contains('.')) {
      final List<String> dayAndHours = hoursPart.split('.');
      if (dayAndHours.length == 2) {
        days = int.tryParse(dayAndHours[0]) ?? 0;
        hoursPart = dayAndHours[1];
      }
    }

    final int? hours = int.tryParse(hoursPart);
    final int? minutes = int.tryParse(parts[1]);
    final String secondsAndFraction = parts.length > 2 ? parts[2] : '0';
    final List<String> secondsParts = secondsAndFraction.split('.');
    final int? seconds = int.tryParse(secondsParts[0]);

    if (hours == null || minutes == null || seconds == null) {
      return null;
    }

    int microseconds = 0;
    if (secondsParts.length > 1) {
      String fraction = secondsParts[1];
      if (fraction.length > 6) {
        fraction = fraction.substring(0, 6);
      }
      microseconds = int.tryParse(fraction.padRight(6, '0')) ?? 0;
    }

    Duration duration = Duration(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      microseconds: microseconds,
    );
    if (isNegative) {
      duration = -duration;
    }
    return duration;
  }

  String _formatCatalogDuration(Map<String, dynamic> raw) {
    final Duration? duration = _readDuration(raw);
    if (duration == null || duration <= Duration.zero) {
      return '';
    }

    final int totalSeconds = duration.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool _supportsThumbnail(CatalogSection section) {
    return _isVideoSection(section);
  }

  bool _supportsDownload(CatalogSection section) {
    return _isVideoSection(section);
  }

  bool _isVideoSection(CatalogSection section) {
    switch (section) {
      case CatalogSection.latest:
      case CatalogSection.fresh:
      case CatalogSection.history:
        return true;
      case CatalogSection.series:
      case CatalogSection.playlists:
        return false;
    }
  }

  String _buildThumbnailUrl(int videoId) {
    final Uri baseUri = Uri.parse(ref.read(appConfigProvider).apiBaseUrl);
    return baseUri
        .resolve('/api/files/getImage?fileId=$videoId&isMobile=true')
        .toString();
  }

  _ThumbnailSize _thumbnailSizeFor({required bool isPortrait}) {
    if (!isPortrait) {
      return const _ThumbnailSize(width: 84, height: 56);
    }
    const double imageHeight = 68;
    const double imageWidth = 46;
    return _ThumbnailSize(width: imageWidth, height: imageHeight);
  }

  Future<void> _openPlayer(BuildContext context, CatalogItem item) async {
    final String description = item.description.trim();
    final PlayerNavigationResult? result =
        await context.push<PlayerNavigationResult>(
      '${AppRoutes.player}/${item.id}',
      extra: <String, String>{
        'title': item.title,
        if (description.isNotEmpty) 'description': description,
      },
    );
    if (!context.mounted) {
      return;
    }
    showPlayerNavigationResultSnackBar(context, result);
  }
}

class _LandscapeActions extends StatelessWidget {
  const _LandscapeActions({
    required this.onDownload,
    required this.onDeleteFromDownloads,
    required this.onDeleteEverywhere,
    required this.onExportToJellyfin,
    required this.remoteActionsEnabled,
  });

  final VoidCallback onDownload;
  final VoidCallback onDeleteFromDownloads;
  final VoidCallback onDeleteEverywhere;
  final VoidCallback onExportToJellyfin;
  final bool remoteActionsEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: remoteActionsEnabled
              ? 'Скачать на устройство'
              : 'Доступно после подключения',
          onPressed: remoteActionsEnabled ? onDownload : null,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          splashRadius: 18,
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: 'Удалить с устройства',
          onPressed: onDeleteFromDownloads,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          splashRadius: 18,
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        IconButton(
          tooltip: remoteActionsEnabled
              ? 'Удалить отовсюду'
              : 'Доступно после подключения',
          onPressed: remoteActionsEnabled ? onDeleteEverywhere : null,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          splashRadius: 18,
          icon: const Icon(Icons.delete_forever_outlined),
        ),
        IconButton(
          tooltip: remoteActionsEnabled
              ? 'В Jellyfin'
              : 'Доступно после подключения',
          onPressed: remoteActionsEnabled ? onExportToJellyfin : null,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          splashRadius: 18,
          icon: const Icon(Icons.live_tv_outlined),
        ),
      ],
    );
  }
}

class _ThumbnailSize {
  const _ThumbnailSize({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;
}

/// The catalogue's sections as a row of chips under the title: one tap to
/// switch, all of them visible, instead of a drop-down to open first.
class _SectionChips extends StatelessWidget {
  const _SectionChips({required this.selected, required this.onSelected});

  final CatalogSection selected;
  final ValueChanged<CatalogSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // A fade at the right edge says the row scrolls on.
    return SizedBox(
      height: 56,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) => LinearGradient(
          colors: const <Color>[Colors.black, Colors.black, Colors.transparent],
          stops: <double>[0, 1 - 32 / bounds.width, 1],
        ).createShader(bounds),
        child: ListView.separated(
          key: const Key('catalog-section-chips'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(LtSizes.gutter, 4, 32, 12),
          itemCount: CatalogSection.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int index) {
            final CatalogSection section = CatalogSection.values[index];
            final bool isSelected = section == selected;
            return ChoiceChip(
              label: Text(_chipLabel(section)),
              selected: isSelected,
              onSelected: (_) {
                if (!isSelected) {
                  onSelected(section);
                }
              },
              selectedColor: LtColors.primary,
              // 40 dp drawn, as the website's chips.
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected ? Colors.white : colors.onSurface,
                  ),
            );
          },
        ),
      ),
    );
  }

  /// Short names, so the chips fit the phone's width.
  static String _chipLabel(CatalogSection section) {
    switch (section) {
      case CatalogSection.series:
        return 'Сериалы';
      case CatalogSection.playlists:
        return 'Плейлисты';
      case CatalogSection.latest:
      case CatalogSection.fresh:
      case CatalogSection.history:
        return section.title;
    }
  }
}

/// «⋮» at the end of a video row: what the swipes do, named.
class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.isDownloaded,
    required this.remoteActionsEnabled,
    required this.onDownload,
    required this.onExportToJellyfin,
    required this.onDeleteLocal,
    required this.onDeleteEverywhere,
  });

  final bool isDownloaded;
  final bool remoteActionsEnabled;
  final VoidCallback onDownload;
  final VoidCallback onExportToJellyfin;
  final VoidCallback onDeleteLocal;
  final VoidCallback onDeleteEverywhere;

  @override
  Widget build(BuildContext context) {
    final Color danger = LtPalette.of(context).danger.strong;
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Действия с видео',
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (VoidCallback action) => action(),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<VoidCallback>>[
        if (!isDownloaded)
          PopupMenuItem<VoidCallback>(
            value: onDownload,
            enabled: remoteActionsEnabled,
            child: const ListTile(
              leading: Icon(Icons.download_rounded),
              title: Text('Скачать на телефон'),
            ),
          ),
        PopupMenuItem<VoidCallback>(
          value: onExportToJellyfin,
          enabled: remoteActionsEnabled,
          child: const ListTile(
            leading: Icon(Icons.live_tv_rounded),
            title: Text('Отправить в Jellyfin'),
          ),
        ),
        if (isDownloaded)
          PopupMenuItem<VoidCallback>(
            value: onDeleteLocal,
            child: const ListTile(
              leading: Icon(Icons.phonelink_erase_rounded),
              title: Text('Удалить с телефона'),
            ),
          ),
        PopupMenuItem<VoidCallback>(
          value: onDeleteEverywhere,
          enabled: remoteActionsEnabled,
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: danger),
            title: Text('Удалить с сервера', style: TextStyle(color: danger)),
          ),
        ),
      ],
    );
  }
}
