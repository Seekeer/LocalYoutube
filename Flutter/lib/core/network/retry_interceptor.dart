import 'package:dio/dio.dart';

import '../logging/log_service.dart';
import 'retry_policy.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    required RetryPolicy policy,
    required LogService logService,
  })  : _dio = dio,
        _policy = policy,
        _logService = logService;

  static const String _attemptKey = 'retry_attempt';
  static const Set<String> _idempotentMethods = <String>{
    'GET',
    'HEAD',
    'PUT',
    'DELETE',
    'OPTIONS',
  };

  final Dio _dio;
  final RetryPolicy _policy;
  final LogService _logService;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions request = err.requestOptions;
    if (!_shouldRetry(request, err)) {
      handler.next(err);
      return;
    }

    final int attempt = (request.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= _policy.maxRetries) {
      handler.next(err);
      return;
    }

    final Duration delay = _policy.delayForAttempt(attempt);
    _logService.warn(
      'Retrying ${request.method} ${request.uri} after ${delay.inMilliseconds}ms',
    );
    await Future<void>.delayed(delay);

    try {
      final RequestOptions retryRequest = request.copyWith(
        extra: <String, dynamic>{
          ...request.extra,
          _attemptKey: attempt + 1,
        },
      );
      final Response<dynamic> response =
          await _dio.fetch<dynamic>(retryRequest);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _shouldRetry(RequestOptions request, DioException err) {
    if (request.extra['disableRetry'] == true) {
      return false;
    }

    final String method = request.method.toUpperCase();
    final bool isIdempotent = _idempotentMethods.contains(method) ||
        request.extra['idempotent'] == true;
    if (!isIdempotent) {
      return false;
    }

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final int? code = err.response?.statusCode;
        return code == 408 ||
            code == 429 ||
            code == 502 ||
            code == 503 ||
            code == 504;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
