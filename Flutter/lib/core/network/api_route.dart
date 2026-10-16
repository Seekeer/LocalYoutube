import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:signalr_netcore/signalr_http_client.dart';

import '../config/app_config.dart';
import '../logging/log_service.dart';

/// Routes the public HTTPS API to its HTTP listener when the LAN is available.
class ApiRoute {
  ApiRoute({
    required this.config,
    required this.logService,
    this.localProbe,
  });

  final AppConfig config;
  final LogService logService;
  final Future<bool> Function(String host, int port, Duration timeout)?
      localProbe;

  Future<bool>? _probeInFlight;
  DateTime? _routeExpiresAt;
  bool _useLocal = false;

  Uri get apiUri => Uri.parse(config.apiBaseUrl);

  Uri get localUri => Uri(
        scheme: 'http',
        host: config.localApiHost.trim(),
        port: config.localApiPort,
      );

  bool matches(Uri uri) {
    final Uri base = apiUri;
    return config.enableLocalApiRoute &&
        base.scheme == 'https' &&
        uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.port == base.port &&
        config.localApiHost.trim().isNotEmpty &&
        config.localApiPort > 0;
  }

  Future<bool> useLocalFor(Uri uri) async {
    if (!matches(uri)) {
      return false;
    }
    final DateTime now = DateTime.now();
    if (_routeExpiresAt != null && now.isBefore(_routeExpiresAt!)) {
      return _useLocal;
    }
    _probeInFlight ??= _probe().whenComplete(() => _probeInFlight = null);
    return _probeInFlight!;
  }

  /// Resolves URLs consumed by native media clients, which bypass Dio.
  Future<Uri> routeMediaUri(Uri uri) async {
    if (!await useLocalFor(uri)) {
      return uri;
    }
    final Uri local = localUri;
    return uri.replace(
      scheme: local.scheme,
      host: local.host,
      port: local.port,
    );
  }

  Future<bool> _probe() async {
    bool available = false;
    try {
      final Duration timeout =
          Duration(milliseconds: config.localApiProbeTimeoutMs);
      if (localProbe != null) {
        available = await localProbe!(
          config.localApiHost.trim(),
          config.localApiPort,
          timeout,
        ).timeout(timeout);
      } else {
        final Socket socket = await Socket.connect(
          config.localApiHost.trim(),
          config.localApiPort,
          timeout: timeout,
        );
        socket.destroy();
        available = true;
      }
    } catch (error) {
      logService.info('API local route unavailable: ${_safeReason(error)}');
    }
    _useLocal = available;
    _routeExpiresAt = DateTime.now().add(
      Duration(milliseconds: config.localApiCacheTtlMs),
    );
    logService.info(
      'API route selected: ${available ? 'local' : 'domain'} '
      '(probe=${config.localApiHost}:${config.localApiPort})',
    );
    return available;
  }

  void invalidate(String reason) {
    _routeExpiresAt = null;
    _useLocal = false;
    logService.info('API route reset: ${_safeReason(reason)}');
  }

  void markLocalUnavailable() {
    _useLocal = false;
    _routeExpiresAt = DateTime.now().add(
      Duration(milliseconds: config.localApiCacheTtlMs),
    );
    logService.info('API local route connection failed; using domain');
  }

  Interceptor createDioInterceptor() => _ApiRouteInterceptor(this);

  /// SignalR's WebSocket implementation does not expose a socket factory. This
  /// HTTP client is used with Long Polling so the same route applies.
  SignalRHttpClient createSignalRClient() => _RoutedSignalRHttpClient(this);

  static String _safeReason(Object error) => error.runtimeType.toString();
}

class _ApiRouteInterceptor extends Interceptor {
  _ApiRouteInterceptor(this._route);

  static const String _originalPathKey = 'apiRouteOriginalPath';
  static const String _originalBaseUrlKey = 'apiRouteOriginalBaseUrl';

  final ApiRoute _route;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (await _route.useLocalFor(options.uri)) {
      options.extra[_originalPathKey] = options.path;
      options.extra[_originalBaseUrlKey] = options.baseUrl;
      final Uri local = _route.localUri;
      if (Uri.tryParse(options.path)?.hasScheme ?? false) {
        options.path = Uri.parse(options.path)
            .replace(scheme: local.scheme, host: local.host, port: local.port)
            .toString();
      } else {
        options.baseUrl = Uri.parse(options.baseUrl)
            .replace(scheme: local.scheme, host: local.host, port: local.port)
            .toString();
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    final RequestOptions options = error.requestOptions;
    if (options.extra.containsKey(_originalPathKey) &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout)) {
      options.path = options.extra.remove(_originalPathKey) as String;
      options.baseUrl = options.extra.remove(_originalBaseUrlKey) as String;
      _route.markLocalUnavailable();
    }
    handler.next(error);
  }
}

class _RoutedSignalRHttpClient extends SignalRHttpClient {
  _RoutedSignalRHttpClient(this._route);

  final ApiRoute _route;

  @override
  Future<SignalRHttpResponse> send(SignalRHttpRequest request) async {
    final Dio dio = Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        connectTimeout: Duration(milliseconds: _route.config.connectTimeoutMs),
        receiveTimeout: Duration(
            milliseconds: request.timeout ?? _route.config.receiveTimeoutMs),
        sendTimeout: Duration(milliseconds: _route.config.sendTimeoutMs),
      ),
    )..interceptors.add(_route.createDioInterceptor());
    final Response<dynamic> response = await dio.request<dynamic>(
      request.url!,
      data: request.content,
      options: Options(
        method: request.method ?? 'GET',
        headers: request.headers?.asMap,
      ),
    );
    return SignalRHttpResponse(
      response.statusCode ?? 0,
      statusText: response.statusMessage,
      content: response.data,
    );
  }
}
