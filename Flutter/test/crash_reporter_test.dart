import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/crash/crash_reporter.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';

void main() {
  test(
    'sends sanitized crash payload in release mode when endpoint is configured',
    () async {
      final _CrashServer server = await _CrashServer.start();
      addTearDown(server.close);

      final LogService logService = LogService();
      final ReleaseCrashReporter reporter = ReleaseCrashReporter(
        config: _testConfig(server.endpoint.toString()),
        logService: logService,
        isReleaseBuild: true,
      );
      await reporter.initialize();

      await reporter.recordError(
        Exception('apiKey=secretValue'),
        StackTrace.fromString('Authorization: Bearer stackTokenValue'),
        reason: 'refresh_token=refreshSecretValue',
        fatal: true,
      );

      await server.waitForRequestCount(1);
      expect(server.requests, hasLength(1));

      final _CapturedRequest request = server.requests.single;
      expect(request.method, 'POST');

      final Map<String, dynamic> payload =
          jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['fatal'], isTrue);
      expect(payload['reason'], contains('refresh_token=***'));
      expect(payload['error'], contains('apiKey=***'));
      expect(payload['error'], isNot(contains('secretValue')));
      expect(payload['stackTrace'], contains('Bearer ***'));
      expect(payload['stackTrace'], isNot(contains('stackTokenValue')));
    },
  );

  test('does not send crash payload when release mode is disabled', () async {
    final _CrashServer server = await _CrashServer.start();
    addTearDown(server.close);

    final ReleaseCrashReporter reporter = ReleaseCrashReporter(
      config: _testConfig(server.endpoint.toString()),
      logService: LogService(),
      isReleaseBuild: false,
    );
    await reporter.initialize();

    await reporter.recordError(
      StateError('boom'),
      StackTrace.fromString('stack'),
      reason: 'non-release smoke',
      fatal: true,
    );

    await server.waitForRequestCount(
      1,
      timeout: const Duration(milliseconds: 300),
    );
    expect(server.requests, isEmpty);
  });

  test('recordFlutterError sends context reason and sanitized exception text',
      () async {
    final _CrashServer server = await _CrashServer.start();
    addTearDown(server.close);

    final ReleaseCrashReporter reporter = ReleaseCrashReporter(
      config: _testConfig(server.endpoint.toString()),
      logService: LogService(),
      isReleaseBuild: true,
    );
    await reporter.initialize();

    final FlutterErrorDetails details = FlutterErrorDetails(
      exception: StateError('password=mySecretValue'),
      stack: StackTrace.fromString('stack'),
      context: ErrorDescription('during widget build'),
    );

    await reporter.recordFlutterError(details);

    await server.waitForRequestCount(1);
    expect(server.requests, hasLength(1));

    final Map<String, dynamic> payload =
        jsonDecode(server.requests.single.body) as Map<String, dynamic>;
    expect(payload['reason'], contains('during widget build'));
    expect(payload['error'], contains('password=***'));
    expect(payload['error'], isNot(contains('mySecretValue')));
  });
}

AppConfig _testConfig(String crashReportUrl) {
  return AppConfig(
    apiBaseUrl: 'https://example.local',
    connectTimeoutMs: 500,
    receiveTimeoutMs: 500,
    sendTimeoutMs: 500,
    crashReportUrl: crashReportUrl,
  );
}

class _CrashServer {
  _CrashServer._(this._server) {
    _subscription = _server.listen(_handleRequest);
  }

  final HttpServer _server;
  late final StreamSubscription<HttpRequest> _subscription;
  final List<_CapturedRequest> requests = <_CapturedRequest>[];

  static Future<_CrashServer> start() async {
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _CrashServer._(server);
  }

  Uri get endpoint => Uri(
        scheme: 'http',
        host: _server.address.address,
        port: _server.port,
        path: '/crash',
      );

  Future<void> waitForRequestCount(
    int expected, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (requests.length < expected && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    requests.add(
      _CapturedRequest(
        method: request.method,
        body: body,
      ),
    );

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write('{}');
    await request.response.close();
  }
}

class _CapturedRequest {
  const _CapturedRequest({
    required this.method,
    required this.body,
  });

  final String method;
  final String body;
}
