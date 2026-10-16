import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/video_list_item.dart';
import '../../downloads/data/offline_history_repository.dart';
import '../../player/presentation/player_navigation_result.dart';

final FutureProvider<List<OfflineHistoryItem>> offlineHistoryItemsProvider =
    FutureProvider<List<OfflineHistoryItem>>((Ref ref) async {
  return ref.read(offlineHistoryRepositoryProvider).listHistory();
});

class OfflineHistoryPage extends ConsumerWidget {
  const OfflineHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<OfflineHistoryItem>> history =
        ref.watch(offlineHistoryItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(offlineHistoryItemsProvider);
          await ref.read(offlineHistoryItemsProvider.future);
        },
        child: history.when(
          data: (List<OfflineHistoryItem> items) {
            if (items.isEmpty) {
              return ListView(
                children: const <Widget>[
                  SizedBox(height: 120),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No local watch history yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final OfflineHistoryItem item = items[index];
                return _OfflineHistoryTile(item: item);
              },
            );
          },
          loading: () => ListView(
            children: const <Widget>[
              SizedBox(height: 140),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (Object error, StackTrace stackTrace) => ListView(
            children: <Widget>[
              const SizedBox(height: 120),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: <Widget>[
                      Text(
                        'Unable to load offline history: $error',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(offlineHistoryItemsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineHistoryTile extends ConsumerWidget {
  const _OfflineHistoryTile({required this.item});

  final OfflineHistoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Uri baseUri = Uri.parse(ref.read(appConfigProvider).apiBaseUrl);
    final String networkUrl = baseUri
        .resolve('/api/files/getImage?fileId=${item.videoId}&isMobile=true')
        .toString();
    final bool isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    final Widget content = isPortrait
        ? Opacity(
            opacity: item.isPlayableOffline ? 1 : 0.6,
            child: PortraitVideoListItem(
              localImagePath: item.thumbnailLocalPath,
              imageUrl: networkUrl,
              allowNetworkFallback: false,
              title: item.title,
              metadataLine: _buildMetadataLine(),
              watchedFraction: _resolveWatchedFraction(),
              isDownloaded: item.isPlayableOffline,
              onTap: () => unawaited(_handleTap(context)),
            ),
          )
        : ListTile(
            enabled: item.isPlayableOffline,
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            leading: VideoThumbnail(
              width: 84,
              height: 56,
              localImagePath: item.thumbnailLocalPath,
              imageUrl: networkUrl,
              allowNetworkFallback: false,
              watchedFraction: _resolveWatchedFraction(),
              isDownloaded: item.isPlayableOffline,
            ),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _buildSubtitle(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: item.isPlayableOffline
                ? const Icon(Icons.play_circle_outline)
                : const Icon(Icons.cloud_off_outlined),
            onTap: () => unawaited(_handleTap(context)),
          );

    return content;
  }

  String _buildSubtitle() {
    final List<String> parts = <String>[
      if ((item.seasonName ?? '').trim().isNotEmpty) item.seasonName!.trim(),
      if ((item.durationSeconds ?? 0) > 0)
        _formatDuration(item.durationSeconds!),
      'Last watched ${_formatDate(item.lastWatchedAt)}',
      'Position ${_formatPosition(item.positionSeconds)}',
      if (!item.isPlayableOffline) 'Not downloaded',
    ];
    return parts.join(' | ');
  }

  String _buildMetadataLine() {
    final List<String> parts = <String>[
      if ((item.seasonName ?? '').trim().isNotEmpty) item.seasonName!.trim(),
      if ((item.durationSeconds ?? 0) > 0)
        _formatDuration(item.durationSeconds!),
      'Pos ${_formatPosition(item.positionSeconds)}',
      if (!item.isPlayableOffline) 'Not downloaded',
    ];
    return parts.isEmpty ? '-' : parts.join(' | ');
  }

  double? _resolveWatchedFraction() {
    final int? durationSeconds = item.durationSeconds;
    if (durationSeconds == null || durationSeconds <= 0) {
      return null;
    }
    final double fraction =
        (item.positionSeconds <= 0 ? 0 : item.positionSeconds / durationSeconds)
            .clamp(0.0, 1.0)
            .toDouble();
    return fraction <= 0 ? null : fraction;
  }

  Future<void> _handleTap(BuildContext context) async {
    if (item.isPlayableOffline) {
      final PlayerNavigationResult? result =
          await context.push<PlayerNavigationResult>(
        '${AppRoutes.player}/${item.videoId}?position=${item.positionSeconds}',
        extra: <String, String>{
          'title': item.title,
          if (item.description.trim().isNotEmpty)
            'description': item.description.trim(),
        },
      );
      if (!context.mounted) {
        return;
      }
      showPlayerNavigationResultSnackBar(context, result);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This video is no longer available offline.'),
      ),
    );
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

  String _formatPosition(double secondsRaw) {
    final int totalSeconds = secondsRaw < 0 ? 0 : secondsRaw.round();
    return _formatDuration(totalSeconds);
  }

  String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}
