import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voice_recorder.dart';

/// Which dictation field holds the microphone, or null. Every field watches it
/// and disables its microphone while another one records.
final Provider<ValueNotifier<Object?>> voiceRecordingOwnerProvider =
    Provider<ValueNotifier<Object?>>((Ref ref) {
  final ValueNotifier<Object?> owner = ValueNotifier<Object?>(null);
  ref.onDispose(owner.dispose);
  return owner;
});

/// A text field with a microphone inside it. Tap starts recording, tap again
/// stops; the clip goes to [onClip], which puts the recognized text into the
/// field for the person to edit and confirm.
///
/// One field records at a time: while one holds the microphone, the others'
/// microphones are disabled.
class VoiceTextField extends ConsumerStatefulWidget {
  const VoiceTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.onClip,
    this.showMic = true,
    this.enabled = true,
    this.minLines = 1,
    this.maxLines = 1,
    this.onRecordingStarted,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final Future<void> Function(String clipPath) onClip;
  final bool showMic;
  final bool enabled;
  final int minLines;
  final int maxLines;

  /// Pauses the video while the person speaks.
  final Future<void> Function()? onRecordingStarted;

  @override
  ConsumerState<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends ConsumerState<VoiceTextField> {
  late final VoiceRecorder _recorder;
  late final ValueNotifier<Object?> _owner;
  StreamSubscription<void>? _interruptions;
  bool _supported = false;
  bool _recording = false;
  bool _processing = false;

  /// Another field holds the microphone.
  bool get _micTaken => _owner.value != null && !identical(_owner.value, this);

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(voiceRecorderProvider);
    _owner = ref.read(voiceRecordingOwnerProvider);
    _owner.addListener(_onOwnerChanged);
    _interruptions = _recorder.interruptions.listen((_) {
      // The app went to the background and the recording was stopped:
      // collect the clip as if the person had tapped stop.
      if (_recording && mounted) {
        unawaited(_toggle());
      }
    });
    unawaited(_checkSupport());
  }

  void _onOwnerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _release() {
    try {
      if (identical(_owner.value, this)) {
        _owner.value = null;
      }
    } catch (_) {
      // The scope, and the notifier with it, is already gone.
    }
  }

  Future<void> _checkSupport() async {
    bool supported = false;
    try {
      supported = await _recorder.isSupported();
    } catch (_) {
      supported = false;
    }
    if (mounted) {
      setState(() {
        _supported = supported;
      });
    }
  }

  Future<void> _toggle() async {
    final VoiceRecorder recorder = _recorder;
    if (_recording) {
      setState(() {
        _recording = false;
        _processing = true;
      });
      String? path;
      try {
        path = await recorder.stop();
      } catch (_) {
        path = null;
      } finally {
        // The microphone is free once the native recording is stopped.
        _release();
      }
      try {
        if (path == null) {
          _show('Запись не получилась.');
        } else {
          await widget.onClip(path);
        }
      } catch (_) {
        _show('Не удалось сохранить запись.');
      } finally {
        if (mounted) {
          setState(() {
            _processing = false;
          });
        }
      }
      return;
    }
    if (_owner.value != null) {
      _show('Уже идёт запись.');
      return;
    }
    // Taken before anything is awaited, so two fields cannot both start.
    _owner.value = this;
    try {
      await widget.onRecordingStarted?.call();
    } catch (_) {}
    bool started = false;
    bool busy = false;
    try {
      started = await recorder.start();
    } on VoiceRecorderBusy {
      busy = true;
    } catch (_) {
      started = false;
    }
    if (!mounted) {
      if (started) {
        await recorder.cancel();
      }
      _release();
      return;
    }
    if (!started) {
      _release();
      _show(busy ? 'Уже идёт запись.' : 'Нет доступа к микрофону.');
      return;
    }
    setState(() {
      _recording = true;
    });
  }

  void _show(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    unawaited(_interruptions?.cancel());
    _owner.removeListener(_onOwnerChanged);
    if (_recording) {
      unawaited(_recorder.cancel());
    }
    if (identical(_owner.value, this)) {
      // Not during unmount: other fields rebuild when the owner changes.
      final ValueNotifier<Object?> owner = _owner;
      final Object self = this;
      scheduleMicrotask(() {
        try {
          if (identical(owner.value, self)) {
            owner.value = null;
          }
        } catch (_) {
          // The whole scope is gone, and the notifier with it.
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool mic = widget.showMic && _supported;
    Widget? suffix;
    if (mic) {
      suffix = _processing
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              tooltip: _recording ? 'Остановить запись' : 'Диктовать',
              // While recording, stopping stays possible whatever else happens.
              onPressed: _recording || (widget.enabled && !_micTaken)
                  ? () => unawaited(_toggle())
                  : null,
              icon: Icon(
                _recording ? Icons.stop_circle_outlined : Icons.mic_none,
                color: _recording ? Theme.of(context).colorScheme.error : null,
              ),
            );
    }
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: _recording ? 'Идёт запись…' : widget.label,
        hintText: widget.hint,
        alignLabelWithHint: widget.maxLines > 1,
        suffixIcon: suffix,
      ),
    );
  }
}
