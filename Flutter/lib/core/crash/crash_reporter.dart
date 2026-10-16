import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../logging/log_service.dart';

abstract interface class CrashReporter {
  Future<void> initialize();

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  });

  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  });
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {}

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {}
}

class ReleaseCrashReporter implements CrashReporter {
  ReleaseCrashReporter({
    required AppConfig config,
    required LogService logService,
    Dio? dio,
    bool isReleaseBuild = kReleaseMode,
  })  : _config = config,
        _logService = logService,
        _isReleaseBuild = isReleaseBuild,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: Duration(milliseconds: config.connectTimeoutMs),
                receiveTimeout: Duration(milliseconds: config.receiveTimeoutMs),
                sendTimeout: Duration(milliseconds: config.sendTimeoutMs),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
                headers: <String, Object>{
                  Headers.acceptHeader: Headers.jsonContentType,
                },
              ),
            );

  final AppConfig _config;
  final LogService _logService;
  final bool _isReleaseBuild;
  final Dio _dio;

  Uri? _endpoint;

  bool get _enabled =>
      _isReleaseBuild && _config.enableCrashReporting && _endpoint != null;

  @override
  Future<void> initialize() async {
    final String crashReportUrl = _config.crashReportUrl.trim();
    if (!_isReleaseBuild ||
        !_config.enableCrashReporting ||
        crashReportUrl.isEmpty) {
      return;
    }

    try {
      _endpoint = Uri.parse(crashReportUrl);
    } catch (error) {
      _endpoint = null;
      _logService.warn(
        'Crash reporting disabled because LOCALTUBE_CRASH_REPORT_URL is invalid: $error',
      );
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    _logService.error(reason ?? 'Unhandled error', error, stackTrace);
    if (!_enabled) {
      return;
    }

    final Uri endpoint = _endpoint!;
    try {
      await _dio.postUri<Object?>(
        endpoint,
        data: <String, Object?>{
          'timestampUtc': DateTime.now().toUtc().toIso8601String(),
          'fatal': fatal,
          'reason':
              _limitText(_logService.sanitize(reason ?? 'Unhandled error')),
          'error': _limitText(_logService.sanitize(error.toString())),
          'stackTrace': _limitText(_logService.sanitize(stackTrace.toString())),
        },
        options: Options(
          headers: <String, Object>{
            Headers.contentTypeHeader: Headers.jsonContentType,
          },
          extra: const <String, Object>{
            'skipAuthRefresh': true,
            'disableRetry': true,
          },
        ),
      );
    } catch (sendError, sendStackTrace) {
      _logService.error(
        'Crash report submit failed',
        sendError,
        sendStackTrace,
      );
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) {
    return recordError(
      details.exception,
      details.stack ?? StackTrace.empty,
      reason:
          details.context?.toDescription() ?? details.library ?? 'FlutterError',
      fatal: fatal,
    );
  }

  String _limitText(String value, {int maxLength = 12000}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength)}...[truncated]';
  }
}
