import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/auth_api.dart';
import 'package:localtube_flutter/features/player/data/stream_authorization_header_provider.dart';

void main() {
  late _InMemoryTokenRepository tokenRepository;
  late _FakeAuthApi authApi;
  late StreamAuthorizationHeaderProvider provider;

  setUp(() {
    tokenRepository = _InMemoryTokenRepository();
    authApi = _FakeAuthApi();
    provider = StreamAuthorizationHeaderProvider(
      authApi: authApi,
      tokenRepository: tokenRepository,
      logService: _NoopLogService(),
    );
  });

  test(
      'buildHeaders returns success with stored token when refresh is not requested',
      () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'stored_access',
        refreshToken: 'stored_refresh',
      ),
    );

    final StreamAuthorizationHeaderResult result = await provider.buildHeaders(
      refreshSession: false,
      reason: 'test-no-refresh',
    );

    expect(result.isSuccess, isTrue);
    expect(
      result.headers[HttpHeaders.authorizationHeader],
      'Bearer stored_access',
    );
    expect(result.failure, isNull);
    expect(authApi.refreshCalls, 0);
  });

  test('buildHeaders returns success with refreshed token for remote playback',
      () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
      ),
    );
    authApi.refreshResult = const SessionTokens(
      userName: 'user',
      accessToken: 'new_access',
      refreshToken: 'new_refresh',
    );

    final StreamAuthorizationHeaderResult result = await provider.buildHeaders(
      refreshSession: true,
      reason: 'test-refresh',
    );

    expect(authApi.refreshCalls, 1);
    expect(authApi.lastRefreshUserName, 'user');
    expect(authApi.lastRefreshToken, 'old_refresh');
    expect(result.isSuccess, isTrue);
    expect(
      result.headers[HttpHeaders.authorizationHeader],
      'Bearer new_access',
    );
    expect(result.failure, isNull);
    final SessionTokens? stored = await tokenRepository.read();
    expect(stored?.accessToken, 'new_access');
    expect(stored?.refreshToken, 'new_refresh');
  });

  test(
      'buildHeaders returns failure instead of falling back to stored token when refresh throws',
      () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
      ),
    );
    authApi.throwOnRefresh = StateError('refresh unavailable');

    final StreamAuthorizationHeaderResult result = await provider.buildHeaders(
      refreshSession: true,
      reason: 'test-refresh-failure',
    );

    expect(authApi.refreshCalls, 1);
    expect(result.isFailure, isTrue);
    expect(result.headers, isEmpty);
    expect(
      result.failure?.reason,
      StreamAuthorizationFailureReason.refreshFailed,
    );
    expect(result.failure?.message, contains('refresh'));
    final SessionTokens? stored = await tokenRepository.read();
    expect(stored?.accessToken, 'old_access');
    expect(stored?.refreshToken, 'old_refresh');
  });

  test(
      'buildHeaders returns failure when refresh throws and stored playback token is invalid',
      () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: '   ',
        refreshToken: 'old_refresh',
      ),
    );
    authApi.throwOnRefresh = StateError('refresh unavailable');

    final StreamAuthorizationHeaderResult result = await provider.buildHeaders(
      refreshSession: true,
      reason: 'test-refresh-failure-invalid-token',
    );

    expect(authApi.refreshCalls, 1);
    expect(result.isFailure, isTrue);
    expect(result.headers, isEmpty);
    expect(
      result.failure?.reason,
      StreamAuthorizationFailureReason.refreshFailed,
    );
    expect(result.failure?.message, contains('refresh'));
    final SessionTokens? stored = await tokenRepository.read();
    expect(stored?.accessToken, '   ');
    expect(stored?.refreshToken, 'old_refresh');
  });

  test('buildHeaders returns failure when refresh returns invalid payload',
      () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
      ),
    );
    authApi.refreshResult = null;

    final StreamAuthorizationHeaderResult result = await provider.buildHeaders(
      refreshSession: true,
      reason: 'test-invalid-payload',
    );

    expect(authApi.refreshCalls, 1);
    expect(result.isFailure, isTrue);
    expect(result.headers, isEmpty);
    expect(
      result.failure?.reason,
      StreamAuthorizationFailureReason.invalidRefreshPayload,
    );
    expect(result.failure?.message, contains('invalid'));
  });

  test('buildHeaders returns failure when refresh is unauthorized', () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
      ),
    );
    authApi.throwOnRefresh = DioException(
      requestOptions: RequestOptions(path: '/account/refresh-token'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/account/refresh-token'),
        statusCode: 401,
      ),
    );

    final StreamAuthorizationHeaderResult result = await provider.buildHeaders(
      refreshSession: true,
      reason: 'test-unauthorized',
    );

    expect(authApi.refreshCalls, 1);
    expect(result.isFailure, isTrue);
    expect(result.headers, isEmpty);
    expect(
      result.failure?.reason,
      StreamAuthorizationFailureReason.unauthorized,
    );
    expect(result.failure?.message, contains('sign in'));
  });

  test('buildHeaders returns failure when no session is available for playback',
      () async {
    final StreamAuthorizationHeaderResult result = await provider.buildHeaders(
      refreshSession: true,
      reason: 'test-empty',
    );

    expect(result.isFailure, isTrue);
    expect(result.headers, isEmpty);
    expect(
      result.failure?.reason,
      StreamAuthorizationFailureReason.missingValidSession,
    );
    expect(result.failure?.message, contains('session'));
    expect(authApi.refreshCalls, 0);
  });
}

class _InMemoryTokenRepository implements TokenRepository {
  SessionTokens? _value;

  @override
  Future<void> clearSession() async {
    _value = null;
  }

  @override
  Future<void> clearAllAuthState() async {
    _value = null;
  }

  @override
  Future<bool> hasAccessToken() async {
    final SessionTokens? value = _value;
    return value != null && value.accessToken.isNotEmpty;
  }

  @override
  Future<SessionTokens?> read() async => _value;

  @override
  Future<void> save(SessionTokens tokens) async {
    _value = tokens;
  }
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi()
      : super(
          config: const AppConfig(
            apiBaseUrl: 'https://example.local',
            connectTimeoutMs: 500,
            receiveTimeoutMs: 500,
            sendTimeoutMs: 500,
          ),
        );

  int refreshCalls = 0;
  SessionTokens? refreshResult;
  Object? throwOnRefresh;
  String? lastRefreshUserName;
  String? lastRefreshToken;
  String? lastAccessToken;

  @override
  Future<SessionTokens?> refreshToken({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) async {
    refreshCalls += 1;
    lastRefreshUserName = userName;
    lastRefreshToken = refreshToken;
    lastAccessToken = accessToken;
    final Object? error = throwOnRefresh;
    if (error != null) {
      throw error;
    }
    return refreshResult;
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
