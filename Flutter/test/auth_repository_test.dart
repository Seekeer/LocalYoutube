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
      'login enters offline fallback on network failure with local eligibility',
      () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: true,
    );
    remoteDataSource.loginError = const NetworkFailure('Network error');

    final AuthAttemptResult result = await repository.login(
      userName: 'user',
      password: 'secret',
    );

    expect(result.shouldEnterOffline, isTrue);
    expect(authNotifier.isOfflineFallback, isTrue);
    expect(
      authNotifier.consumePendingAccessNotice(),
      'Network unavailable. Entered offline mode with local data.',
    );
  });

  test('login stays signed out on invalid credentials', () async {
    final AuthRepository repository = buildRepository(
      canEnterOfflineFallback: true,
    );
    remoteDataSource.loginResult = null;

    final AuthAttemptResult result = await repository.login(
      userName: 'user',
      password: 'bad-secret',
    );

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<AuthFailure>());
    expect(authNotifier.accessMode, AppAccessMode.signedOut);
  });

  test('auto login enters offline fallback on refresh network failure',
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
    remoteDataSource.refreshError = const NetworkFailure('Network error');

    final AuthAttemptResult result = await repository.tryAutoLogin();

    expect(result.shouldEnterOffline, isTrue);
    expect(authNotifier.isOfflineFallback, isTrue);
  });

  test(
      'refresh network failure preserves existing session tokens and recoverable state',
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
    remoteDataSource.refreshError = const NetworkFailure('Network error');

    final AuthAttemptResult result = await repository.refreshSession(
      allowOfflineFallback: true,
    );

    expect(result.shouldEnterOffline, isTrue);
    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
    expect(authNotifier.accessMode, isNot(AppAccessMode.signedOut));
  });

  test(
      'default refresh path preserves session on transient failure when offline fallback is unavailable',
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
    remoteDataSource.refreshError = const NetworkFailure('Network error');

    final AuthAttemptResult result = await repository.refreshSession();

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<NetworkFailure>());
    expect(await tokenRepository.read(), isNotNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
    expect(authNotifier.accessMode, isNot(AppAccessMode.signedOut));
  });

  test(
      'invalid refresh payload preserves session tokens while preserving saved credentials',
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
  });

  test('authoritative refresh rejection clears session but preserves saved credentials',
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
    remoteDataSource.refreshError = const AuthFailure('Unauthorized');

    final AuthAttemptResult result = await repository.refreshSession(
      allowOfflineFallback: true,
    );

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<AuthFailure>());
    expect(await tokenRepository.read(), isNull);
    expect(tokenRepository.savedCredentialsStillExist, isTrue);
    expect(authNotifier.accessMode, AppAccessMode.signedOut);
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

    expect(result.shouldEnterOffline, isTrue);
    expect(authNotifier.isOfflineFallback, isTrue);
    expect(await tokenRepository.read(), isNotNull);
  });

  test(
      'auto login enters offline fallback for existing local session even without local shell data',
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
    remoteDataSource.refreshError = const NetworkFailure('Network error');

    final AuthAttemptResult result = await repository.tryAutoLogin();

    expect(result.shouldEnterOffline, isTrue);
    expect(authNotifier.isOfflineFallback, isTrue);
  });
}

class _InMemoryTokenRepository implements TokenRepository {
  SessionTokens? _value;
  String? savedLogin;
  String? savedPassword;

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

  SessionTokens? loginResult;
  SessionTokens? refreshResult;
  Object? loginError;
  Object? refreshError;

  @override
  Future<SessionTokens?> login({
    required String userName,
    required String password,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }
    return loginResult;
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
