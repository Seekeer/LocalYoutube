import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/api_route.dart';

void main() {
  AppConfig config({bool enabled = true}) => AppConfig(
        apiBaseUrl:
            'https://api.example.invalid:9999',
        connectTimeoutMs: 15000,
        receiveTimeoutMs: 30000,
        sendTimeoutMs: 15000,
        enableLocalApiRoute: enabled,
        localApiHost: '192.0.2.10',
        localApiPort: 55,
        localApiProbeTimeoutMs: 37,
        localApiCacheTtlMs: 60000,
      );

  test('probes only the configured API origin and coalesces concurrent probes',
      () async {
    var probeCount = 0;
    final ApiRoute route = ApiRoute(
      config: config(),
      logService: LogService(),
      localProbe: (String host, int port, Duration timeout) {
        probeCount++;
        expect(host, '192.0.2.10');
        expect(port, 55);
        expect(timeout, const Duration(milliseconds: 37));
        return Future<bool>.value(true);
      },
    );

    final List<bool> results = await Future.wait(<Future<bool>>[
      route.useLocalFor(Uri.parse(
          'https://api.example.invalid:9999/api/a')),
      route.useLocalFor(Uri.parse(
          'https://api.example.invalid:9999/api/b')),
    ]);

    expect(results, <bool>[true, true]);
    expect(probeCount, 1);
    expect(
      await route.useLocalFor(Uri.parse('https://other.example.test:9999')),
      isFalse,
    );
  });

  test('failed probe is cached briefly and reset makes the next request probe',
      () async {
    var probeCount = 0;
    final ApiRoute route = ApiRoute(
      config: config(),
      logService: LogService(),
      localProbe: (_, __, ___) async {
        probeCount++;
        return false;
      },
    );

    expect(await route.useLocalFor(Uri.parse(
        'https://api.example.invalid:9999')), false);
    expect(await route.useLocalFor(Uri.parse(
        'https://api.example.invalid:9999')), false);
    expect(probeCount, 1);
    route.invalidate('network changed');
    expect(await route.useLocalFor(Uri.parse(
        'https://api.example.invalid:9999')), false);
    expect(probeCount, 2);
  });

  test('feature can be disabled without probing', () async {
    var probeCount = 0;
    final ApiRoute route = ApiRoute(
      config: config(enabled: false),
      logService: LogService(),
      localProbe: (_, __, ___) async {
        probeCount++;
        return true;
      },
    );
    expect(await route.useLocalFor(Uri.parse(
        'https://api.example.invalid:9999')), false);
    expect(probeCount, 0);
  });

  test('routes API requests to the local HTTP listener without duplicating query',
      () async {
    final ApiRoute route = ApiRoute(
      config: config(),
      logService: LogService(),
      localProbe: (_, __, ___) async => true,
    );
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(
      baseUrl: '${config().apiBaseUrl}/api',
      responseType: ResponseType.plain,
    ))
      ..httpClientAdapter = adapter
      ..interceptors.add(route.createDioInterceptor());

    await dio.get<dynamic>('/videos', queryParameters: <String, dynamic>{'page': 2});

    expect(adapter.uris.single.toString(),
        'http://192.0.2.10:55/api/videos?page=2');
  });

  test('uses public HTTPS URL when local probe fails', () async {
    final ApiRoute route = ApiRoute(
      config: config(),
      logService: LogService(),
      localProbe: (_, __, ___) async => false,
    );
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(
      baseUrl: '${config().apiBaseUrl}/api',
      responseType: ResponseType.plain,
    ))
      ..httpClientAdapter = adapter
      ..interceptors.add(route.createDioInterceptor());

    await dio.get<dynamic>('/videos');

    expect(adapter.uris.single.toString(),
        'https://api.example.invalid:9999/api/videos');
  });

  test('routes absolute SignalR URLs to the same local HTTP listener', () async {
    final ApiRoute route = ApiRoute(
      config: config(),
      logService: LogService(),
      localProbe: (_, __, ___) async => true,
    );
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(responseType: ResponseType.plain))
      ..httpClientAdapter = adapter
      ..interceptors.add(route.createDioInterceptor());

    await dio.get<dynamic>(
      'https://api.example.invalid:9999/player/negotiate',
      queryParameters: <String, dynamic>{'negotiateVersion': 1},
    );

    expect(adapter.uris.single.toString(),
        'http://192.0.2.10:55/player/negotiate?negotiateVersion=1');
  });

  test('routes native media URLs but leaves unrelated origins alone', () async {
    final ApiRoute route = ApiRoute(
      config: config(),
      logService: LogService(),
      localProbe: (_, __, ___) async => true,
    );
    final Uri media = Uri.parse(
        'https://api.example.invalid:9999/api/files/getFileById?fileId=42');
    final Uri unrelated = Uri.parse('https://cdn.example.test/video.mp4');

    expect((await route.routeMediaUri(media)).toString(),
        'http://192.0.2.10:55/api/files/getFileById?fileId=42');
    expect(await route.routeMediaUri(unrelated), unrelated);
  });

  test('local connection failure makes the next request use the public URL',
      () async {
    final ApiRoute route = ApiRoute(
      config: config(),
      logService: LogService(),
      localProbe: (_, __, ___) async => true,
    );
    final _RecordingAdapter adapter = _RecordingAdapter()..failNext = true;
    final Dio dio = Dio(BaseOptions(
      baseUrl: '${config().apiBaseUrl}/api',
      responseType: ResponseType.plain,
    ))
      ..httpClientAdapter = adapter
      ..interceptors.add(route.createDioInterceptor());

    await expectLater(dio.get<dynamic>('/videos'), throwsA(isA<DioException>()));
    await dio.get<dynamic>('/videos');

    expect(adapter.uris.map((Uri uri) => uri.toString()).toList(), <String>[
      'http://192.0.2.10:55/api/videos',
      'https://api.example.invalid:9999/api/videos',
    ]);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<Uri> uris = <Uri>[];
  bool failNext = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uris.add(options.uri);
    if (failNext) {
      failNext = false;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}
