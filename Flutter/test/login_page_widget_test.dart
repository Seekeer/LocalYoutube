import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
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
import 'package:localtube_flutter/core/storage/secure_storage_service.dart';
import 'package:localtube_flutter/features/auth/data/auth_attempt_result.dart';
import 'package:localtube_flutter/features/auth/data/auth_local_session_repository.dart';
import 'package:localtube_flutter/features/auth/data/offline_availability_probe.dart';
import 'package:localtube_flutter/features/auth/data/auth_remote_data_source.dart';
import 'package:localtube_flutter/features/auth/data/auth_repository.dart';
import 'package:localtube_flutter/features/auth/domain/usecases/login_use_case.dart';
import 'package:localtube_flutter/features/auth/domain/usecases/try_auto_login_use_case.dart';
import 'package:localtube_flutter/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('shows validation errors for empty login form', (
    WidgetTester tester,
  ) async {
    final _ConfigurableAuthRepository authRepository =
        _ConfigurableAuthRepository()
          ..nextAutoLoginResult = const AuthAttemptResult.failure(
            AuthFailure('No session'),
          );

    await tester.pumpWidget(
      _testApp(
        authRepository: authRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Login is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows server failure message when login fails', (
    WidgetTester tester,
  ) async {
    final _ConfigurableAuthRepository authRepository =
        _ConfigurableAuthRepository()
          ..nextAutoLoginResult = const AuthAttemptResult.failure(
            AuthFailure('No session'),
          )
          ..nextLoginResult = const AuthAttemptResult.failure(
            AuthFailure('Invalid credentials'),
          );

    await tester.pumpWidget(
      _testApp(
        authRepository: authRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Login'), 'john');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'bad_password',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('does not try silent login with saved credentials on app start', (
    WidgetTester tester,
  ) async {
    final _ConfigurableAuthRepository authRepository =
        _ConfigurableAuthRepository()
          ..nextAutoLoginResult = const AuthAttemptResult.failure(
            AuthFailure('No session'),
          )
          ..nextLoginResult = const AuthAttemptResult.failure(
            AuthFailure('Invalid credentials'),
          );

    await tester.pumpWidget(
      _testApp(
        authRepository: authRepository,
        savedLogin: 'saved_user',
        savedPassword: 'saved_pass',
      ),
    );
    await tester.pumpAndSettle();

    expect(authRepository.lastLoginUserName, isNull);
    expect(authRepository.lastLoginPassword, isNull);
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });
}

Widget _testApp({
  required _ConfigurableAuthRepository authRepository,
  String? savedLogin,
  String? savedPassword,
}) {
  final _InMemorySecureStorageService storage = _InMemorySecureStorageService(
    seed: <String, String>{
      if (savedLogin != null) 'saved_login': savedLogin,
      if (savedPassword != null) 'saved_password': savedPassword,
    },
  );
  return ProviderScope(
    overrides: <Override>[
      loginUseCaseProvider.overrideWithValue(LoginUseCase(authRepository)),
      tryAutoLoginUseCaseProvider
          .overrideWithValue(TryAutoLoginUseCase(authRepository)),
      secureStorageServiceProvider.overrideWithValue(storage),
    ],
    child: MaterialApp(
      home: LoginPage(
        authNotifier: AuthNotifier(),
      ),
    ),
  );
}

class _ConfigurableAuthRepository extends AuthRepository {
  _ConfigurableAuthRepository()
      : super(
          remoteDataSource: _FakeAuthRemoteDataSource(),
          localSessionRepository: _InMemoryAuthLocalSessionRepository(),
          offlineAvailabilityProbe: _NeverOfflineAvailabilityProbe(),
          tokenRepository: _InMemoryTokenRepository(),
          authNotifier: AuthNotifier(),
          logService: _NoopLogService(),
        );

  AuthAttemptResult nextLoginResult = const AuthAttemptResult.successOnline();
  AuthAttemptResult nextAutoLoginResult =
      const AuthAttemptResult.failure(AuthFailure('No session'));
  String? lastLoginUserName;
  String? lastLoginPassword;

  @override
  Future<AuthAttemptResult> login({
    required String userName,
    required String password,
  }) async {
    lastLoginUserName = userName;
    lastLoginPassword = password;
    return nextLoginResult;
  }

  @override
  Future<AuthAttemptResult> tryAutoLogin() async {
    return nextAutoLoginResult;
  }
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

class _InMemorySecureStorageService extends SecureStorageService {
  _InMemorySecureStorageService({Map<String, String>? seed})
      : _store = <String, String>{...?(seed)};

  final Map<String, String> _store;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
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
}

class _NeverOfflineAvailabilityProbe extends OfflineAvailabilityProbe {
  _NeverOfflineAvailabilityProbe()
      : super(
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

  @override
  Future<bool> canEnterOfflineFallback() async => false;
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
