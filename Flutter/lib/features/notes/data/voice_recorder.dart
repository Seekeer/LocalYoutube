import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Records short voice clips for dictation. Clips live in the app's support
/// directory until they are recognized, so a clip made offline survives restarts.
///
/// There is one microphone: only one recording runs at a time, and [start]
/// throws [VoiceRecorderBusy] while another one is running.
abstract class VoiceRecorder {
  /// Whether this device can record at all.
  Future<bool> isSupported();

  /// Starts recording and returns false when the microphone is not allowed.
  Future<bool> start();

  /// Stops recording and returns the clip file path, or null if nothing was recorded.
  Future<String?> stop();

  /// Drops an unfinished recording.
  Future<void> cancel();

  /// Fires when the system stopped the recording on its own (the app went to
  /// the background). The owner then calls [stop] to collect the clip.
  Stream<void> get interruptions;
}

/// Thrown by [VoiceRecorder.start] while another recording is running.
class VoiceRecorderBusy implements Exception {
  const VoiceRecorderBusy();

  @override
  String toString() => 'Уже идёт запись.';
}

/// Android MediaRecorder behind a method channel (see MainActivity.kt).
/// One Android API does not justify another Flutter plugin.
class PlatformVoiceRecorder implements VoiceRecorder {
  PlatformVoiceRecorder({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('org.localtube.app/voice_recorder');

  final MethodChannel _channel;
  final StreamController<void> _interruptions =
      StreamController<void>.broadcast();
  String? _path;
  bool _starting = false;
  bool _listening = false;

  @override
  Stream<void> get interruptions => _interruptions.stream;

  @override
  Future<bool> isSupported() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> start() async {
    // A second recording would release the first one natively and orphan
    // its clip.
    if (_path != null || _starting) {
      throw const VoiceRecorderBusy();
    }
    _starting = true;
    try {
      _listen();
      final bool allowed =
          await _channel.invokeMethod<bool>('requestPermission') ?? false;
      if (!allowed) {
        return false;
      }
      final Directory support = await getApplicationSupportDirectory();
      final Directory dir = Directory('${support.path}/voice-drafts');
      await dir.create(recursive: true);
      final String path =
          '${dir.path}/clip-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _channel
          .invokeMethod<void>('start', <String, dynamic>{'path': path});
      _path = path;
      return true;
    } finally {
      _starting = false;
    }
  }

  @override
  Future<String?> stop() async {
    final String? path = _path;
    _path = null;
    if (path == null) {
      return null;
    }
    bool stopped = false;
    try {
      // false: MediaRecorder had no valid data to finish the file with.
      stopped = await _channel.invokeMethod<bool>('stop') ?? true;
    } catch (_) {
      stopped = false;
    }
    final File file = File(path);
    try {
      if (stopped && await file.exists() && await file.length() > 0) {
        return path;
      }
    } catch (_) {}
    await _delete(file);
    return null;
  }

  @override
  Future<void> cancel() async {
    final String? path = _path;
    _path = null;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
    if (path != null) {
      await _delete(File(path));
    }
  }

  /// The handler is installed on first use, so merely creating the recorder
  /// does not touch the platform channel.
  void _listen() {
    if (_listening) {
      return;
    }
    _listening = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'interrupted' && _path != null) {
        _interruptions.add(null);
      }
      return null;
    });
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

final Provider<VoiceRecorder> voiceRecorderProvider =
    Provider<VoiceRecorder>((Ref ref) => PlatformVoiceRecorder());
