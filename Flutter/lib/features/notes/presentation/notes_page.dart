import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../../shared/widgets/video_list_item.dart';
import '../../catalog/data/local_video_metadata_repository.dart';
import '../../player/presentation/player_navigation_result.dart';
import '../data/notes_repository.dart';
import '../domain/notes_models.dart';

/// The «Заметки» screen: the Triage Queue plus videos with local Drafts, as a
/// vertical list that a mouse wheel scrolls as well as a finger.
/// The server's cover for a video, or null without a configured server.
String? _coverUrl(WidgetRef ref, int videoId) {
  try {
    return Uri.parse(ref.read(appConfigProvider).apiBaseUrl)
        .resolve('/api/files/getImage?fileId=$videoId&isMobile=true')
        .toString();
  } catch (_) {
    return null;
  }
}

/// A note's cover and length from the phone's catalogue cache, when it has
/// them.
final AutoDisposeFutureProviderFamily<LocalVideoMetadata?, int>
    _noteMetadataProvider = FutureProvider.autoDispose
        .family<LocalVideoMetadata?, int>((Ref ref, int videoId) async {
  try {
    return await ref
        .read(localVideoMetadataRepositoryProvider)
        .findByVideoId(videoId);
  } catch (_) {
    return null;
  }
});

String? _lengthLabel(int? seconds) {
  if (seconds == null || seconds <= 0) {
    return null;
  }
  final int h = seconds ~/ 3600;
  final int m = (seconds % 3600) ~/ 60;
  final int sec = seconds % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
      : '$m:${sec.toString().padLeft(2, '0')}';
}

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  static const double _maxWidth = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<NotesShelfData> shelf = ref.watch(notesShelfProvider);
    final NotesShelfData? data = shelf.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          data == null || data.count == 0
              ? 'Заметки'
              : 'Заметки · ${data.count}',
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('notes-refresh'),
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: _buildBody(context, ref, shelf),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NotesShelfData> shelf,
  ) {
    final NotesShelfData? data = shelf.valueOrNull;
    if (data == null) {
      if (shelf.hasError) {
        return StateFeedbackPlaceholder(
          icon: Icons.error_outline,
          title: 'Не удалось загрузить заметки',
          message: '${shelf.error}',
          actionLabel: 'Повторить',
          onAction: () => _refresh(ref),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (data.items.isEmpty) {
      return const StateFeedbackPlaceholder(
        icon: Icons.task_alt,
        title: 'Разбирать нечего',
        message: 'Досмотренные видео без тем и черновики появятся здесь.',
      );
    }
    final ThemeData theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async => _refresh(ref),
      child: ListView.builder(
        key: const Key('notes-list'),
        padding: ltListPadding(context, top: 4),
        itemCount: data.items.length + (data.more > 0 ? 1 : 0) + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Видео без темы и незаконченные черновики',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final int i = index - 1;
          if (i == data.items.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Ещё ${data.more} появятся, когда разберёте эти',
                key: const Key('notes-more'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final NotesShelfItem item = data.items[i];
          // «Суд времени — Перестройка» already names its series.
          final bool titleNamesSeries = item.seriesName.isNotEmpty &&
              item.title
                  .toLowerCase()
                  .startsWith(item.seriesName.toLowerCase());
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              final LocalVideoMetadata? metadata =
                  ref.watch(_noteMetadataProvider(item.videoId)).valueOrNull;
              return PortraitVideoListItem(
                key: ValueKey<String>('notes-item-${item.videoId}'),
                localImagePath: metadata?.thumbnailLocalPath,
                durationLabel: _lengthLabel(metadata?.durationSeconds),
                imageUrl: _coverUrl(ref, item.videoId),
                allowNetworkFallback: true,
                title: item.title,
                metadataLine: titleNamesSeries ? '' : item.seriesName,
                watchedFraction: null,
                isDownloaded: false,
                onTap: () => _open(context, ref, item),
                footer: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: <Widget>[
                    if (item.needsClassification)
                      const _ReasonChip(label: 'Нужна тема'),
                    if (item.hasDrafts) const _ReasonChip(label: 'Черновик'),
                  ],
                ),
                trailing: SizedBox(
                  width: 48,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.read(notesRevisionProvider.notifier).state++;
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    NotesShelfItem item,
  ) async {
    final PlayerNavigationResult? result =
        await context.push<PlayerNavigationResult>(
      '${AppRoutes.player}/${item.videoId}',
      extra: <String, String>{'title': item.title},
    );
    if (!context.mounted) {
      return;
    }
    _refresh(ref);
    showPlayerNavigationResultSnackBar(context, result);
  }
}

/// Why a video is on the shelf, as a small tinted chip: the same colour for
/// the same reason everywhere.
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label});

  final String label;

  /// A flat, tinted tag in regular weight: a status, not a button.
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF23273A) : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
