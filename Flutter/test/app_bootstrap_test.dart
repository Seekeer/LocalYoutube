import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/app_bootstrap.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/auth/session_tokens.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/core/network/auth_api.dart';
import 'package:localtube_flutter/core/storage/secure_storage_service.dart';
import 'package:localtube_flutter/features/downloads/domain/download_service.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final pendingHistory in <bool>[false, true]) {
    test(
      pendingHistory
          ? 'bootstrap does not send pending history before the first frame'
          : 'bootstrap restores saved session without waiting for HTTP',
      () async {
        final database = AppDatabase(executor: NativeDatabase.memory());
        await database.initialize();
        if (pendingHistory) {
          await SyncOutboxDao(database).enqueue(
            operationType: 'playback_position_set',
            payloadJson:
                '{"videoId":1,"positionSeconds":12,"updatedDate":"2026-10-14T00:00:00Z"}',
          );
        }
        final api = _StalledAuthApi();
        final adapter = _StalledAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.local/api'))
          ..httpClientAdapter = adapter;
        final bootstrap = _bootstrap(
          database: database,
          api: api,
          dio: dio,
          storage: _Storage(<String, String>{
            'user_name': 'viewer',
            'access_token': 'access',
            'refresh_token': 'refresh',
          }),
        );
        bool finished = false;
        ProviderContainer? container;
        bootstrap.then((_) => finished = true);
        try {
          await Future.any<void>(<Future<void>>[
            bootstrap.then((_) {}),
            if (pendingHistory) adapter.started.future,
          ]).timeout(const Duration(seconds: 2));
          expect(finished, isTrue,
              reason: 'The native splash must not wait for outbox HTTP.');
          final result = await bootstrap;
          container = ProviderContainer(overrides: result.overrides);
          expect(container.read(authNotifierProvider).accessMode,
              AppAccessMode.offlineFallback);
          expect(api.refreshCalls, 0);
          expect(adapter.calls, 0);
        } finally {
          api.response.complete(null);
          adapter.response.complete(ResponseBody.fromString('{}', 200));
          await Future<void>.delayed(Duration.zero);
          await _dispose(await bootstrap, database, container: container);
        }
      },
    );
  }

  test('saved credentials alone show login without sending a request',
      () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final api = _StalledAuthApi();
    final dio = Dio();
    final result = await _bootstrap(
      database: database,
      api: api,
      dio: dio,
      storage: _Storage(<String, String>{
        'saved_login': 'viewer',
        'saved_password': 'password',
      }),
    );
    final container = ProviderContainer(overrides: result.overrides);
    try {
      expect(container.read(authNotifierProvider).accessMode,
          AppAccessMode.signedOut);
      expect(api.refreshCalls, 0);
    } finally {
      await _dispose(result, database, container: container);
    }
  });
}

Future<BootstrapResult> _bootstrap({
  required AppDatabase database,
  required AuthApi api,
  required Dio dio,
  required SecureStorageService storage,
}) {
  final downloads = _Downloads();
  when(downloads.initialize).thenAnswer((_) async {});
  return AppBootstrap.initialize(
    environmentOverride: AppEnvironment.prod,
    logServiceOverride: _Log(),
    secureStorageOverride: storage,
    appDatabaseOverride: database,
    authApiOverride: api,
    downloadServiceOverride: downloads,
    dioOverride: dio,
  );
}

Future<void> _dispose(BootstrapResult result, AppDatabase database,
    {ProviderContainer? container}) async {
  result.router.dispose();
  final providers = container ?? ProviderContainer(overrides: result.overrides);
  await providers.read(appSyncCoordinatorProvider).dispose();
  await providers.read(castRegistrationServiceProvider).dispose();
  await providers.read(syncHubServiceProvider).dispose();
  providers.read(dioProvider).close(force: true);
  providers.dispose();
  await database.close();
}

class _Downloads extends Mock implements DownloadService {}

class _Storage extends SecureStorageService {
  _Storage(this.values);
  final Map<String, String> values;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _StalledAuthApi extends AuthApi {
  _StalledAuthApi()
      : super(
          config: const AppConfig(
            apiBaseUrl: 'https://example.local',
            connectTimeoutMs: 15000,
            receiveTimeoutMs: 30000,
            sendTimeoutMs: 15000,
          ),
        );
  final response = Completer<SessionTokens?>();
  int refreshCalls = 0;
  @override
  Future<SessionTokens?> refreshToken({
    required String userName,
    required String refreshToken,
    required String accessToken,
  }) {
    refreshCalls++;
    return response.future;
  }
}

class _StalledAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final response = Completer<ResponseBody>();
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    calls++;
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

class _Log extends LogService {
  @override
  Future<void> initialize() async {}
  @override
  void info(String message) {}
  @override
  void error(String message, Object error, StackTrace stackTrace) {}
}
