import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../player/presentation/player_navigation_result.dart';
import '../data/notes_repository.dart';
import '../domain/notes_models.dart';

/// The «Заметки» screen: the Triage Queue plus videos with local Drafts, as a
/// vertical list that a mouse wheel scrolls as well as a finger.
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
          data == null || data.count == 0 ? 'Заметки' : 'Заметки · ${data.count}',
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
      child: ListView.separated(
        key: const Key('notes-list'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: data.items.length + (data.more > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          if (index == data.items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'И ещё ${data.more}',
                key: const Key('notes-more'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final NotesShelfItem item = data.items[index];
          return ListTile(
            key: ValueKey<String>('notes-item-${item.videoId}'),
            title: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item.seriesName.isEmpty
                ? null
                : Text(
                    item.seriesName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Text(
              item.reasonLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            onTap: () => _open(context, ref, item),
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
