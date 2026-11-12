import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/playback/playback_mode.dart';
import '../data/notes_repository.dart';
import '../domain/notes_models.dart';
import 'voice_text_field.dart';

/// Number of Drafts of a video that need the person, for the «есть
/// черновики» marker. Topics waiting to sync on their own do not count.
final notesDraftCountProvider =
    FutureProvider.autoDispose.family<int, int>((Ref ref, int videoId) async {
  ref.watch(notesRevisionProvider);
  final List<NoteDraft> drafts =
      await ref.watch(notesRepositoryProvider).drafts(videoId);
  return drafts.where((NoteDraft draft) => draft.needsPerson).length;
});

/// The collapsible «Заметки» section below the video.
class NotesSection extends ConsumerStatefulWidget {
  const NotesSection({
    super.key,
    required this.videoId,
    this.title = '',
    this.onPausePlayback,
  });

  final int videoId;
  final String title;
  final Future<void> Function()? onPausePlayback;

  @override
  ConsumerState<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends ConsumerState<NotesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final int drafts =
        ref.watch(notesDraftCountProvider(widget.videoId)).valueOrNull ?? 0;
    // No PageStorageKey: a key shared by every video would restore the tile
    // expanded while [_expanded] says it is collapsed.
    return ExpansionTile(
      title: Text('Заметки', style: Theme.of(context).textTheme.titleMedium),
      subtitle: drafts > 0 ? const Text('есть черновики') : null,
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      collapsedShape: const Border(),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      onExpansionChanged: (bool expanded) {
        setState(() {
          _expanded = expanded;
        });
      },
      children: !_expanded
          ? const <Widget>[]
          : <Widget>[
              NotesContent(
                key: ValueKey<int>(widget.videoId),
                videoId: widget.videoId,
                title: widget.title,
                onPausePlayback: widget.onPausePlayback,
              ),
            ],
    );
  }
}

/// Opens the «Заметки» content as the post-viewing menu. «Позже» closes it.
Future<void> showPostViewingNotes({
  required BuildContext context,
  required int videoId,
  String title = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Заметки',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(title, maxLines: 2),
                  ),
                NotesContent(
                  videoId: videoId,
                  title: title,
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Topics, Review, Extended Description, Action and Video Query of one video.
class NotesContent extends ConsumerStatefulWidget {
  const NotesContent({
    super.key,
    required this.videoId,
    this.title = '',
    this.onPausePlayback,
    this.onClose,
  });

  final int videoId;
  final String title;
  final Future<void> Function()? onPausePlayback;

  /// Shown as «Позже» in the post-viewing menu.
  final VoidCallback? onClose;

  @override
  ConsumerState<NotesContent> createState() => _NotesContentState();
}

class _NotesContentState extends ConsumerState<NotesContent> {
  final TextEditingController _topicPhrase = TextEditingController();
  final TextEditingController _review = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _action = TextEditingController();
  final TextEditingController _formulated = TextEditingController();
  final TextEditingController _query = TextEditingController();

  NotesSnapshot? _snapshot;
  List<NoteTopic> _vocabulary = const <NoteTopic>[];
  List<SuggestedTopic> _suggestions = const <SuggestedTopic>[];
  final List<String> _selected = <String>[];
  bool _noTopics = false;
  bool _topicsChanged = false;
  bool _loading = true;
  bool _busy = false;
  bool _editingDescription = false;
  String? _error;
  FormulatedAction? _formulatedAction;
  int? _reviewDraftId;
  int? _actionDraftId;
  int? _queryDraftId;
  int? _phraseDraftId;

  /// The Review text last put into the field from the server. While the field
  /// still holds it, the person has not typed anything to keep.
  String _shownReview = '';

  NotesRepository get _repository => ref.read(notesRepositoryProvider);

  VideoNotes? get _notes => _snapshot?.notes;
  bool get _offline => _snapshot?.offline ?? false;
  bool get _ai => !_offline && (_notes?.aiAvailable ?? false);

  /// Offline, the last known value decides; with nothing known, dictation is
  /// still offered because the clip only waits on the device.
  bool get _speech => _notes?.speechAvailable ?? _offline;

  /// Offline with nothing known, Drafts are still allowed.
  bool get _telegram => _notes?.telegramLinked ?? _offline;

  @override
  void initState() {
    super.initState();
    unawaited(_load(initial: true));
  }

  @override
  void dispose() {
    _topicPhrase.dispose();
    _review.dispose();
    _description.dispose();
    _action.dispose();
    _formulated.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Reloads notes and Drafts. Text the person is typing is kept: the Review
  /// is replaced only on the first load, after it was saved ([resetReview]),
  /// or while the field is untouched; the Extended Description only while it
  /// is not being edited.
  Future<void> _load({bool initial = false, bool resetReview = false}) async {
    final int videoId = widget.videoId;
    try {
      final NotesSnapshot snapshot = await _repository.load(videoId);
      List<NoteTopic> vocabulary = _vocabulary;
      try {
        vocabulary = await _repository.vocabulary();
      } catch (_) {}
      if (!mounted || videoId != widget.videoId) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _vocabulary = vocabulary;
        _loading = false;
        _error = null;
        final VideoNotes? notes = snapshot.notes;
        if (!_topicsChanged) {
          _selected
            ..clear()
            ..addAll(notes?.topics.map((NoteTopic t) => t.name) ??
                const <String>[]);
          _noTopics = notes?.noTopics ?? false;
        }
        final String review = snapshot.offline ? '' : (notes?.review ?? '');
        if (initial ||
            resetReview ||
            (_reviewDraftId == null && _review.text == _shownReview)) {
          _review.text = review;
          _shownReview = review;
        }
        if (!_editingDescription) {
          _description.text = notes?.description ?? '';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _changed() {
    ref.read(notesRevisionProvider.notifier).state++;
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await action();
    } catch (error) {
      _toast(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  static const String _keptOffline =
      'Нет связи с сервером. Сохранено как черновик.';

  // ---- Dictation ----

  Future<void> Function(String) _dictateInto(
    NoteDraftKind kind,
    TextEditingController controller,
  ) {
    return (String clipPath) async {
      final DictationResult result = await _repository.dictate(
        widget.videoId,
        kind,
        clipPath,
        title: widget.title,
      );
      final String? text = result.text;
      if (text != null && text.trim().isNotEmpty) {
        final String current = controller.text.trim();
        controller.text = current.isEmpty ? text.trim() : '$current ${text.trim()}';
      } else if (result.keptAsDraft) {
        _toast(result.failure != null && !result.failure!.offline
            ? 'Не удалось распознать: ${result.failure!.message} Запись сохранена в черновиках.'
            : 'Запись сохранена. Распознаем после подключения.');
        _changed();
        await _load();
      } else {
        _toast('Речь не распознана.');
      }
    };
  }

  // ---- Topics ----

  void _toggleTopic(String name) {
    setState(() {
      final int index = _selected
          .indexWhere((String t) => t.toLowerCase() == name.toLowerCase());
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(name);
        _noTopics = false;
      }
      _topicsChanged = true;
    });
  }

  bool _isSelected(String name) =>
      _selected.any((String t) => t.toLowerCase() == name.toLowerCase());

  bool _isKnown(String name) {
    final String key = name.toLowerCase();
    return _vocabulary.any((NoteTopic t) => t.name.toLowerCase() == key) ||
        (_notes?.topics.any((NoteTopic t) => t.name.toLowerCase() == key) ??
            false);
  }

  Future<void> _suggest() => _run(() async {
        final List<SuggestedTopic> suggestions =
            await _repository.suggestTopics(widget.videoId);
        if (mounted) {
          setState(() {
            _suggestions = suggestions;
          });
        }
      });

  Future<void> _matchPhrase() => _run(() async {
        final String phrase = _topicPhrase.text.trim();
        if (phrase.isEmpty) {
          return;
        }
        if (!_ai) {
          await _repository.saveDraftText(
            widget.videoId,
            NoteDraftKind.topicsPhrase,
            phrase,
            draftId: _phraseDraftId,
            title: widget.title,
          );
          _phraseDraftId = null;
          _topicPhrase.clear();
          _toast(_keptOffline);
          _changed();
          await _load();
          return;
        }
        final List<SuggestedTopic> matched =
            await _repository.matchTopics(widget.videoId, phrase);
        final int? draftId = _phraseDraftId;
        if (draftId != null) {
          await _repository.deleteDraft(draftId);
          _phraseDraftId = null;
          _changed();
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = matched;
          _topicPhrase.clear();
        });
      });

  void _addTypedTopic() {
    final String name = _topicPhrase.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (!_isSelected(name)) {
      _toggleTopic(name);
    }
    _topicPhrase.clear();
  }

  Future<void> _saveTopics() => _run(() async {
        final bool online = await _repository.saveTopics(
          widget.videoId,
          topics: List<String>.of(_selected),
          noTopics: _selected.isEmpty && _noTopics,
          title: widget.title,
        );
        _topicsChanged = false;
        _suggestions = const <SuggestedTopic>[];
        _toast(online
            ? 'Темы сохранены'
            : 'Темы сохранены на устройстве и применятся после подключения.');
        _changed();
        await _load();
      });

  // ---- Review ----

  Future<void> _saveReview() => _run(() async {
        final bool online = await _repository.confirmReview(
          widget.videoId,
          _review.text.trim(),
          draftId: _reviewDraftId,
          title: widget.title,
        );
        _reviewDraftId = null;
        if (!online) {
          _review.clear();
        }
        _toast(online ? 'Отзыв сохранён' : _keptOffline);
        _changed();
        await _load(resetReview: true);
      });

  Future<void> _regenerate() => _run(() async {
        await _repository.regenerateDescription(widget.videoId);
        await _load();
      });

  Future<void> _saveDescription() => _run(() async {
        await _repository.editDescription(
          widget.videoId,
          _description.text.trim(),
        );
        _editingDescription = false;
        await _load();
      });

  // ---- Action ----

  Future<void> _formulate() => _run(() async {
        final String phrase = _action.text.trim();
        if (phrase.isEmpty) {
          return;
        }
        if (!_ai) {
          // Without AI the phrase itself is the Action.
          setState(() {
            _formulatedAction = FormulatedAction(action: phrase);
            _formulated.text = phrase;
          });
          if (_offline) {
            await _repository.saveDraftText(
              widget.videoId,
              NoteDraftKind.action,
              phrase,
              draftId: _actionDraftId,
              title: widget.title,
            );
            _actionDraftId = null;
            _action.clear();
            setState(() {
              _formulatedAction = null;
            });
            _toast(_keptOffline);
            _changed();
            await _load();
          }
          return;
        }
        final FormulatedAction? action = await _repository.formulateAction(
          widget.videoId,
          phrase,
          draftId: _actionDraftId,
          title: widget.title,
        );
        if (action == null) {
          _actionDraftId = null;
          _action.clear();
          _toast(_keptOffline);
          _changed();
          await _load();
          return;
        }
        if (mounted) {
          setState(() {
            _formulatedAction = action;
            _formulated.text = action.action;
          });
        }
      });

  Future<void> _sendAction() => _run(() async {
        final String text = _formulated.text.trim();
        if (text.isEmpty) {
          return;
        }
        final bool online = await _repository.sendAction(
          widget.videoId,
          text,
          position: _formulatedAction?.position,
          draftId: _actionDraftId,
          title: widget.title,
        );
        _actionDraftId = null;
        setState(() {
          _formulatedAction = null;
          _formulated.clear();
          _action.clear();
        });
        _toast(online ? 'Действие отправлено в Telegram' : _keptOffline);
        _changed();
        await _load();
      });

  // ---- Video Query ----

  Future<void> _ask() => _run(() async {
        final String query = _query.text.trim();
        if (query.isEmpty) {
          return;
        }
        final bool online = await _repository.ask(
          widget.videoId,
          query,
          draftId: _queryDraftId,
          title: widget.title,
        );
        _queryDraftId = null;
        _query.clear();
        _toast(online ? 'Ответ придёт в Telegram' : _keptOffline);
        _changed();
        await _load();
      });

  // ---- Drafts ----

  void _useDraft(NoteDraft draft) {
    setState(() {
      switch (draft.kind) {
        case NoteDraftKind.review:
          _review.text = draft.text;
          _reviewDraftId = draft.id;
          break;
        case NoteDraftKind.action:
          _action.text = draft.text;
          _actionDraftId = draft.id;
          _formulatedAction = null;
          _formulated.clear();
          break;
        case NoteDraftKind.query:
          _query.text = draft.text;
          _queryDraftId = draft.id;
          break;
        case NoteDraftKind.topicsPhrase:
          _topicPhrase.text = draft.text;
          _phraseDraftId = draft.id;
          break;
        case NoteDraftKind.topics:
          break;
      }
    });
  }

  Future<void> _deleteDraft(NoteDraft draft) => _run(() async {
        await _repository.deleteDraft(draft.id);
        if (_reviewDraftId == draft.id) _reviewDraftId = null;
        if (_actionDraftId == draft.id) _actionDraftId = null;
        if (_queryDraftId == draft.id) _queryDraftId = null;
        if (_phraseDraftId == draft.id) _phraseDraftId = null;
        _changed();
        await _load();
      });

  Future<void> _retryDraft(NoteDraft draft) => _run(() async {
        await _repository.retryDraft(draft.id);
        _changed();
        await _load();
      });

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(effectiveAutonomousModeProvider,
        (bool? previous, bool next) {
      if (previous == true && !next) {
        unawaited(_load());
      }
    });
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final ThemeData theme = Theme.of(context);
    final List<NoteDraft> drafts =
        _snapshot?.drafts ?? const <NoteDraft>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        if (_offline)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Нет связи с сервером: сохранённое доступно только для чтения, '
              'новое сохраняется черновиками.',
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        if (drafts.isNotEmpty) ..._buildDrafts(theme, drafts),
        ..._buildTopics(theme),
        const Divider(height: 32),
        ..._buildReview(theme),
        const Divider(height: 32),
        ..._buildAction(theme),
        if (_ai || _offline || (_notes?.answers.isNotEmpty ?? false)) ...<Widget>[
          const Divider(height: 32),
          ..._buildAsk(theme),
        ],
        if (widget.onClose != null) ...<Widget>[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onClose,
              child: const Text('Позже'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _heading(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: theme.textTheme.titleSmall),
      );

  List<Widget> _buildDrafts(ThemeData theme, List<NoteDraft> drafts) {
    return <Widget>[
      _heading(theme, 'Есть черновики'),
      ...drafts.map((NoteDraft draft) => _buildDraft(theme, draft)),
      const Divider(height: 24),
    ];
  }

  Widget _buildDraft(ThemeData theme, NoteDraft draft) {
    final String kind = switch (draft.kind) {
      NoteDraftKind.review => 'Отзыв',
      NoteDraftKind.action => 'Действие',
      NoteDraftKind.query => 'Запрос',
      NoteDraftKind.topicsPhrase => 'Темы (фраза)',
      NoteDraftKind.topics => 'Темы',
    };
    String detail;
    if (draft.kind == NoteDraftKind.topics) {
      detail = draft.error.isNotEmpty
          ? 'Не применены: ${draft.error}'
          : 'Применятся после подключения';
    } else {
      detail = switch (draft.status) {
        NoteDraftStatus.pendingRecognition => 'Запись ждёт распознавания',
        NoteDraftStatus.recognitionFailed => draft.error.isEmpty
            ? 'Не удалось распознать запись'
            : 'Не удалось распознать: ${draft.error}',
        NoteDraftStatus.ready => draft.text,
      };
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(kind, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(detail, maxLines: 4, overflow: TextOverflow.ellipsis),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: <Widget>[
                // Refused Topics are not retried automatically.
                if (draft.status == NoteDraftStatus.recognitionFailed ||
                    (draft.kind == NoteDraftKind.topics &&
                        draft.error.isNotEmpty))
                  TextButton(
                    onPressed: _busy ? null : () => _retryDraft(draft),
                    child: const Text('Повторить'),
                  ),
                if (draft.status == NoteDraftStatus.ready &&
                    draft.kind != NoteDraftKind.topics)
                  TextButton(
                    onPressed: _busy ? null : () => _useDraft(draft),
                    child: const Text('Использовать'),
                  ),
                TextButton(
                  onPressed: _busy ? null : () => _deleteDraft(draft),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTopics(ThemeData theme) {
    final List<NoteTopic> unselected = _vocabulary
        .where((NoteTopic t) => !_isSelected(t.name))
        .toList(growable: false);
    return <Widget>[
      _heading(theme, 'Темы'),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          ..._selected.map(
            (String name) => InputChip(
              label: Text(_isKnown(name) ? name : '$name · новая'),
              onDeleted: _busy ? null : () => _toggleTopic(name),
              deleteButtonTooltipMessage: 'Убрать тему',
            ),
          ),
          FilterChip(
            label: const Text('Без тем'),
            selected: _selected.isEmpty && _noTopics,
            onSelected: _selected.isNotEmpty || _busy
                ? null
                : (bool value) {
                    setState(() {
                      _noTopics = value;
                      _topicsChanged = true;
                    });
                  },
          ),
        ],
      ),
      if (_suggestions.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Text('Предложения', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _suggestions
              .map(
                (SuggestedTopic topic) => FilterChip(
                  label: Text(topic.isNew ? '${topic.name} · новая' : topic.name),
                  selected: _isSelected(topic.name),
                  onSelected: _busy ? null : (_) => _toggleTopic(topic.name),
                ),
              )
              .toList(growable: false),
        ),
      ],
      const SizedBox(height: 8),
      VoiceTextField(
        controller: _topicPhrase,
        label: _ai ? 'Тема или фраза о темах' : 'Новая тема',
        showMic: _speech,
        enabled: !_busy,
        onRecordingStarted: widget.onPausePlayback,
        onClip: _dictateInto(NoteDraftKind.topicsPhrase, _topicPhrase),
      ),
      Wrap(
        spacing: 8,
        children: <Widget>[
          TextButton(
            onPressed: _busy ? null : _addTypedTopic,
            child: const Text('Добавить'),
          ),
          if (_ai || _offline)
            TextButton(
              onPressed: _busy ? null : _matchPhrase,
              child: Text(_offline ? 'Сохранить фразу' : 'Подобрать'),
            ),
          if (_ai)
            TextButton(
              onPressed: _busy ? null : _suggest,
              child: const Text('Предложить темы'),
            ),
        ],
      ),
      if (unselected.isNotEmpty)
        ExpansionTile(
          title: const Text('Словарь тем'),
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: unselected
                  .map(
                    (NoteTopic topic) => Tooltip(
                      message: topic.definition,
                      child: ActionChip(
                        label: Text(topic.name),
                        onPressed:
                            _busy ? null : () => _toggleTopic(topic.name),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _busy || !_topicsChanged ? null : _saveTopics,
          child: const Text('Сохранить темы'),
        ),
      ),
    ];
  }

  List<Widget> _buildReview(ThemeData theme) {
    final VideoNotes? notes = _notes;
    final String savedReview = notes?.review ?? '';
    return <Widget>[
      _heading(theme, 'Отзыв'),
      if (_offline && savedReview.isNotEmpty) ...<Widget>[
        SelectableText(savedReview),
        const SizedBox(height: 8),
      ],
      VoiceTextField(
        controller: _review,
        label: _offline ? 'Черновик отзыва' : 'Что вы думаете о видео',
        showMic: _speech,
        enabled: !_busy,
        minLines: 3,
        maxLines: 8,
        onRecordingStarted: widget.onPausePlayback,
        onClip: _dictateInto(NoteDraftKind.review, _review),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _busy ? null : _saveReview,
          child: Text(_offline ? 'Сохранить черновик' : 'Сохранить отзыв'),
        ),
      ),
      if (savedReview.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        _heading(theme, 'Расширенное описание'),
        ..._buildDescription(theme, notes!),
      ],
    ];
  }

  List<Widget> _buildDescription(ThemeData theme, VideoNotes notes) {
    final String status = notes.descriptionStatus ?? '';
    final String? label = switch (status) {
      'pending' => 'Готовится…',
      'waitingTranscript' => 'Ждём транскрипт',
      'failed' => 'Ошибка: ${notes.descriptionError ?? 'не удалось создать описание'}',
      _ => null,
    };
    final String text = notes.description ?? '';
    return <Widget>[
      if (label != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: status == 'failed'
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
        ),
      if (_editingDescription && !_offline)
        TextField(
          controller: _description,
          minLines: 4,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Расширенное описание',
            alignLabelWithHint: true,
          ),
        )
      else if (text.isNotEmpty)
        SelectableText(text),
      if (notes.descriptionEdited && !_editingDescription)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Изменено вручную', style: theme.textTheme.bodySmall),
        ),
      if (!_offline)
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: <Widget>[
            if (_editingDescription) ...<Widget>[
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _editingDescription = false;
                          _description.text = notes.description ?? '';
                        }),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: _busy ? null : _saveDescription,
                child: const Text('Сохранить описание'),
              ),
            ] else ...<Widget>[
              if (_ai)
                TextButton(
                  onPressed: _busy || status == 'pending' ? null : _regenerate,
                  child: const Text('Перегенерировать'),
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _editingDescription = true;
                          _description.text = notes.description ?? '';
                        }),
                child: const Text('Изменить'),
              ),
            ],
          ],
        ),
    ];
  }

  List<Widget> _buildAction(ThemeData theme) {
    if (!_telegram) {
      return <Widget>[
        _heading(theme, 'Действие'),
        const Text('Telegram не привязан'),
      ];
    }
    return <Widget>[
      _heading(theme, 'Действие'),
      VoiceTextField(
        controller: _action,
        label: 'Что сделать по итогам видео',
        showMic: _speech,
        enabled: !_busy,
        maxLines: 3,
        onRecordingStarted: widget.onPausePlayback,
        onClip: _dictateInto(NoteDraftKind.action, _action),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _busy ? null : _formulate,
          child: Text(_offline
              ? 'Сохранить черновик'
              : (_ai ? 'Сформулировать' : 'Подготовить')),
        ),
      ),
      if (_formulatedAction != null) ...<Widget>[
        const SizedBox(height: 8),
        TextField(
          controller: _formulated,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Задача',
            alignLabelWithHint: true,
          ),
        ),
        if (_formulatedAction!.position != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Момент: ${_stamp(_formulatedAction!.position!)}'),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy ? null : _sendAction,
            child: const Text('Отправить в Telegram'),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildAsk(ThemeData theme) {
    final List<NoteAnswer> answers = _notes?.answers ?? const <NoteAnswer>[];
    return <Widget>[
      _heading(theme, 'Спросить'),
      if (!_telegram)
        const Text('Telegram не привязан')
      else if (_ai || _offline) ...<Widget>[
        VoiceTextField(
          controller: _query,
          label: 'Вопрос по содержанию видео',
          showMic: _speech,
          enabled: !_busy,
          maxLines: 3,
          onRecordingStarted: widget.onPausePlayback,
          onClip: _dictateInto(NoteDraftKind.query, _query),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy ? null : _ask,
            child: Text(_offline ? 'Сохранить черновик' : 'Отправить'),
          ),
        ),
      ],
      if (answers.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Text('Ответы', style: theme.textTheme.labelLarge),
        ...answers.map(
          (NoteAnswer answer) => ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(answer.query, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(_answerStatus(answer)),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (answer.answer.isNotEmpty) SelectableText(answer.answer),
              if (answer.error.isNotEmpty)
                Text(
                  answer.error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  String _answerStatus(NoteAnswer answer) => switch (answer.status) {
        'pending' => 'Готовится…',
        'waitingTranscript' => 'Ждём транскрипт',
        'ready' => 'Готово',
        'failed' => 'Ошибка',
        _ => answer.status,
      };

  String _stamp(double seconds) {
    final int total = seconds.round();
    final int hours = total ~/ 3600;
    final String minutes = ((total ~/ 60) % 60).toString().padLeft(2, '0');
    final String rest = (total % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$rest' : '$minutes:$rest';
  }
}
