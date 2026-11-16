import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notes_repository.dart';
import '../domain/notes_models.dart';

/// What the person entered in the Rating dialog.
@immutable
class RatingDialogResult {
  const RatingDialogResult({required this.rating, required this.review});

  /// From [VideoNotes.minRating] to [VideoNotes.maxRating], or null when none was picked.
  final int? rating;

  /// The Review as typed, trimmed. Empty when nothing was typed.
  final String review;
}

/// Asks for the person's Rating of a video they just finished, with their Review beside it.
///
/// What they had already given is shown to start with, so finishing a video twice changes the Rating
/// rather than asking for it from nothing; taking a score back or erasing the Review and saving clears
/// them. «Пропустить» closes it with nothing saved. A failed save
/// keeps the dialog open with the reason, so nothing typed is lost.
Future<void> showFinishViewingRating({
  required BuildContext context,
  required WidgetRef ref,
  required int videoId,
  String title = '',
}) {
  final NotesRepository notes = ref.read(notesRepositoryProvider);
  // Read in the background, so the dialog opens at once and is filled in when the answer comes.
  final Future<VideoNotes?> current = notes
      .load(videoId)
      .then<VideoNotes?>((NotesSnapshot snapshot) => snapshot.notes)
      .timeout(const Duration(seconds: 10))
      .catchError((Object _) => null);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => RatingDialog(
      title: title,
      current: current,
      // Only what differs from what was given before is sent, so a taken-back score or an erased
      // Review is saved as such - the same as clearing them in «Заметки».
      onSave: (RatingDialogResult result) async {
        final VideoNotes? known = await current;
        if (result.rating != known?.rating) {
          await notes.saveRating(videoId, result.rating);
        }
        if (result.review != (known?.review ?? '').trim()) {
          await notes.confirmReview(videoId, result.review, title: title);
        }
        ref.read(notesRevisionProvider.notifier).state++;
      },
    ),
  );
}

/// The Rating dialog itself: ten scores, a Review field, «Пропустить» and «Сохранить».
///
/// [onSave] does the saving. It throwing keeps the dialog open with the error shown.
class RatingDialog extends StatefulWidget {
  const RatingDialog({
    super.key,
    required this.onSave,
    this.title = '',
    this.current,
  });

  final String title;

  /// The Rating and Review given before, when they are known; the dialog fills itself in from them
  /// unless the person has already started.
  final Future<VideoNotes?>? current;
  final Future<void> Function(RatingDialogResult result) onSave;

  static Key scoreKey(int score) => Key('rating-score-$score');
  static const Key reviewFieldKey = Key('rating-review');
  static const Key saveKey = Key('rating-save');
  static const Key skipKey = Key('rating-skip');

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  final TextEditingController _review = TextEditingController();
  int? _rating;
  bool _touched = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Future<VideoNotes?>? current = widget.current;
    if (current != null) {
      unawaited(current.then(_fillFrom));
    }
  }

  void _fillFrom(VideoNotes? notes) {
    if (!mounted || _touched || notes == null) {
      return;
    }
    setState(() {
      _rating = notes.rating;
      _review.text = notes.review ?? '';
    });
  }

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  /// Saving is offered once the person changed something, a taken-back score included.
  bool get _canSave => !_saving && _touched;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        RatingDialogResult(rating: _rating, review: _review.text.trim()),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = error is NotesFailure
            ? error.message
            : 'Не удалось сохранить оценку.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = widget.title.trim();
    return AlertDialog(
      title: const Text('Оцените видео'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (title.isNotEmpty) ...<Widget>[
                Text(title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (int score = VideoNotes.minRating;
                      score <= VideoNotes.maxRating;
                      score++)
                    ChoiceChip(
                      key: RatingDialog.scoreKey(score),
                      label: Text('$score'),
                      selected: _rating == score,
                      onSelected: _saving
                          ? null
                          : (bool selected) => setState(() {
                                _touched = true;
                                _rating = selected ? score : null;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: RatingDialog.reviewFieldKey,
                controller: _review,
                enabled: !_saving,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Отзыв',
                  hintText: 'Что запомнилось',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _touched = true),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: RatingDialog.skipKey,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Пропустить'),
        ),
        FilledButton(
          key: RatingDialog.saveKey,
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}
