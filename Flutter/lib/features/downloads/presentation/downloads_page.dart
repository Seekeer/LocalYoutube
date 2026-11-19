import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/network/network_status.dart';
import '../../../shared/widgets/autonomous_mode_card.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../../shared/widgets/video_list_item.dart';
import '../../../shared/widgets/watch_progress.dart';
import '../../player/data/local_playback_repository.dart';
import '../../catalog/data/local_video_metadata_repository.dart';
import '../../player/presentation/player_navigation_result.dart';
import '../domain/download_models.dart';
import 'downloads_controller.dart';

final downloadMetadataProvider =
    FutureProvider.family<LocalVideoMetadata?, int>(
        (Ref ref, int videoId) async {
  return ref.read(localVideoMetadataRepositoryProvider).findByVideoId(videoId);
});

/// How far each video was watched on this phone, in seconds.
final AutoDisposeFutureProvider<Map<int, double>> _watchedSecondsProvider =
    FutureProvider.autoDispose<Map<int, double>>((Ref ref) async {
  try {
    final List<PlaybackPositionSnapshot> snapshots =
        await ref.read(localPlaybackRepositoryProvider).listRecent(limit: 1000);
    return <int, double>{
      for (final PlaybackPositionSnapshot s in snapshots)
        s.videoId: s.positionSeconds,
    };
  } catch (_) {
    return const <int, double>{};
  }
});

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({
    super.key,
    this.showCompletedOnly = false,
  });

  final bool showCompletedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DownloadsState state = ref.watch(downloadsControllerProvider);
    final bool isOffline = ref.watch(networkStatusProvider).maybeWhen(
          data: (NetworkStatus status) => status == NetworkStatus.offline,
          orElse: () => false,
        );
    final bool isOfflineFallback =
        ref.watch(authNotifierProvider).isOfflineFallback;
    final List<DownloadItem> visibleItems = showCompletedOnly
        ? state.items
            .where((DownloadItem item) =>
                item.status == DownloadStatus.completed ||
                item.status == DownloadStatus.damaged)
            .toList(growable: false)
        : state.items
            .where(
                (DownloadItem item) => item.status != DownloadStatus.completed)
            .toList(growable: false);

    final List<DownloadItem> active = visibleItems
        .where((DownloadItem item) => item.status.isActive)
        .toList(growable: false);
    final int downloading = visibleItems
        .where((DownloadItem i) => i.status == DownloadStatus.downloading)
        .length;
    final int waiting = visibleItems
        .where((DownloadItem i) => i.status == DownloadStatus.queued)
        .length;
    final int paused = visibleItems
        .where((DownloadItem i) => i.status == DownloadStatus.paused)
        .length;

    return Scaffold(
      // The screen's main switch sits where the thumb is.
      bottomNavigationBar: showCompletedOnly
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: const AutonomousModeCard(),
              ),
            )
          : null,
      appBar: AppBar(
        title: Text(showCompletedOnly ? 'Скачанное' : 'Загрузки'),
        actions: <Widget>[
          if (!showCompletedOnly && active.isNotEmpty)
            TextButton(
              key: const Key('downloads-pause-all'),
              // The text ends on the 16 dp edge, like the discs below.
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 12),
                minimumSize: const Size(48, 48),
              ),
              onPressed: () {
                final DownloadsController controller =
                    ref.read(downloadsControllerProvider.notifier);
                for (final DownloadItem item in active) {
                  controller.pause(item.videoId);
                }
              },
              child: const Text('Приостановить все'),
            )
          else if (!showCompletedOnly && paused > 0)
            TextButton(
              key: const Key('downloads-resume-all'),
              // The text ends on the 16 dp edge, like the discs below.
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 12),
                minimumSize: const Size(48, 48),
              ),
              onPressed: () {
                final DownloadsController controller =
                    ref.read(downloadsControllerProvider.notifier);
                for (final DownloadItem item in visibleItems) {
                  if (item.status == DownloadStatus.paused) {
                    controller.resume(item.videoId);
                  }
                }
              },
              child: const Text('Продолжить все'),
            ),
          const SizedBox(width: LtSizes.gutter),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (showCompletedOnly && visibleItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _videoCountLabel(visibleItems.length),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          if (!showCompletedOnly && visibleItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      <String>[
                        if (downloading > 0) '$downloading\u00a0скачивается',
                        if (waiting > 0) '$waiting\u00a0в\u00a0очереди',
                        if (paused > 0) '$paused\u00a0на\u00a0паузе',
                      ].join(' ·\u00a0'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          if (isOffline)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: StateFeedbackBanner(
                message: showCompletedOnly
                    ? 'Нет сети — скачанное смотрится как обычно.'
                    : 'Нет сети — загрузки продолжатся, когда она появится.',
                tone: StateFeedbackTone.warning,
              ),
            ),
          if (state.errorMessage != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: StateFeedbackBanner(
                message: state.errorMessage!,
                tone: StateFeedbackTone.error,
              ),
            ),
          Expanded(
            child: _DownloadsList(
              state: state.copyWith(items: visibleItems),
              isOffline: isOffline,
              isOfflineFallback: isOfflineFallback,
              showCompletedOnly: showCompletedOnly,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsList extends ConsumerWidget {
  const _DownloadsList({
    required this.state,
    required this.isOffline,
    required this.isOfflineFallback,
    required this.showCompletedOnly,
  });

  final DownloadsState state;
  final bool isOffline;
  final bool isOfflineFallback;
  final bool showCompletedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      final bool hasError = state.errorMessage != null;
      return Center(
        child: SingleChildScrollView(
          child: StateFeedbackPlaceholder(
            icon: hasError
                ? Icons.error_outline_rounded
                : showCompletedOnly
                    ? Icons.download_done_rounded
                    : Icons.downloading_rounded,
            title: hasError
                ? 'Не удалось загрузить список'
                : showCompletedOnly
                    ? 'На телефоне пока ничего нет'
                    : 'Очередь пуста',
            message: hasError
                ? state.errorMessage!
                : showCompletedOnly
                    ? 'Скачайте видео из списка — потяните его строку вправо или нажмите «Скачать» в плеере.'
                    : 'Здесь появятся видео, которые скачиваются на телефон.',
            actionLabel: hasError ? 'Повторить' : null,
            onAction: hasError
                ? () => ref.read(downloadsControllerProvider.notifier).reload()
                : null,
          ),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey<String>('downloads-list'),
      scrollCacheExtent: const ScrollCacheExtent.pixels(700),
      padding: ltListPadding(context, top: 4),
      itemCount: state.items.length,
      itemBuilder: (BuildContext context, int index) {
        final DownloadItem item = state.items[index];
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final LocalVideoMetadata? metadata =
                ref.watch(downloadMetadataProvider(item.videoId)).valueOrNull;
            if (showCompletedOnly && item.status == DownloadStatus.completed) {
              return _CompletedDownloadTile(
                item: item,
                metadata: metadata,
                allowNetworkFallback: !isOfflineFallback,
              );
            }
            return _ActiveDownloadTile(
              item: item,
              metadata: metadata,
              allowNetworkFallback: !isOfflineFallback,
            );
          },
        );
      },
    );
  }
}

String _thumbnailUrl(WidgetRef ref, int videoId) {
  final Uri baseUri = Uri.parse(ref.read(appConfigProvider).apiBaseUrl);
  return baseUri
      .resolve('/api/files/getImage?fileId=$videoId&isMobile=true')
      .toString();
}

String _formatDuration(int totalSeconds) {
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _CompletedDownloadTile extends ConsumerWidget {
  const _CompletedDownloadTile({
    required this.item,
    required this.metadata,
    required this.allowNetworkFallback,
  });

  final DownloadItem item;
  final LocalVideoMetadata? metadata;
  final bool allowNetworkFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DownloadsController controller =
        ref.read(downloadsControllerProvider.notifier);
    final String thumbnailUrl = _thumbnailUrl(ref, item.videoId);
    final String title = _resolveTitle(item, metadata);
    final bool isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final int durationSeconds = metadata?.durationSeconds ?? 0;
    final double watchedSeconds =
        ref.watch(_watchedSecondsProvider).valueOrNull?[item.videoId] ?? 0;
    final double? watchedFraction = durationSeconds > 0 && watchedSeconds > 0
        ? (watchedSeconds / durationSeconds).clamp(0.0, 1.0).toDouble()
        : null;

    final Widget content = isPortrait
        ? PortraitVideoListItem(
            key: ValueKey<int>(item.videoId),
            localImagePath: metadata?.thumbnailLocalPath,
            imageUrl: thumbnailUrl,
            allowNetworkFallback: allowNetworkFallback,
            title: title,
            metadataLine: (metadata?.seasonName ?? '').trim(),
            durationLabel:
                durationSeconds > 0 ? _formatDuration(durationSeconds) : null,
            watchedFraction: watchedFraction,
            accentLine: watchProgressLabel(
              watchedFraction,
              durationSeconds > 0 ? Duration(seconds: durationSeconds) : null,
            ),
            accentColor: watchProgressColor(context, watchedFraction),
            // Everything here is on the phone; a mark on every row says nothing.
            isDownloaded: false,
            trailing: PopupMenuButton<void>(
              tooltip: 'Действия с видео',
              icon: Icon(
                Icons.more_vert_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
                PopupMenuItem<void>(
                  onTap: () => controller.delete(item.videoId),
                  child: ListTile(
                    leading: Icon(
                      Icons.phonelink_erase_rounded,
                      color: LtPalette.of(context).danger.strong,
                    ),
                    title: Text(
                      'Удалить с телефона',
                      style: TextStyle(
                        color: LtPalette.of(context).danger.strong,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => _openPlayer(context, ref, item, metadata),
          )
        : ListTile(
            key: ValueKey<int>(item.videoId),
            leading: VideoThumbnail(
              width: 84,
              height: 56,
              localImagePath: metadata?.thumbnailLocalPath,
              imageUrl: thumbnailUrl,
              allowNetworkFallback: allowNetworkFallback,
              watchedFraction: null,
              isDownloaded: true,
            ),
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _buildMetadataLine(metadata),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _openPlayer(context, ref, item, metadata),
          );

    return Slidable(
      key: ValueKey<String>('downloads-completed-slide-${item.videoId}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.32,
        dismissible: DismissiblePane(
          onDismissed: () {},
          closeOnCancel: true,
          confirmDismiss: () async {
            await controller.delete(item.videoId);
            return false;
          },
        ),
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => controller.delete(item.videoId),
            backgroundColor: LtPalette.of(context).danger.strong,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Удалить с телефона',
          ),
        ],
      ),
      child: content,
    );
  }

  String _resolveTitle(DownloadItem item, LocalVideoMetadata? metadata) {
    final String title = metadata?.title.trim() ?? item.title?.trim() ?? '';
    return title.isNotEmpty ? title : 'Видео №${item.videoId}';
  }

  String _buildMetadataLine(LocalVideoMetadata? metadata) {
    if (metadata == null) {
      return '';
    }
    final List<String> parts = <String>[
      if ((metadata.seasonName ?? '').trim().isNotEmpty)
        metadata.seasonName!.trim(),
      if ((metadata.durationSeconds ?? 0) > 0)
        _formatDuration(metadata.durationSeconds!),
    ];
    return parts.join(' · ');
  }

  Future<void> _openPlayer(
    BuildContext context,
    WidgetRef ref,
    DownloadItem item,
    LocalVideoMetadata? metadata,
  ) async {
    final PlayerNavigationResult? result =
        await context.push<PlayerNavigationResult>(
      '${AppRoutes.player}/${item.videoId}',
      extra: <String, String>{
        'title': _resolveTitle(item, metadata),
        if ((metadata?.description ?? '').trim().isNotEmpty)
          'description': metadata!.description.trim(),
      },
    );
    if (!context.mounted) {
      return;
    }
    showPlayerNavigationResultSnackBar(context, result);
    await ref.read(downloadsControllerProvider.notifier).reload();
  }
}

/// A download in progress, waiting, paused or broken: its cover, a status in
/// colour, the progress bar with speed and time left, and what can be done.
class _ActiveDownloadTile extends ConsumerWidget {
  const _ActiveDownloadTile({
    required this.item,
    required this.metadata,
    required this.allowNetworkFallback,
  });

  final DownloadItem item;
  final LocalVideoMetadata? metadata;
  final bool allowNetworkFallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final TextTheme text = theme.textTheme;
    final String title = _resolveTitle();
    final String transferInfo = _transferInfoLabel(item);
    final bool waiting =
        item.status == DownloadStatus.queued && item.progress <= 0;
    final double? progressValue = waiting ? null : item.progress;
    final (String statusLabel, Color statusColor) = _status(context, item);
    final bool openable = item.status == DownloadStatus.completed;

    final bool dark = theme.brightness == Brightness.dark;
    // A paused bar is clearly duller than a running one, in both themes.
    final Color barColor = item.status == DownloadStatus.paused
        ? (dark ? const Color(0xFF6B7192) : LtColors.subtle)
        : statusColor;

    return InkWell(
      key: ValueKey<int>(item.videoId),
      onTap: openable
          ? () => unawaited(
                context
                    .push<PlayerNavigationResult>(
                  '${AppRoutes.player}/${item.videoId}',
                )
                    .then((PlayerNavigationResult? result) {
                  if (!context.mounted) {
                    return;
                  }
                  showPlayerNavigationResultSnackBar(context, result);
                  unawaited(
                    ref.read(downloadsControllerProvider.notifier).reload(),
                  );
                }),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(LtSizes.gutter, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                VideoCover(
                  width: 112,
                  localImagePath: metadata?.thumbnailLocalPath,
                  imageUrl: _thumbnailUrl(ref, item.videoId),
                  allowNetworkFallback: allowNetworkFallback,
                  watchedFraction: null,
                  isDownloaded: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        keepShortWordsTogether(title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: text.labelMedium?.copyWith(color: statusColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                ..._buildActions(context, ref),
              ],
            ),
            // The progress runs under the whole row, the controls included.
            if (!waiting) ...<Widget>[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                  color: barColor,
                  backgroundColor: dark
                      ? const Color(0xFF2A2E44)
                      : barColor.withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text(
                    _progressLabel(item),
                    style: text.labelMedium?.copyWith(
                      color: item.status == DownloadStatus.paused
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  if (transferInfo.isNotEmpty) ...<Widget>[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        transferInfo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _resolveTitle() {
    final String title = metadata?.title.trim() ?? item.title?.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }
    return 'Видео №${item.videoId}';
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    final DownloadsController controller =
        ref.read(downloadsControllerProvider.notifier);

    switch (item.status) {
      case DownloadStatus.queued:
        return <Widget>[
          IconButton.filledTonal(
            style: _queueDisc(context),
            tooltip: 'Остановить',
            onPressed: () => controller.stop(item.videoId),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
      case DownloadStatus.downloading:
        return <Widget>[
          IconButton.filledTonal(
            style: _queueDisc(context),
            tooltip: 'Пауза',
            onPressed: () => controller.pause(item.videoId),
            icon: const Icon(Icons.pause_rounded),
          ),
          IconButton.filledTonal(
            style: _queueDisc(context),
            tooltip: 'Остановить',
            onPressed: () => controller.stop(item.videoId),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
      case DownloadStatus.paused:
        return <Widget>[
          IconButton.filledTonal(
            style: _queueDisc(context),
            tooltip: 'Продолжить',
            onPressed: () => controller.resume(item.videoId),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton.filledTonal(
            style: _queueDisc(context),
            tooltip: 'Убрать загрузку',
            onPressed: () => controller.delete(item.videoId),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
      case DownloadStatus.completed:
      case DownloadStatus.damaged:
      case DownloadStatus.failed:
        return <Widget>[
          IconButton.filledTonal(
            style: _queueDisc(context),
            tooltip: item.status == DownloadStatus.failed
                ? 'Повторить'
                : 'Скачать заново',
            onPressed: () => controller.resume(item.videoId),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton.filledTonal(
            style: _queueDisc(context),
            tooltip: 'Убрать загрузку',
            onPressed: () => controller.delete(item.videoId),
            icon: const Icon(Icons.close_rounded),
          ),
        ];
    }
  }

  (String, Color) _status(BuildContext context, DownloadItem item) {
    final LtPalette palette = LtPalette.of(context);
    switch (item.status) {
      case DownloadStatus.queued:
        return (
          'В очереди',
          Theme.of(context).colorScheme.onSurfaceVariant,
        );
      case DownloadStatus.downloading:
        return ('Скачивается', palette.cobalt.strong);
      case DownloadStatus.paused:
        return ('На паузе', Theme.of(context).colorScheme.onSurfaceVariant);
      case DownloadStatus.completed:
        return ('Скачано', palette.mint.strong);
      case DownloadStatus.failed:
        return ('Не удалось скачать', palette.danger.strong);
      case DownloadStatus.damaged:
        return ('Файл повреждён — скачайте заново', palette.danger.strong);
    }
  }

  String _progressLabel(DownloadItem item) {
    final int percent =
        ((item.progress * 100).round().clamp(0, 100) as num).toInt();
    return '$percent%';
  }

  String _transferInfoLabel(DownloadItem item) {
    final String speedLabel = _formatSpeed(item.speedMbps);
    final String etaLabel = _formatEta(item.eta);
    return <String>[
      if (speedLabel.isNotEmpty) speedLabel,
      if (etaLabel.isNotEmpty) 'ещё $etaLabel',
    ].join(' · ');
  }

  String _formatSpeed(double? speedMbps) {
    if (speedMbps == null || speedMbps.isNaN || speedMbps <= 0) {
      return '';
    }
    if (speedMbps >= 1) {
      return '${speedMbps.toStringAsFixed(1).replaceAll('.', ',')} МБ/с';
    }
    return '${(speedMbps * 1000).toStringAsFixed(0)} КБ/с';
  }

  /// «≈1 мин», «≈2 ч 5 мин», «меньше минуты».
  String _formatEta(Duration? eta) {
    if (eta == null || eta.isNegative) {
      return '';
    }
    final int minutes = (eta.inSeconds / 60).round();
    if (minutes < 1) {
      return 'меньше минуты';
    }
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int rest = minutes % 60;
      return rest == 0 ? '≈$hours ч' : '≈$hours ч $rest мин';
    }
    return '≈$minutes мин';
  }
}

/// «4 видео» — the word does not change with the number.
String _videoCountLabel(int count) => '$count видео';

/// The queue's pause, resume and remove: the player's tinted 40 dp discs.
ButtonStyle _queueDisc(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  final bool dark = theme.brightness == Brightness.dark;
  return IconButton.styleFrom(
    fixedSize: const Size.square(40),
    minimumSize: const Size.square(40),
    backgroundColor:
        dark ? const Color(0xFF1E2446) : theme.colorScheme.primaryContainer,
    foregroundColor:
        dark ? const Color(0xFFC9CEFF) : theme.colorScheme.onPrimaryContainer,
  );
}
