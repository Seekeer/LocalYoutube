import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../player/presentation/player_navigation_result.dart';
import '../data/notes_repository.dart';
import '../domain/notes_models.dart';

/// Home shelf «Заметки»: the Triage Queue plus videos with local Drafts.
/// Hidden while empty or unavailable.
class NotesShelf extends ConsumerWidget {
  const NotesShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotesShelfData? data = ref.watch(notesShelfProvider).valueOrNull;
    if (data == null || data.count == 0) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Card(
      key: const Key('notes-shelf'),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: <Widget>[
                  Text('Заметки', style: theme.textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Badge(
                    label: Text('${data.count}'),
                    backgroundColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: data.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final NotesShelfItem item = data.items[index];
                  return SizedBox(
                    width: 220,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _open(context, ref, item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (item.seriesName.isNotEmpty)
                            Text(
                              item.seriesName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          const Spacer(),
                          Text(
                            item.reasonLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
    ref.read(notesRevisionProvider.notifier).state++;
    showPlayerNavigationResultSnackBar(context, result);
  }
}
