import 'dart:io';

import 'package:dio/dio.dart';

import '../auth/session_tokens.dart';
import '../config/app_config.dart';
import '../logging/log_service.dart';
import 'api_route.dart';

class AuthApi {
  AuthApi({
    required AppConfig config,
    LogService? logService,
    ApiRoute? apiRoute,
  })  : _config = config,
        _logService = logService,
        _dio = Dio(
          BaseOptions(
            baseUrl: '${config.apiBaseUrl}/api',
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
            headers: <String, dynamic>{
              Headers.acceptHeader: Headers.jsonContentType,
            },
            connectTimeout: Duration(milliseconds: config.connectTimeoutMs),
            receiveTimeout: Duration(milliseconds: config.receiveTimeoutMs),
            sendTimeout: Duration(milliseconds: config.sendTimeoutMs),
          ),
        )..interceptors.add((apiRoute ??
                ApiRoute(
                  config: config,
                  logService: logService ?? LogService(),
                ))
            .createDioInterceptor());

  final AppConfig _config;
  final LogService? _logService;
  final Dio _dio;

  Future<SessionTokens?> login({
    required String userName,
    required String password,
  }) async {
    try {
      _logRequest('POST', '/account/login');
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/account/login',
        data: <String, dynamic>{
          'username': userName,
          'password': password,
        },
        options: Options(
          extra: <String, Object?>{
            'disableRetry': true,
            'skipAuthRefresh': true,
          },
        ),
      );
      _logResponse('POST', '/account/login', response.statusCode ?? 0);
      return _parseTokens(response.data, fallbackUserName: userName);
    } on DioException catch (error) {
      _logError('POST', '/account/login', error);
      rethrow;
    } catch (error, stackTrace) {
      _logService?.error('Auth API login failed', error, stackTrace);
      rethrow;
    }
  }

  Future<SessionTokens?> refreshToken({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) async {
    try {
      _logRequest('POST', '/account/refresh-token');
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/account/refresh-token',
        data: <String, dynamic>{
          'userName': userName,
          'refreshToken': refreshToken,
        },
        options: Options(
          headers: <String, dynamic>{
            HttpHeaders.authorizationHeader: 'Bearer $accessToken',
          },
          extra: <String, Object?>{
            'disableRetry': true,
            'skipAuthRefresh': true,
          },
        ),
      );
      _logResponse(
        'POST',
        '/account/refresh-token',
        response.statusCode ?? 0,
      );
      return _parseTokens(response.data, fallbackUserName: userName);
    } on DioException catch (error) {
      _logError('POST', '/account/refresh-token', error);
      rethrow;
    } catch (error, stackTrace) {
      _logService?.error('Auth API refresh failed', error, stackTrace);
      rethrow;
    }
  }

  Future<void> logout({
    required String accessToken,
  }) async {
    try {
      _logRequest('POST', '/account/logout');
      await _dio.post<dynamic>(
        '/account/logout',
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer $accessToken',
          },
          extra: <String, Object?>{
            'disableRetry': true,
            'skipAuthRefresh': true,
          },
        ),
      );
      _logResponse('POST', '/account/logout', 200);
    } on DioException catch (error) {
      _logError('POST', '/account/logout', error);
      rethrow;
    } catch (error, stackTrace) {
      _logService?.error('Auth API logout failed', error, stackTrace);
      rethrow;
    }
  }

  SessionTokens? _parseTokens(
    dynamic data, {
    required String fallbackUserName,
  }) {
    if (data is! Map) {
      return null;
    }
    final Map<String, dynamic> map = data.map(
      (dynamic key, dynamic value) => MapEntry('$key', value),
    );

    final String nextUserName =
        (map['username'] ?? map['userName'] ?? fallbackUserName).toString();
    final String nextAccessToken = (map['accessToken'] ?? '').toString();
    final String nextRefreshToken = (map['refreshToken'] ?? '').toString();
    if (nextAccessToken.isEmpty || nextRefreshToken.isEmpty) {
      return null;
    }
    return SessionTokens(
      userName: nextUserName,
      accessToken: nextAccessToken,
      refreshToken: nextRefreshToken,
    );
  }

  void _logRequest(String method, String path) {
    if (!_config.enableNetworkLogs) {
      return;
    }
    _logService?.info('HTTP -> $method ${_config.apiBaseUrl}$path');
  }

  void _logResponse(String method, String path, int statusCode) {
    if (!_config.enableNetworkLogs) {
      return;
    }
    _logService?.info('HTTP <- $statusCode $method ${_config.apiBaseUrl}$path');
  }

  void _logError(String method, String path, DioException error) {
    if (!_config.enableNetworkLogs) {
      return;
    }
    _logService?.info(
      'HTTP xx ${error.response?.statusCode ?? 0} $method ${_config.apiBaseUrl}$path (${error.type.name}: ${error.message})',
    );
  }
}
