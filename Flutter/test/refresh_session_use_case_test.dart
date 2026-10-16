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
import 'package:localtube_flutter/features/auth/data/offline_availability_probe.dart';
import 'package:localtube_flutter/features/auth/data/auth_remote_data_source.dart';
import 'package:localtube_flutter/features/auth/data/auth_repository.dart';
import 'package:localtube_flutter/features/auth/domain/usecases/refresh_session_use_case.dart';

void main() {
  late _InMemoryTokenRepository tokenRepository;
  late _InMemoryAuthLocalSessionRepository localSessionRepository;
  late _NeverOfflineAvailabilityProbe offlineAvailabilityProbe;
  late _FakeAuthRemoteDataSource remoteDataSource;
  late AuthNotifier authNotifier;
  late RefreshSessionUseCase useCase;

  setUp(() {
    tokenRepository = _InMemoryTokenRepository();
    localSessionRepository = _InMemoryAuthLocalSessionRepository();
    offlineAvailabilityProbe = _NeverOfflineAvailabilityProbe();
    remoteDataSource = _FakeAuthRemoteDataSource();
    authNotifier = AuthNotifier();

    final AuthRepository authRepository = AuthRepository(
      remoteDataSource: remoteDataSource,
      localSessionRepository: localSessionRepository,
      offlineAvailabilityProbe: offlineAvailabilityProbe,
      tokenRepository: tokenRepository,
      authNotifier: authNotifier,
      logService: _NoopLogService(),
    );
    useCase = RefreshSessionUseCase(authRepository);
  });

  tearDown(() async {
    await localSessionRepository.close();
    await offlineAvailabilityProbe.close();
  });

  test('refreshes session and updates local state on success', () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
      ),
    );
    remoteDataSource.refreshResult = const SessionTokens(
      userName: 'user',
      accessToken: 'new_access',
      refreshToken: 'new_refresh',
    );

    final AuthAttemptResult result = await useCase.call();

    expect(result.isSuccessOnline, isTrue);
    final SessionTokens? stored = await tokenRepository.read();
    expect(stored, isNotNull);
    expect(stored!.accessToken, 'new_access');
    expect(stored.refreshToken, 'new_refresh');
    expect(authNotifier.isOnlineAuthenticated, isTrue);
    expect(localSessionRepository.lastSavedUserName, 'user');
    expect(remoteDataSource.lastRefreshUserName, 'user');
    expect(remoteDataSource.lastRefreshToken, 'old_refresh');
  });

  test('returns auth failure when session is absent', () async {
    final AuthAttemptResult result = await useCase.call();

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<AuthFailure>());
    expect(result.failure?.message, 'No session');
    expect(authNotifier.canEnterAppShell, isFalse);
  });

  test('preserves local session when remote refresh returns invalid payload',
      () async {
    await tokenRepository.save(
      const SessionTokens(
        userName: 'user',
        accessToken: 'old_access',
        refreshToken: 'old_refresh',
      ),
    );
    remoteDataSource.refreshResult = null;

    final AuthAttemptResult result = await useCase.call();

    expect(result.isFailure, isTrue);
    expect(result.failure, isA<UnknownFailure>());
    expect(
      result.failure?.message,
      'Session refresh response was invalid',
    );
    final SessionTokens? stored = await tokenRepository.read();
    expect(stored, isNotNull);
    expect(stored!.accessToken, 'old_access');
    expect(stored.refreshToken, 'old_refresh');
    expect(authNotifier.accessMode, isNot(AppAccessMode.signedOut));
    expect(
      authNotifier.lastTransitionReasonCode,
      'refresh-network-failure-preserved',
    );
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

class _InMemoryAuthLocalSessionRepository extends AuthLocalSessionRepository {
  _InMemoryAuthLocalSessionRepository()
      : this._(
          AppDatabase(executor: NativeDatabase.memory()),
        );

  _InMemoryAuthLocalSessionRepository._(this._database)
      : super(
          SessionMetaDao(_database),
        );

  final AppDatabase _database;

  String? lastSavedUserName;

  @override
  Future<void> saveSessionMeta({required String userName}) async {
    lastSavedUserName = userName;
  }

  @override
  Future<void> clearSessionMeta() async {
    lastSavedUserName = null;
  }

  Future<void> close() => _database.close();
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
  String? lastRefreshUserName;
  String? lastRefreshToken;
  String? lastAccessToken;

  @override
  Future<SessionTokens?> refresh({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) async {
    lastRefreshUserName = userName;
    lastRefreshToken = refreshToken;
    lastAccessToken = accessToken;
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

class _NeverOfflineAvailabilityProbe extends OfflineAvailabilityProbe {
  _NeverOfflineAvailabilityProbe()
      : this._(
          AppDatabase(executor: NativeDatabase.memory()),
          AppDatabase(executor: NativeDatabase.memory()),
          AppDatabase(executor: NativeDatabase.memory()),
          AppDatabase(executor: NativeDatabase.memory()),
          AppDatabase(executor: NativeDatabase.memory()),
        );

  _NeverOfflineAvailabilityProbe._(
    this._sessionMetaDatabase,
    this._videosCacheDatabase,
    this._downloadsDatabase,
    this._playbackPositionsDatabase,
    this._bookmarksDatabase,
  ) : super(
          sessionMetaDao: SessionMetaDao(
            _sessionMetaDatabase,
          ),
          videosCacheDao: VideosCacheDao(
            _videosCacheDatabase,
          ),
          downloadsDao: DownloadsDao(
            _downloadsDatabase,
          ),
          playbackPositionsDao: PlaybackPositionsDao(
            _playbackPositionsDatabase,
          ),
          bookmarksDao: BookmarksDao(
            _bookmarksDatabase,
          ),
        );

  final AppDatabase _sessionMetaDatabase;
  final AppDatabase _videosCacheDatabase;
  final AppDatabase _downloadsDatabase;
  final AppDatabase _playbackPositionsDatabase;
  final AppDatabase _bookmarksDatabase;

  @override
  Future<bool> canEnterOfflineFallback() async => false;

  Future<void> close() async {
    await _sessionMetaDatabase.close();
    await _videosCacheDatabase.close();
    await _downloadsDatabase.close();
    await _playbackPositionsDatabase.close();
    await _bookmarksDatabase.close();
  }
}
