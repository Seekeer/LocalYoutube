import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../../shared/widgets/video_list_item.dart';
import '../../../shared/widgets/watch_progress.dart';
import '../../../app/theme/app_theme.dart';
import '../../downloads/data/offline_history_repository.dart';
import '../../downloads/presentation/downloads_controller.dart';
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
                  SizedBox(height: 96),
                  StateFeedbackPlaceholder(
                    icon: Icons.history_rounded,
                    title: 'История пуста',
                    message:
                        'Здесь появятся видео, которые вы смотрели на этом телефоне.',
                  ),
                ],
              );
            }
            // Newest first, under a heading per day.
            final List<OfflineHistoryItem> sorted =
                List<OfflineHistoryItem>.of(items)
                  ..sort(
                    (OfflineHistoryItem a, OfflineHistoryItem b) =>
                        b.lastWatchedAt.compareTo(a.lastWatchedAt),
                  );
            final List<Widget> rows = <Widget>[];
            String? day;
            for (final OfflineHistoryItem item in sorted) {
              final String itemDay = _dayLabel(item.lastWatchedAt);
              if (itemDay != day) {
                day = itemDay;
                rows.add(
                  LtSectionHeader(
                    itemDay,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  ),
                );
              }
              rows.add(_OfflineHistoryTile(item: item));
            }
            return ListView(
              padding: ltListPadding(context, top: 0),
              children: rows,
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
              const SizedBox(height: 96),
              StateFeedbackPlaceholder(
                icon: Icons.error_outline_rounded,
                title: 'Не удалось загрузить историю',
                message: '$error',
                actionLabel: 'Повторить',
                onAction: () => ref.invalidate(offlineHistoryItemsProvider),
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
        ? PortraitVideoListItem(
            localImagePath: item.thumbnailLocalPath,
            imageUrl: networkUrl,
            allowNetworkFallback: false,
            title: item.title,
            // Line 2 is where and when, line 3 the state, as in every list.
            metadataLine: <String>[
              if ((item.seasonName ?? '').trim().isNotEmpty)
                item.seasonName!.trim(),
              _buildWhenLine(),
            ].join(' · '),
            accentLine: item.isPlayableOffline
                ? watchProgressLabel(
                    _resolveWatchedFraction(),
                    (item.durationSeconds ?? 0) > 0
                        ? Duration(seconds: item.durationSeconds!)
                        : null,
                  )
                : 'Не скачано',
            accentIcon: item.isPlayableOffline ? null : Icons.cloud_off_rounded,
            accentColor:
                item.isPlayableOffline && _resolveWatchedFraction() != null
                    ? watchProgressColor(context, _resolveWatchedFraction())
                    : Theme.of(context).colorScheme.onSurfaceVariant,
            durationLabel: (item.durationSeconds ?? 0) > 0
                ? _formatDuration(item.durationSeconds!)
                : null,
            watchedFraction: _resolveWatchedFraction(),
            // Downloaded is the rule here; only the exception is marked.
            isDownloaded: false,
            dimmed: !item.isPlayableOffline,
            onTap: () => unawaited(_handleTap(context)),
            // The same «⋮» as the other lists; here it can only free the phone.
            trailing: PopupMenuButton<void>(
              tooltip: 'Действия с видео',
              enabled: item.isPlayableOffline,
              icon: Icon(
                Icons.more_vert_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
                PopupMenuItem<void>(
                  onTap: () async {
                    final ProviderContainer container =
                        ProviderScope.containerOf(context, listen: false);
                    await container
                        .read(downloadsControllerProvider.notifier)
                        .delete(item.videoId);
                    container.invalidate(offlineHistoryItemsProvider);
                  },
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
          )
        : ListTile(
            enabled: item.isPlayableOffline,
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
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
              <String>[
                _buildMetadataLine(),
                _dayLabel(item.lastWatchedAt),
                _buildWhenLine(),
              ].where((String s) => s.isNotEmpty).join(' · '),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: item.isPlayableOffline
                ? const Icon(Icons.play_circle_outline_rounded)
                : const Icon(Icons.cloud_off_rounded),
            onTap: () => unawaited(_handleTap(context)),
          );

    return content;
  }

  String _buildMetadataLine() {
    final List<String> parts = <String>[
      if ((item.seasonName ?? '').trim().isNotEmpty) item.seasonName!.trim(),
      if (!item.isPlayableOffline) 'не скачано',
    ];
    return parts.join(' · ');
  }

  /// «в 16:30».
  String _buildWhenLine() {
    final DateTime local = item.lastWatchedAt.toLocal();
    return 'в ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
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
        content: Text('Этого видео больше нет на телефоне.'),
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
}

const List<String> _months = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// «Сегодня», «Вчера» or «12 ноября» (with the year when it is not this one).
String _dayLabel(DateTime value) {
  final DateTime local = value.toLocal();
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime day = DateTime(local.year, local.month, local.day);
  final int daysAgo = today.difference(day).inDays;
  if (daysAgo == 0) {
    return 'Сегодня';
  }
  if (daysAgo == 1) {
    return 'Вчера';
  }
  final String year = local.year == now.year ? '' : ' ${local.year}';
  return '${local.day} ${_months[local.month - 1]}$year';
}
