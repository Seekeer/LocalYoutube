import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/app/sync/app_sync_coordinator.dart';
import 'package:localtube_flutter/app/sync/app_sync_lifecycle_listener.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/bookmarks_dao.dart';
import 'package:localtube_flutter/core/db/daos/downloads_dao.dart';
import 'package:localtube_flutter/core/db/daos/playback_positions_dao.dart';
import 'package:localtube_flutter/core/db/daos/session_meta_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/core/db/daos/videos_cache_dao.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/auth_api.dart';
import 'package:localtube_flutter/core/network/network_status.dart';
import 'package:localtube_flutter/features/auth/data/auth_local_session_repository.dart';
import 'package:localtube_flutter/features/auth/data/auth_remote_data_source.dart';
import 'package:localtube_flutter/features/auth/data/auth_repository.dart';
import 'package:localtube_flutter/features/auth/data/offline_availability_probe.dart';
import 'package:localtube_flutter/features/bookmarks/data/bookmarks_remote_data_source.dart';
import 'package:localtube_flutter/features/bookmarks/data/bookmarks_repository.dart';
import 'package:localtube_flutter/features/bookmarks/data/local_bookmarks_repository.dart';
import 'package:localtube_flutter/features/player/data/local_playback_repository.dart';
import 'package:localtube_flutter/features/player/data/playback_position_remote_data_source.dart';
import 'package:localtube_flutter/features/player/data/playback_sync_repository.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

void main() {
  testWidgets('listener enters offline fallback when network drops', (
    WidgetTester tester,
  ) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      authNotifier: authNotifier,
      enterOfflineFallbackResult: true,
    );
    final _FakeAppSyncCoordinator appSyncCoordinator =
        _FakeAppSyncCoordinator();
    final StreamController<NetworkStatus> networkController =
        StreamController<NetworkStatus>();
    addTearDown(networkController.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authNotifierProvider.overrideWith((Ref ref) => authNotifier),
          authRepositoryProvider.overrideWithValue(authRepository),
          appSyncCoordinatorProvider.overrideWithValue(appSyncCoordinator),
          networkStatusProvider.overrideWith((Ref ref) {
            return networkController.stream;
          }),
        ],
        child: const MaterialApp(
          home: AppSyncLifecycleListener(
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    networkController.add(NetworkStatus.online);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    networkController.add(NetworkStatus.offline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(authRepository.enterOfflineFallbackCalls, 1);
    expect(authNotifier.isOfflineFallback, isTrue);
    expect(
      authNotifier.consumePendingAccessNotice(),
      'Internet unavailable. Switched to offline mode using local data.',
    );
  });

  testWidgets('listener recovers online session when network returns', (
    WidgetTester tester,
  ) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.offlineFallback,
    );
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      authNotifier: authNotifier,
      recoverOnlineSessionResult: true,
      onRecoverOnlineSession: () {
        authNotifier.enterOnlineAuthenticated();
      },
    );
    final _FakeAppSyncCoordinator appSyncCoordinator =
        _FakeAppSyncCoordinator();
    final StreamController<NetworkStatus> networkController =
        StreamController<NetworkStatus>();
    addTearDown(networkController.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authNotifierProvider.overrideWith((Ref ref) => authNotifier),
          authRepositoryProvider.overrideWithValue(authRepository),
          appSyncCoordinatorProvider.overrideWithValue(appSyncCoordinator),
          networkStatusProvider.overrideWith((Ref ref) {
            return networkController.stream;
          }),
        ],
        child: const MaterialApp(
          home: AppSyncLifecycleListener(
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    networkController.add(NetworkStatus.offline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    networkController.add(NetworkStatus.online);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(authRepository.recoverOnlineSessionCalls, 1);
    expect(authNotifier.isOnlineAuthenticated, isTrue);
    expect(appSyncCoordinator.syncReasons, contains('network-online'));
  });

  testWidgets('local content renders before stalled startup recovery and sync',
      (WidgetTester tester) async {
    final authNotifier =
        AuthNotifier(initialMode: AppAccessMode.offlineFallback);
    final recovery = Completer<bool>();
    final sync = Completer<void>();
    final authRepository = _FakeAuthRepository(
      authNotifier: authNotifier,
      recoveryFuture: recovery.future,
    );
    final coordinator = _FakeAppSyncCoordinator()
      ..initializeFuture = sync.future;
    final network = StreamController<NetworkStatus>();
    addTearDown(network.close);
    bool renderedBeforeSync = false;

    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        authNotifierProvider.overrideWith((Ref ref) => authNotifier),
        authRepositoryProvider.overrideWithValue(authRepository),
        appSyncCoordinatorProvider.overrideWithValue(coordinator),
        networkStatusProvider.overrideWith((Ref ref) => network.stream),
      ],
      child: MaterialApp(
        home: AppSyncLifecycleListener(
          child: Builder(builder: (_) {
            renderedBeforeSync = coordinator.initializeCalls == 0;
            return const Text('Local content');
          }),
        ),
      ),
    ));
    network.add(NetworkStatus.online);
    await tester.pump();

    expect(renderedBeforeSync, isTrue);
    expect(find.text('Local content'), findsOneWidget);
    expect(coordinator.initializeCalls, 1);
    expect(authRepository.recoverOnlineSessionCalls, 1);
    expect(authNotifier.isOfflineFallback, isTrue);

    // A resume during slow authentication must share the same refresh.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(authRepository.recoverOnlineSessionCalls, 1);

    recovery.complete(false);
    sync.complete();
    await tester.pump();
    expect(authNotifier.isOfflineFallback, isTrue);
    expect(coordinator.syncReasons, contains('network-online'));
  });

  testWidgets('rejected startup session stays signed out',
      (WidgetTester tester) async {
    final authNotifier =
        AuthNotifier(initialMode: AppAccessMode.offlineFallback);
    final authRepository = _FakeAuthRepository(
      authNotifier: authNotifier,
      onRecoverOnlineSession: authNotifier.enterSignedOut,
    );
    final coordinator = _FakeAppSyncCoordinator();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        authNotifierProvider.overrideWith((Ref ref) => authNotifier),
        authRepositoryProvider.overrideWithValue(authRepository),
        appSyncCoordinatorProvider.overrideWithValue(coordinator),
        networkStatusProvider.overrideWith(
          (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.online),
        ),
      ],
      child: const MaterialApp(
        home: AppSyncLifecycleListener(child: Text('Local content')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(authRepository.recoverOnlineSessionCalls, 1);
    expect(authNotifier.accessMode, AppAccessMode.signedOut);
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required this.authNotifier,
    this.enterOfflineFallbackResult = false,
    this.recoverOnlineSessionResult = false,
    this.onRecoverOnlineSession,
    this.recoveryFuture,
  }) : super(
          remoteDataSource: _FakeAuthRemoteDataSource(),
          localSessionRepository: _FakeAuthLocalSessionRepository(),
          offlineAvailabilityProbe: _NeverOfflineAvailabilityProbe(),
          tokenRepository: _InMemoryTokenRepository(),
          authNotifier: authNotifier,
          logService: _NoopLogService(),
        );

  final AuthNotifier authNotifier;
  final bool enterOfflineFallbackResult;
  final bool recoverOnlineSessionResult;
  final VoidCallback? onRecoverOnlineSession;
  final Future<bool>? recoveryFuture;

  int enterOfflineFallbackCalls = 0;
  int recoverOnlineSessionCalls = 0;

  @override
  Future<bool> enterOfflineFallbackIfAvailable({String? notice}) async {
    enterOfflineFallbackCalls += 1;
    if (enterOfflineFallbackResult) {
      authNotifier.enterOfflineFallback(notice: notice);
    }
    return enterOfflineFallbackResult;
  }

  @override
  Future<bool> recoverOnlineSession() async {
    recoverOnlineSessionCalls += 1;
    onRecoverOnlineSession?.call();
    if (recoveryFuture != null) {
      return recoveryFuture!;
    }
    return recoverOnlineSessionResult;
  }
}

class _FakeAppSyncCoordinator extends AppSyncCoordinator {
  _FakeAppSyncCoordinator()
      : super(
          bookmarksRepository: _FakeBookmarksRepository(),
          playbackSyncRepository: _FakePlaybackSyncRepository(),
          logService: _NoopLogService(),
        );

  final List<String> syncReasons = <String>[];
  int initializeCalls = 0;
  Future<void>? initializeFuture;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    await initializeFuture;
  }

  @override
  Future<void> triggerSync({required String reason}) async {
    syncReasons.add(reason);
  }
}

class _NoopLogService extends LogService {
  @override
  void debug(String message) {}

  @override
  void error(String message, Object error, StackTrace stackTrace) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}
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

class _FakeAuthLocalSessionRepository extends AuthLocalSessionRepository {
  _FakeAuthLocalSessionRepository()
      : super(
          SessionMetaDao(
            AppDatabase(executor: NativeDatabase.memory()),
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

class _FakeBookmarksRepository extends BookmarksRepository {
  _FakeBookmarksRepository()
      : super(
          remoteDataSource: BookmarksRemoteDataSource(_fakeDio()),
          localBookmarksRepository: LocalBookmarksRepository(
            BookmarksDao(AppDatabase(executor: NativeDatabase.memory())),
          ),
          localSyncOutboxRepository: LocalSyncOutboxRepository(
            SyncOutboxDao(AppDatabase(executor: NativeDatabase.memory())),
          ),
          logService: _NoopLogService(),
        );

  @override
  Future<void> processOutbox() async {}
}

class _FakePlaybackSyncRepository extends PlaybackSyncRepository {
  _FakePlaybackSyncRepository()
      : super(
          localPlaybackRepository: LocalPlaybackRepository(
            PlaybackPositionsDao(
                AppDatabase(executor: NativeDatabase.memory())),
          ),
          remoteDataSource: PlaybackPositionRemoteDataSource(_fakeDio()),
          localSyncOutboxRepository: LocalSyncOutboxRepository(
            SyncOutboxDao(AppDatabase(executor: NativeDatabase.memory())),
          ),
          logService: _NoopLogService(),
        );

  @override
  Future<void> processOutbox() async {}

  @override
  Future<void> reconcileRecent({int limit = 20}) async {}
}

Dio _fakeDio() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://example.local',
    ),
  );
}
