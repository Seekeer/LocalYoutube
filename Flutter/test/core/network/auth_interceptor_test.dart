import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/auth_api.dart';
import 'package:localtube_flutter/core/network/auth_interceptor.dart';

void main() {
  test(
      'transient refresh exception keeps session tokens and does not force signed out',
      () async {
    final _MemoryTokenRepository tokenRepository = _MemoryTokenRepository(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );
    final _RecordingErrorHandler handler = _RecordingErrorHandler();
    final DioException requestError = DioException(
      requestOptions: RequestOptions(path: '/videos'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/videos'),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );

    final AuthInterceptor interceptor = AuthInterceptor(
      dio: Dio(),
      authApi: _ThrowingAuthApi(
        DioException(
          requestOptions: RequestOptions(path: '/account/refresh-token'),
          type: DioExceptionType.connectionError,
        ),
      ),
      tokenRepository: tokenRepository,
      authNotifier: authNotifier,
      logService: _NoopLogService(),
    );

    await interceptor.onError(requestError, handler);

    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.clearSessionCalls, 0);
    expect(tokenRepository.clearAllAuthStateCalls, 0);
    expect(authNotifier.accessMode, AppAccessMode.onlineAuthenticated);
    expect(authNotifier.lastTransitionReason, isNull);
    expect(handler.nextError, same(requestError));
    expect(handler.resolveResponse, isNull);
  });

  test('interceptor does not sign out after refresh timeout', () async {
    final _MemoryTokenRepository tokenRepository = _MemoryTokenRepository(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );
    final _RecordingErrorHandler handler = _RecordingErrorHandler();
    final DioException requestError = DioException(
      requestOptions: RequestOptions(path: '/videos'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/videos'),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );

    final AuthInterceptor interceptor = AuthInterceptor(
      dio: Dio(),
      authApi: _ThrowingAuthApi(
        DioException(
          requestOptions: RequestOptions(path: '/account/refresh-token'),
          type: DioExceptionType.receiveTimeout,
        ),
      ),
      tokenRepository: tokenRepository,
      authNotifier: authNotifier,
      logService: _NoopLogService(),
    );

    await interceptor.onError(requestError, handler);

    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.clearSessionCalls, 0);
    expect(authNotifier.accessMode, AppAccessMode.onlineAuthenticated);
    expect(handler.nextError, same(requestError));
  });

  test('refresh 401 exception clears session tokens and signs out', () async {
    final _MemoryTokenRepository tokenRepository = _MemoryTokenRepository(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );
    final _RecordingErrorHandler handler = _RecordingErrorHandler();
    final DioException requestError = DioException(
      requestOptions: RequestOptions(path: '/videos'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/videos'),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );

    final AuthInterceptor interceptor = AuthInterceptor(
      dio: Dio(),
      authApi: _ThrowingAuthApi(
        DioException(
          requestOptions: RequestOptions(path: '/account/refresh-token'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/account/refresh-token'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
      ),
      tokenRepository: tokenRepository,
      authNotifier: authNotifier,
      logService: _NoopLogService(),
    );

    await interceptor.onError(requestError, handler);

    expect(await tokenRepository.read(), isNull);
    expect(tokenRepository.clearSessionCalls, 1);
    expect(tokenRepository.clearAllAuthStateCalls, 0);
    expect(authNotifier.accessMode, AppAccessMode.signedOut);
    expect(
      authNotifier.lastTransitionReason,
      AuthTransitionReason.refreshInvalidSession,
    );
    expect(handler.nextError, same(requestError));
    expect(handler.resolveResponse, isNull);
  });

  test('refresh 400 and 422 exceptions clear session tokens and sign out',
      () async {
    for (final int statusCode in <int>[400, 422]) {
      final _MemoryTokenRepository tokenRepository = _MemoryTokenRepository(
        const SessionTokens(
          userName: 'user',
          accessToken: 'access',
          refreshToken: 'refresh',
        ),
      );
      final AuthNotifier authNotifier = AuthNotifier(
        initialMode: AppAccessMode.onlineAuthenticated,
      );
      final _RecordingErrorHandler handler = _RecordingErrorHandler();
      final DioException requestError = DioException(
        requestOptions: RequestOptions(path: '/videos'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/videos'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );

      final AuthInterceptor interceptor = AuthInterceptor(
        dio: Dio(),
        authApi: _ThrowingAuthApi(
          DioException(
            requestOptions: RequestOptions(path: '/account/refresh-token'),
            response: Response<dynamic>(
              requestOptions: RequestOptions(path: '/account/refresh-token'),
              statusCode: statusCode,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
        tokenRepository: tokenRepository,
        authNotifier: authNotifier,
        logService: _NoopLogService(),
      );

      await interceptor.onError(requestError, handler);

      expect(await tokenRepository.read(), isNull);
      expect(tokenRepository.clearSessionCalls, 1);
      expect(tokenRepository.clearAllAuthStateCalls, 0);
      expect(authNotifier.accessMode, AppAccessMode.signedOut);
      expect(
        authNotifier.lastTransitionReason,
        AuthTransitionReason.refreshInvalidSession,
      );
      expect(handler.nextError, same(requestError));
      expect(handler.resolveResponse, isNull);
    }
  });
}

class _MemoryTokenRepository implements TokenRepository {
  _MemoryTokenRepository(this._tokens);

  SessionTokens? _tokens;
  int clearSessionCalls = 0;
  int clearAllAuthStateCalls = 0;

  @override
  Future<void> clearAllAuthState() async {
    clearAllAuthStateCalls++;
    _tokens = null;
  }

  @override
  Future<void> clearSession() async {
    clearSessionCalls++;
    _tokens = null;
  }

  @override
  Future<bool> hasAccessToken() async =>
      _tokens?.accessToken.isNotEmpty ?? false;

  @override
  Future<SessionTokens?> read() async => _tokens;

  @override
  Future<void> save(SessionTokens tokens) async {
    _tokens = tokens;
  }
}

class _ThrowingAuthApi extends AuthApi {
  _ThrowingAuthApi(this._error)
      : super(
          config: const AppConfig(
            apiBaseUrl: 'https://example.local',
            connectTimeoutMs: 500,
            receiveTimeoutMs: 500,
            sendTimeoutMs: 500,
          ),
        );

  final DioException _error;

  @override
  Future<SessionTokens?> refreshToken({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) {
    throw _error;
  }
}

class _RecordingErrorHandler extends ErrorInterceptorHandler {
  DioException? nextError;
  Response<dynamic>? resolveResponse;

  @override
  void next(DioException err) {
    nextError = err;
  }

  @override
  void resolve(Response<dynamic> response) {
    resolveResponse = response;
  }
}

class _NoopLogService extends LogService {
  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, Object error, StackTrace stackTrace) {}
}
