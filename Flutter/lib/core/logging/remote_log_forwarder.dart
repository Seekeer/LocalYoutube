import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../auth/token_repository.dart';
import 'log_service.dart';

/// Best-effort delivery, independent of application HTTP interceptors and retries.
/// Offline diagnostics remain in LogService's local file.
class RemoteLogForwarder {
  RemoteLogForwarder({
    required LogService logService,
    required TokenRepository tokens,
    required String apiBaseUrl,
    Dio? client,
    String version = 'unknown',
  })  : _tokens = tokens,
        _endpoint =
            '${apiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/client-logs',
        _client = client ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
            )),
        _version = version {
    _subscription = logService.entryStream.listen((entry) {
      if (entry.level == LogLevel.debug) return;
      if (_pending.length >= 100) _pending.removeAt(0);
      _pending.add(entry);
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(flush());
    });
    unawaited(_readVersion());
  }

  final TokenRepository _tokens;
  final String _endpoint;
  final Dio _client;
  final List<LogEntry> _pending = [];
  late final StreamSubscription<LogEntry> _subscription;
  late final Timer _timer;
  String _version;
  bool _sending = false;
  bool _disposed = false;

  Future<void> _readVersion() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('org.localtube.app/app_updates');
      final info =
          await channel.invokeMapMethod<String, dynamic>('installedApp');
      if (info != null)
        _version = '${info['versionName']}+${info['versionCode']}';
    } catch (_) {
      // Package identity is optional on platforms without the native channel.
    }
  }

  Future<void> flush() async {
    if (_disposed || _sending || _pending.isEmpty) return;
    _sending = true;
    try {
      final session = await _tokens.read();
      if (_disposed || session == null || session.accessToken.isEmpty) return;
      final entries = _pending.take(5).toList(growable: false);
      _pending.removeRange(0, entries.length);
      await _client.post<Object?>(
        _endpoint,
        data: {
          'source': 'flutter',
          'version': _limit(_version, 128),
          'entries': entries
              .map((entry) => {
                    'timestampUtc': entry.timestampUtc.toIso8601String(),
                    'level': entry.level.name,
                    'message': _limit(
                        entry.message.isEmpty ? '[empty]' : entry.message,
                        1000),
                    if (entry.error != null)
                      'error': _limit(entry.error!, 1000),
                    if (entry.stackTrace != null)
                      'stackTrace': _limit(entry.stackTrace!, 2000),
                  })
              .toList(growable: false),
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${session.accessToken}'}),
      );
    } catch (_) {
      // Do not log telemetry failures or feed them back into this queue.
    } finally {
      _sending = false;
    }
  }

  String _limit(String value, int length) =>
      value.length <= length ? value : value.substring(0, length);

  Future<void> dispose() async {
    _disposed = true;
    _timer.cancel();
    await _subscription.cancel();
    _client.close(force: true);
    _pending.clear();
  }
}
