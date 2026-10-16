import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/bookmarks_dao.dart';
import 'package:localtube_flutter/core/db/daos/downloads_dao.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/session_meta_dao.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
import 'package:localtube_flutter/core/errors/failure.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/auth_api.dart';
import 'package:localtube_flutter/features/auth/data/auth_attempt_result.dart';
import 'package:localtube_flutter/features/auth/data/auth_local_session_repository.dart';
import 'package:localtube_flutter/features/auth/data/auth_remote_data_source.dart';
import 'package:localtube_flutter/features/auth/data/auth_repository.dart';
import 'package:localtube_flutter/features/auth/data/offline_availability_probe.dart';

void main() {
  late _InMemoryTokenRepository tokenRepository;
  late _FakeAuthRemoteDataSource remoteDataSource;
  late AuthNotifier authNotifier;

  AuthRepository buildRepository({
    required bool canEnterOfflineFallback,
  }) {
    return AuthRepository(
      remoteDataSource: remoteDataSource,
      localSessionRepository: _InMemoryAuthLocalSessionRepository(),
      offlineAvailabilityProbe: _FixedOfflineAvailabilityProbe(
        isOfflineFallbackAvailable: canEnterOfflineFallback,
      ),
      tokenRepository: tokenRepository,
      authNotifier: authNotifier,
      logService: _NoopLogService(),
    );
  }

  setUp(() {
    tokenRepository = _InMemoryTokenRepository();
    remoteDataSource = _FakeAuthRemoteDataSource();
    authNotifier = AuthNotifier();
  });

  test(
      'refresh network failure preserves saved session and does not hard sign out',
      () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: true,
    );
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    tokenRepository.savedLogin = 'user';
    tokenRepository.savedPassword = 'secret';
    remoteDataSource.refreshError = DioException(
      requestOptions: RequestOptions(path: '/account/refresh-token'),
      type: DioExceptionType.connectionError,
    );

    final AuthAttemptResult result = await repository.refreshSession(
      allowOfflineFallback: true,
    );

    expect(result.isFailure, isFalse);
    expect(result.shouldEnterOffline, isTrue);
    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
    expect(authNotifier.accessMode, isNot(AppAccessMode.signedOut));
    expect(
      authNotifier.lastTransitionReasonCode,
      'refresh-network-failure-preserved',
    );
  });

  test('refresh invalid payload preserves session tokens without hard sign out',
      () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: false,
    );
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    tokenRepository.savedLogin = 'user';
    tokenRepository.savedPassword = 'secret';
    remoteDataSource.refreshResult = const SessionTokens(
      userName: 'user',
      accessToken: '',
      refreshToken: '',
    );

    final AuthAttemptResult result = await repository.refreshSession();

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<UnknownFailure>());
    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
    expect(authNotifier.accessMode, isNot(AppAccessMode.signedOut));
    expect(
      authNotifier.lastTransitionReasonCode,
      'refresh-network-failure-preserved',
    );
  });

  test('refresh null payload preserves session tokens without hard sign out',
      () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: false,
    );
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    tokenRepository.savedLogin = 'user';
    tokenRepository.savedPassword = 'secret';
    remoteDataSource.refreshResult = null;

    final AuthAttemptResult result = await repository.refreshSession();

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<UnknownFailure>());
    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
    expect(authNotifier.accessMode, isNot(AppAccessMode.signedOut));
    expect(
      authNotifier.lastTransitionReasonCode,
      'refresh-network-failure-preserved',
    );
  });

  test('auto login enters offline fallback on invalid refresh payload',
      () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: false,
    );
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    remoteDataSource.refreshResult = null;

    final AuthAttemptResult result = await repository.tryAutoLogin();

    expect(result.isFailure, isFalse);
    expect(result.shouldEnterOffline, isTrue);
    expect(await tokenRepository.read(), isNotNull);
    expect(authNotifier.accessMode, AppAccessMode.offlineFallback);
    expect(
      authNotifier.lastTransitionReasonCode,
      'refresh-network-failure-preserved',
    );
  });

  test(
      'auto login clears session on refresh auth failure without clearing saved auth state',
      () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: false,
    );
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    tokenRepository.savedLogin = 'user';
    tokenRepository.savedPassword = 'secret';
    remoteDataSource.refreshError = const AuthFailure('Unauthorized');

    final AuthAttemptResult result = await repository.tryAutoLogin();

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<AuthFailure>());
    expect(await tokenRepository.read(), isNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
    expect(authNotifier.accessMode, AppAccessMode.signedOut);
  });

  test('auto login does not clear saved credentials when token probe fails',
      () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: false,
    );
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
    );
    tokenRepository.savedLogin = 'user';
    tokenRepository.savedPassword = 'secret';
    tokenRepository.throwOnHasAccessToken = true;
    remoteDataSource.refreshError = const NetworkFailure('Network error');

    final AuthAttemptResult result = await repository.tryAutoLogin();

    expect(result.shouldEnterOffline, isTrue);
    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
  });

  test('auth notifier does not notify listeners when only reason changes', () {
    final AuthNotifier notifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );
    int notifications = 0;
    notifier.addListener(() {
      notifications++;
    });

    notifier.enterOnlineAuthenticated(
      reason: AuthTransitionReason.refreshSucceeded,
    );
    notifier.enterOnlineAuthenticated(
      reason: AuthTransitionReason.refreshSucceeded,
    );

    expect(
      notifier.lastTransitionReason,
      AuthTransitionReason.refreshSucceeded,
    );
    expect(notifications, 0);
  });
}

class _InMemoryTokenRepository implements TokenRepository {
  SessionTokens? _value;
  String? savedLogin;
  String? savedPassword;
  bool throwOnHasAccessToken = false;

  bool get savedCredentialsStillExist =>
      (savedLogin?.isNotEmpty ?? false) && (savedPassword?.isNotEmpty ?? false);

  @override
  Future<void> clearSession() async {
    _value = null;
  }

  @override
  Future<void> clearAllAuthState() async {
    _value = null;
    savedLogin = null;
    savedPassword = null;
  }

  @override
  Future<bool> hasAccessToken() async {
    if (throwOnHasAccessToken) {
      throw StateError('secure storage read failed');
    }
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

class _InMemoryAuthLocalSessionRepository extends AuthLocalSessionRepository {
  _InMemoryAuthLocalSessionRepository()
      : super(
          SessionMetaDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
        );

  @override
  Future<void> saveSessionMeta({required String userName}) async {}

  @override
  Future<void> clearSessionMeta() async {}
}

class _FixedOfflineAvailabilityProbe extends OfflineAvailabilityProbe {
  _FixedOfflineAvailabilityProbe({
    required this.isOfflineFallbackAvailable,
  }) : super(
          sessionMetaDao: SessionMetaDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          videosCacheDao: VideosCacheDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          downloadsDao: DownloadsDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          playbackPositionsDao: PlaybackPositionsDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
          bookmarksDao: BookmarksDao(
            AppDatabase(executor: NativeDatabase.memory()),
          ),
        );

  final bool isOfflineFallbackAvailable;

  @override
  Future<bool> canEnterOfflineFallback() async => isOfflineFallbackAvailable;
}

class _FakeAuthRemoteDataSource extends AuthRemoteDataSource {
  _FakeAuthRemoteDataSource()
      : super(
          AuthApi(
            config: const AppConfig(
              apiBaseUrl: 'https://example.local',
              connectTimeoutMs: 500,
              receiveTimeoutMs: 500,
              sendTimeoutMs: 500,
            ),
          ),
        );

  SessionTokens? refreshResult;
  Object? refreshError;

  @override
  Future<SessionTokens?> login({
    required String userName,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionTokens?> refresh({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) async {
    if (refreshError != null) {
      throw refreshError!;
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
