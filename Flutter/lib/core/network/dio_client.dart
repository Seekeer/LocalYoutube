import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../logging/log_service.dart';
import 'auth_interceptor.dart';
import 'api_route.dart';
import 'retry_interceptor.dart';
import 'retry_policy.dart';

typedef AuthInterceptorFactory = AuthInterceptor Function(Dio dio);

class DioClient {
  static Dio build({
    required AppConfig config,
    required RetryPolicy retryPolicy,
    required AuthInterceptorFactory authInterceptorFactory,
    required LogService logService,
    required ApiRoute apiRoute,
  }) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: '${config.apiBaseUrl}/api',
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        connectTimeout: Duration(milliseconds: config.connectTimeoutMs),
        receiveTimeout: Duration(milliseconds: config.receiveTimeoutMs),
        sendTimeout: Duration(milliseconds: config.sendTimeoutMs),
        headers: <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
        },
      ),
    );
    dio.interceptors.add(apiRoute.createDioInterceptor());

    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        policy: retryPolicy,
        logService: logService,
      ),
    );
    dio.interceptors.add(authInterceptorFactory(dio));
    if (config.enableNetworkLogs) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (
            RequestOptions options,
            RequestInterceptorHandler handler,
          ) {
            logService.info(
              'HTTP -> ${options.method} ${logService.sanitize(options.uri.toString())}',
            );
            handler.next(options);
          },
          onResponse: (
            Response<dynamic> response,
            ResponseInterceptorHandler handler,
          ) {
            final RequestOptions request = response.requestOptions;
            logService.info(
              'HTTP <- ${response.statusCode ?? 0} ${request.method} ${logService.sanitize(request.uri.toString())}',
            );
            handler.next(response);
          },
          onError: (DioException error, ErrorInterceptorHandler handler) {
            final RequestOptions request = error.requestOptions;
            logService.info(
              'HTTP xx ${error.response?.statusCode ?? 0} ${request.method} ${logService.sanitize(request.uri.toString())}',
            );
            handler.next(error);
          },
        ),
      );
    }

    return dio;
  }
}
