import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notes_repository.dart';
import 'voice_text_field.dart';

/// Edits a Mark's caption, typed or dictated. Returns the new caption, or
/// null when the person cancels.
Future<String?> showMarkCaptionDialog({
  required BuildContext context,
  required String caption,
  Future<void> Function()? onPausePlayback,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _MarkCaptionDialog(
      caption: caption,
      onPausePlayback: onPausePlayback,
    ),
  );
}

class _MarkCaptionDialog extends ConsumerStatefulWidget {
  const _MarkCaptionDialog({required this.caption, this.onPausePlayback});

  final String caption;
  final Future<void> Function()? onPausePlayback;

  @override
  ConsumerState<_MarkCaptionDialog> createState() => _MarkCaptionDialogState();
}

class _MarkCaptionDialogState extends ConsumerState<_MarkCaptionDialog> {
  late final TextEditingController _text;
  String? _error;

  /// A clip that could not be recognized stays until «Повторить» recognizes
  /// it or «Удалить» drops it.
  String? _failedClip;
  bool _retrying = false;

  /// Read once: the clip is also cleaned up in [dispose].
  late final NotesRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(notesRepositoryProvider);
    final String caption = widget.caption.trim();
    // Automatic captions such as "(bookmark)" are not the person's words.
    final bool automatic = caption.startsWith('(') && caption.endsWith(')');
    _text = TextEditingController(text: automatic ? '' : caption);
  }

  @override
  void dispose() {
    _text.dispose();
    // The caption is decided once the dialog closes; a clip nobody recognized
    // has nothing left to go into.
    final String? clip = _failedClip;
    if (clip != null) {
      unawaited(_repository.deleteClip(clip));
    }
    super.dispose();
  }

  Future<void> _onClip(String clipPath) async {
    // A newer clip replaces the one that failed before it.
    final String? previous = _failedClip;
    if (previous != null && previous != clipPath) {
      _failedClip = null;
      await _repository.deleteClip(previous);
    }
    await _recognize(clipPath);
  }

  Future<void> _recognize(String clipPath) async {
    try {
      final String text = await _repository.recognizeClip(clipPath);
      if (!mounted) {
        return;
      }
      final String current = _text.text.trim();
      setState(() {
        _error = null;
        _failedClip = null;
        _text.text = current.isEmpty ? text.trim() : '$current ${text.trim()}';
      });
    } catch (error) {
      if (!mounted) {
        await _repository.deleteClip(clipPath);
        return;
      }
      setState(() {
        _error = error.toString();
        _failedClip = clipPath;
      });
    }
  }

  Future<void> _retry() async {
    final String? clip = _failedClip;
    if (clip == null || _retrying) {
      return;
    }
    setState(() {
      _retrying = true;
    });
    await _recognize(clip);
    if (mounted) {
      setState(() {
        _retrying = false;
      });
    }
  }

  Future<void> _deleteFailedClip() async {
    final String? clip = _failedClip;
    if (clip == null) {
      return;
    }
    setState(() {
      _failedClip = null;
      _error = null;
    });
    await _repository.deleteClip(clip);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Подпись метки'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            VoiceTextField(
              controller: _text,
              label: 'Что важно в этом месте',
              minLines: 2,
              maxLines: 5,
              onRecordingStarted: widget.onPausePlayback,
              onClip: _onClip,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_failedClip != null)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                children: <Widget>[
                  TextButton(
                    onPressed: _retrying ? null : _retry,
                    child: const Text('Повторить'),
                  ),
                  TextButton(
                    onPressed: _retrying ? null : _deleteFailedClip,
                    child: const Text('Удалить'),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
