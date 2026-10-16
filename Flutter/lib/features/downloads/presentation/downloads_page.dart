import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/network/network_status.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../../shared/widgets/video_list_item.dart';
import '../../catalog/data/local_video_metadata_repository.dart';
import '../../player/presentation/player_navigation_result.dart';
import '../domain/download_models.dart';
import 'downloads_controller.dart';

final downloadMetadataProvider =
    FutureProvider.family<LocalVideoMetadata?, int>(
        (Ref ref, int videoId) async {
  return ref.read(localVideoMetadataRepositoryProvider).findByVideoId(videoId);
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
    final bool useOfflinePlayback = ref.watch(effectiveAutonomousModeProvider);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(showCompletedOnly
            ? '\u0421\u043a\u0430\u0447\u0430\u043d\u043d\u043e\u0435'
            : '\u0421\u043a\u0430\u0447\u0438\u0432\u0430\u0435\u043c\u043e\u0435'),
        actions: <Widget>[
          if (showCompletedOnly) ...<Widget>[
            const Center(
              child: Text(
                '\u0410\u0432\u0442\u043e\u043d\u043e\u043c\u043d\u043e',
              ),
            ),
            Switch(
              key: const Key('autonomous-mode-switch'),
              value: useOfflinePlayback,
              onChanged: isOffline
                  ? null
                  : (bool value) {
                      ref.read(manualAutonomousModeProvider.notifier).state =
                          value;
                    },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Column(
        children: <Widget>[
          if (isOffline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: StateFeedbackBanner(
                message:
                    'Offline mode: active downloads will resume on network.',
                tone: StateFeedbackTone.warning,
              ),
            ),
          if (state.errorMessage != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        child: StateFeedbackPlaceholder(
          icon: hasError
              ? Icons.error_outline
              : isOffline
                  ? Icons.cloud_off_outlined
                  : Icons.download_done_outlined,
          title: hasError
              ? 'Unable to load downloads'
              : isOffline
                  ? 'Offline mode'
                  : showCompletedOnly
                      ? 'No downloaded files yet'
                      : 'No downloads yet',
          message: hasError
              ? state.errorMessage!
              : isOffline
                  ? 'Downloaded videos will appear here when available locally.'
                  : showCompletedOnly
                      ? 'Completed local files will appear here.'
                      : 'Queue downloads from Home to see progress here.',
          actionLabel: hasError ? 'Retry' : null,
          onAction: hasError
              ? () => ref.read(downloadsControllerProvider.notifier).reload()
              : null,
        ),
      );
    }

    return ListView.separated(
      key: const PageStorageKey<String>('downloads-list'),
      scrollCacheExtent: const ScrollCacheExtent.pixels(700),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
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
            return _ActiveDownloadTile(item: item, metadata: metadata);
          },
        );
      },
    );
  }
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
    final Uri baseUri = Uri.parse(ref.read(appConfigProvider).apiBaseUrl);
    final String thumbnailUrl = baseUri
        .resolve('/api/files/getImage?fileId=${item.videoId}&isMobile=true')
        .toString();
    final String title = _resolveTitle(item, metadata);
    final String metadataLine = _buildMetadataLine(metadata);
    final bool isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    final Widget content = isPortrait
        ? PortraitVideoListItem(
            key: ValueKey<int>(item.videoId),
            localImagePath: metadata?.thumbnailLocalPath,
            imageUrl: thumbnailUrl,
            allowNetworkFallback: allowNetworkFallback,
            title: title,
            metadataLine: metadataLine,
            watchedFraction: null,
            isDownloaded: true,
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
              metadataLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _openPlayer(context, ref, item, metadata),
          );

    return Slidable(
      key: ValueKey<String>('downloads-completed-slide-${item.videoId}'),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
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
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_sweep_outlined,
            label:
                '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u0438\u0437 \u0441\u043a\u0430\u0447\u0430\u043d\u043d\u044b\u0445',
          ),
        ],
      ),
      child: content,
    );
  }

  String _resolveTitle(DownloadItem item, LocalVideoMetadata? metadata) {
    final String title = metadata?.title.trim() ?? item.title?.trim() ?? '';
    return title.isNotEmpty ? title : 'Video #${item.videoId}';
  }

  String _buildMetadataLine(LocalVideoMetadata? metadata) {
    if (metadata == null) {
      return '-';
    }
    final List<String> parts = <String>[
      if ((metadata.seasonName ?? '').trim().isNotEmpty)
        metadata.seasonName!.trim(),
      if ((metadata.durationSeconds ?? 0) > 0)
        _formatDuration(metadata.durationSeconds!),
    ];
    return parts.isEmpty ? '-' : parts.join(' | ');
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

class _ActiveDownloadTile extends ConsumerWidget {
  const _ActiveDownloadTile({
    required this.item,
    required this.metadata,
  });

  final DownloadItem item;
  final LocalVideoMetadata? metadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String title = _resolveTitle();
    final String description = (metadata?.description ?? '').trim();
    final String transferInfo = _transferInfoLabel(item);
    final double? progressValue =
        item.status == DownloadStatus.queued && item.progress <= 0
            ? null
            : item.progress;

    return ListTile(
      key: ValueKey<int>(item.videoId),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (description.isNotEmpty) ...<Widget>[
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          Text(_statusLabel(item)),
          if (transferInfo.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(transferInfo),
          ],
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progressValue),
          const SizedBox(height: 4),
          Text(_progressLabel(item)),
        ],
      ),
      onTap: item.status == DownloadStatus.completed
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
      trailing: Wrap(
        spacing: 4,
        children: _buildActions(ref),
      ),
    );
  }

  String _resolveTitle() {
    final String title = metadata?.title.trim() ?? item.title?.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }
    return 'Video #${item.videoId}';
  }

  List<Widget> _buildActions(WidgetRef ref) {
    final DownloadsController controller =
        ref.read(downloadsControllerProvider.notifier);

    switch (item.status) {
      case DownloadStatus.queued:
      case DownloadStatus.downloading:
        return <Widget>[
          IconButton(
            tooltip: 'Pause',
            onPressed: () => controller.pause(item.videoId),
            icon: const Icon(Icons.pause),
          ),
          IconButton(
            tooltip: 'Stop',
            onPressed: () => controller.stop(item.videoId),
            icon: const Icon(Icons.stop),
          ),
        ];
      case DownloadStatus.paused:
        return <Widget>[
          IconButton(
            tooltip: 'Resume',
            onPressed: () => controller.resume(item.videoId),
            icon: const Icon(Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Delete local',
            onPressed: () => controller.delete(item.videoId),
            icon: const Icon(Icons.delete_outline),
          ),
        ];
      case DownloadStatus.completed:
      case DownloadStatus.damaged:
      case DownloadStatus.failed:
        return <Widget>[
          IconButton(
            tooltip:
                item.status == DownloadStatus.failed ? 'Retry' : 'Redownload',
            onPressed: () => controller.resume(item.videoId),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Delete local',
            onPressed: () => controller.delete(item.videoId),
            icon: const Icon(Icons.delete_outline),
          ),
        ];
    }
  }

  String _statusLabel(DownloadItem item) {
    switch (item.status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return item.localPath == null
            ? 'Completed'
            : 'Completed: ${item.localPath}';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.damaged:
        return 'Downloaded video is damaged. Download it again.';
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
    if (speedLabel.isEmpty && etaLabel.isEmpty) {
      return '';
    }
    if (speedLabel.isNotEmpty && etaLabel.isNotEmpty) {
      return 'Speed: $speedLabel | ETA: $etaLabel';
    }
    if (speedLabel.isNotEmpty) {
      return 'Speed: $speedLabel';
    }
    return 'ETA: $etaLabel';
  }

  String _formatSpeed(double? speedMbps) {
    if (speedMbps == null || speedMbps.isNaN || speedMbps <= 0) {
      return '';
    }
    if (speedMbps >= 1) {
      return '${speedMbps.toStringAsFixed(2)} MB/s';
    }
    return '${(speedMbps * 1000).toStringAsFixed(0)} kB/s';
  }

  String _formatEta(Duration? eta) {
    if (eta == null || eta.isNegative) {
      return '';
    }
    final int totalSeconds = eta.inSeconds;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
