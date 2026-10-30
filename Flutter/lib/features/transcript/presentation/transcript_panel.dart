import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../data/transcript_repository.dart';
import '../domain/transcript.dart';

class TranscriptPanel extends ConsumerStatefulWidget {
  const TranscriptPanel(
      {super.key,
      required this.videoId,
      required this.onSeek,
      required this.onBookmark,
      this.showCaptionsControl = true});
  final int videoId;
  final Future<void> Function(Duration) onSeek;
  final Future<bool> Function(double, String) onBookmark;
  final bool showCaptionsControl;
  @override
  ConsumerState<TranscriptPanel> createState() => _TranscriptPanelState();
}

class _TranscriptPanelState extends ConsumerState<TranscriptPanel> {
  final TextEditingController _text = TextEditingController();
  Timer? _timer;
  bool _expanded = false, _saving = false;
  String _status = 'loading', _error = '';
  double _progress = 0;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    _text.addListener(_selectionChanged);
  }

  void _selectionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TranscriptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _loadRevision++;
      _timer?.cancel();
      _text.clear();
      _status = 'loading';
      _error = '';
      if (_expanded) unawaited(_load());
    }
  }

  Future<void> _load() async {
    final int id = widget.videoId;
    final int revision = ++_loadRevision;
    _timer?.cancel();
    try {
      final repo = ref.read(transcriptRepositoryProvider);
      final cached = await repo.cached(id);
      if (!mounted || id != widget.videoId || revision != _loadRevision) return;
      if (cached != null && _text.text.isEmpty) _publish(cached);
      final job = await repo.status(id);
      if (!mounted || id != widget.videoId || revision != _loadRevision) return;
      setState(() {
        _status = job['status'] as String;
        _error = (job['error'] as String?) ?? '';
        _progress = (job['progress'] as num?)?.toDouble() ?? 0;
      });
      if (_status == 'ready') {
        final transcript = await repo.load(id);
        if (mounted && id == widget.videoId && revision == _loadRevision) {
          _publish(transcript);
          unawaited(repo.srt(id).catchError((_) => ''));
        }
      } else if (['queued', 'processing', 'checking', 'waitingDownload']
              .contains(_status) &&
          _expanded) {
        _timer = Timer(const Duration(seconds: 4), () => unawaited(_load()));
      } else if (_status == 'stale' || _status == 'removed') {
        _text.clear();
        ref.read(transcriptProvider(id).notifier).state = null;
      }
    } catch (_) {
      if (!mounted || id != widget.videoId || revision != _loadRevision) return;
      setState(() {
        _status = 'unavailable';
        _error = _text.text.isEmpty
            ? 'Не удалось загрузить текст видео.'
            : 'Показан сохранённый текст. Сервер недоступен.';
      });
    }
  }

  void _publish(Transcript transcript) {
    ref.read(transcriptProvider(widget.videoId).notifier).state = transcript;
    if (_text.text != transcript.text) _text.text = transcript.text;
    setState(() {});
  }

  Future<void> _request() async {
    final int id = widget.videoId;
    try {
      await ref.read(transcriptRepositoryProvider).request(id);
      if (!mounted || id != widget.videoId) return;
      await _load();
    } catch (_) {
      if (mounted && id == widget.videoId) {
        setState(() {
          _error =
              'Не удалось создать субтитры. Проверьте подключение и завершение загрузки видео.';
        });
      }
    }
  }

  Future<void> _bookmark(TranscriptWord word, String caption) async {
    setState(() {
      _saving = true;
    });
    try {
      final bool added = await widget.onBookmark(word.start, caption);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(added
                ? 'Закладка создана'
                : 'Рядом с этим моментом уже есть закладка')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось создать закладку')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveSrt() async {
    final int id = widget.videoId;
    try {
      final String srt = await ref.read(transcriptRepositoryProvider).srt(id);
      if (!mounted || id != widget.videoId) return;
      await FilePicker.platform.saveFile(
          fileName: '$id.srt', bytes: Uint8List.fromList(utf8.encode(srt)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Не удалось сохранить SRT.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Transcript? transcript =
        ref.watch(transcriptProvider(widget.videoId));
    final TextSelection selection = _text.selection;
    final bool valid = selection.isValid && selection.end <= _text.text.length;
    final String raw =
        valid ? _text.text.substring(selection.start, selection.end) : '';
    final String selected = raw.trim();
    final int offset =
        valid ? selection.start + raw.length - raw.trimLeft().length : 0;
    final TranscriptWord? word = valid ? transcript?.wordAt(offset) : null;
    final double target =
        word == null ? 0 : (word.start - 1.5).clamp(0, double.infinity);
    final Map<String, String> labels = {
      'loading': 'Загружаем текст…',
      'disabled': 'Создание субтитров пока не настроено.',
      'waitingDownload': 'Ожидаем завершения загрузки видео.',
      'checking': 'Проверяем существующие субтитры…',
      'queued': 'Видео в очереди. Фильмы обрабатываются ночью.',
      'processing': 'Создаём текст и субтитры: ${(_progress * 100).round()}%',
      'existing': 'В фильме уже есть субтитры. Распознавание не запускалось.',
    };
    return ExpansionTile(
      title: const Text('Текст видео'),
      tilePadding: EdgeInsets.zero,
      onExpansionChanged: (bool expanded) {
        setState(() {
          _expanded = expanded;
        });
        if (expanded) {
          unawaited(_load());
        } else {
          _timer?.cancel();
        }
      },
      children: !_expanded
          ? const []
          : [
              if (labels.containsKey(_status)) Text(labels[_status]!),
              if (_error.isNotEmpty)
                Text(_error,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (['none', 'failed', 'stale', 'unavailable'].contains(_status))
                OutlinedButton(
                    onPressed: _request,
                    child: const Text('Создать текст и субтитры')),
              if (_text.text.isNotEmpty) ...[
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        'Поставьте курсор для перехода к видео. Выделите текст для закладки.')),
                SizedBox(
                    height: 280,
                    child: TextField(
                        controller: _text,
                        readOnly: true,
                        showCursor: true,
                        expands: true,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(height: 1.6),
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Расшифровка видео',
                            alignLabelWithHint: true))),
                Wrap(spacing: 8, children: [
                  OutlinedButton(
                      onPressed: word == null
                          ? null
                          : () => unawaited(widget.onSeek(
                              Duration(milliseconds: (target * 1000).round()))),
                      child: Text(word == null
                          ? 'Перейти к месту'
                          : 'Перейти к ${_stamp(target)}')),
                  FilledButton.icon(
                      onPressed: selected.isEmpty || word == null || _saving
                          ? null
                          : () => unawaited(_bookmark(word, selected)),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Создать закладку')),
                  if (widget.showCaptionsControl)
                    TextButton(
                        onPressed: () => ref
                                .read(captionsEnabledProvider(widget.videoId)
                                    .notifier)
                                .state =
                            !ref.read(captionsEnabledProvider(widget.videoId)),
                        child: Text(
                            ref.watch(captionsEnabledProvider(widget.videoId))
                                ? 'Выключить субтитры'
                                : 'Включить субтитры')),
                  TextButton(
                      onPressed: _saveSrt, child: const Text('Скачать SRT')),
                ]),
              ],
            ],
    );
  }

  String _stamp(double seconds) =>
      '${seconds ~/ 60}:${(seconds.toInt() % 60).toString().padLeft(2, '0')}';
  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }
}

class TranscriptCaptions extends ConsumerWidget {
  const TranscriptCaptions(
      {super.key, required this.videoId, required this.controller});
  final int videoId;
  final VideoPlayerController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(captionsEnabledProvider(videoId))) {
      return const SizedBox.shrink();
    }
    final Transcript? transcript = ref.watch(transcriptProvider(videoId));
    if (transcript == null) return const SizedBox.shrink();
    return IgnorePointer(
        child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final String text = transcript.captionAt(value.position);
              return text.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 46),
                      child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(text,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  backgroundColor: Colors.black87,
                                  fontSize: 18,
                                  height: 1.4))));
            }));
  }
}
