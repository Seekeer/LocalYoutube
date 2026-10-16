import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../app/router/auth_notifier.dart';
import '../auth/session_tokens.dart';
import '../auth/token_repository.dart';
import '../logging/log_service.dart';
import 'auth_api.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required AuthApi authApi,
    required TokenRepository tokenRepository,
    required AuthNotifier authNotifier,
    required LogService logService,
  })  : _dio = dio,
        _authApi = authApi,
        _tokenRepository = tokenRepository,
        _authNotifier = authNotifier,
        _logService = logService;

  static const String _retryKey = 'auth_retry';

  final Dio _dio;
  final AuthApi _authApi;
  final TokenRepository _tokenRepository;
  final AuthNotifier _authNotifier;
  final LogService _logService;

  Completer<bool>? _refreshCompleter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final SessionTokens? session = await _tokenRepository.read();
    if (session != null && session.accessToken.isNotEmpty) {
      options.headers[HttpHeaders.authorizationHeader] =
          'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_canRefresh(err.requestOptions, err.response?.statusCode)) {
      handler.next(err);
      return;
    }

    final bool refreshed = await _singleFlightRefresh();
    if (!refreshed) {
      handler.next(err);
      return;
    }

    final SessionTokens? nextSession = await _tokenRepository.read();
    if (nextSession == null || nextSession.accessToken.isEmpty) {
      handler.next(err);
      return;
    }

    try {
      final RequestOptions retryRequest = err.requestOptions.copyWith(
        headers: <String, dynamic>{
          ...err.requestOptions.headers,
          HttpHeaders.authorizationHeader: 'Bearer ${nextSession.accessToken}',
        },
        extra: <String, dynamic>{
          ...err.requestOptions.extra,
          _retryKey: true,
        },
      );

      final Response<dynamic> response =
          await _dio.fetch<dynamic>(retryRequest);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _canRefresh(RequestOptions request, int? statusCode) {
    if (request.extra['skipAuthRefresh'] == true) {
      return false;
    }
    if (request.extra[_retryKey] == true) {
      return false;
    }
    if (statusCode != 401) {
      return false;
    }
    final String path = request.path;
    if (path.contains('/account/login') ||
        path.contains('/account/refresh-token')) {
      return false;
    }
    return true;
  }

  Future<bool> _singleFlightRefresh() async {
    final Completer<bool>? current = _refreshCompleter;
    if (current != null) {
      return current.future;
    }

    final Completer<bool> completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final SessionTokens? session = await _tokenRepository.read();
      if (session == null || !session.isValid) {
        await _tokenRepository.clearSession();
        _authNotifier.enterSignedOut(
          reason: AuthTransitionReason.refreshInvalidSession,
        );
        completer.complete(false);
        return await completer.future;
      }

      final SessionTokens? refreshed = await _authApi.refreshToken(
        userName: session.userName,
        refreshToken: session.refreshToken,
        accessToken: session.accessToken,
      );
      if (refreshed == null || !refreshed.isValid) {
        await _tokenRepository.clearSession();
        _authNotifier.enterSignedOut(
          reason: AuthTransitionReason.refreshInvalidSession,
        );
        completer.complete(false);
        return await completer.future;
      }

      await _tokenRepository.save(refreshed);
      _authNotifier.enterOnlineAuthenticated(
        reason: AuthTransitionReason.refreshSucceeded,
      );
      completer.complete(true);
      return await completer.future;
    } catch (error, stackTrace) {
      _logService.error('Refresh token failed', error, stackTrace);
      if (_isAuthoritativeAuthFailure(error)) {
        await _tokenRepository.clearSession();
        _authNotifier.enterSignedOut(
          reason: AuthTransitionReason.refreshInvalidSession,
        );
      }
      completer.complete(false);
      return completer.future;
    } finally {
      _refreshCompleter = null;
    }
  }

  bool _isAuthoritativeAuthFailure(Object error) {
    if (error is! DioException) {
      return false;
    }
    final int? statusCode = error.response?.statusCode;
    return statusCode == 400 ||
        statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 422;
  }
}
