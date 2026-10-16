import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/app/router/auth_notifier.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/video_metadata_dao.dart';
import 'package:localtube_flutter/core/network/network_status.dart';
import 'package:localtube_flutter/core/playback/playback_mode.dart';
import 'package:localtube_flutter/features/catalog/data/local_video_metadata_repository.dart';
import 'package:localtube_flutter/features/downloads/data/offline_history_repository.dart';
import 'package:localtube_flutter/features/home/presentation/start_page.dart';

void main() {
  testWidgets(
      'offline network hides online buttons and forces autonomous switch', (
    WidgetTester tester,
  ) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.offlineFallback,
    );
    final StreamController<NetworkStatus> networkController =
        StreamController<NetworkStatus>();
    addTearDown(networkController.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authNotifierProvider.overrideWith((Ref ref) => authNotifier),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com',
              connectTimeoutMs: 15000,
              receiveTimeoutMs: 30000,
              sendTimeoutMs: 15000,
            ),
          ),
          offlineHistoryRepositoryProvider
              .overrideWithValue(_DummyOfflineHistoryRepository()),
          networkStatusProvider.overrideWith((Ref ref) {
            return networkController.stream;
          }),
        ],
        child: const MaterialApp(
          home: StartPage(),
        ),
      ),
    );

    networkController.add(NetworkStatus.offline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
        find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'), findsNothing);
    expect(find.text('\u0421\u0435\u0440\u0438\u0438'), findsNothing);
    expect(
      find.text('\u0418\u0441\u0442\u043e\u0440\u0438\u044f'),
      findsOneWidget,
    );
    expect(
      find.text('\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c'),
      findsOneWidget,
    );
    expect(find.text('Автономно'), findsOneWidget);
    final Switch autonomousSwitch = tester.widget<Switch>(
      find.byKey(const Key('autonomous-mode-switch')),
    );
    expect(autonomousSwitch.value, isTrue);
    expect(autonomousSwitch.onChanged, isNull);
  });

  testWidgets(
    'offline fallback continue shows snackbar when nothing is playable',
    (WidgetTester tester) async {
      final AuthNotifier authNotifier = AuthNotifier(
        initialMode: AppAccessMode.offlineFallback,
      );
      final StreamController<NetworkStatus> networkController =
          StreamController<NetworkStatus>();
      addTearDown(networkController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authNotifierProvider.overrideWith((Ref ref) => authNotifier),
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'https://example.com',
                connectTimeoutMs: 15000,
                receiveTimeoutMs: 30000,
                sendTimeoutMs: 15000,
              ),
            ),
            offlineHistoryRepositoryProvider
                .overrideWithValue(_DummyOfflineHistoryRepository()),
            networkStatusProvider.overrideWith((Ref ref) {
              return networkController.stream;
            }),
          ],
          child: const MaterialApp(
            home: StartPage(),
          ),
        ),
      );

      networkController.add(NetworkStatus.offline);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text(
          '\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('No downloaded video available to continue.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'manual autonomous switch toggles between online and local menu actions',
    (WidgetTester tester) async {
      final AuthNotifier authNotifier = AuthNotifier(
        initialMode: AppAccessMode.onlineAuthenticated,
      );
      final StreamController<NetworkStatus> networkController =
          StreamController<NetworkStatus>();
      addTearDown(networkController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authNotifierProvider.overrideWith((Ref ref) => authNotifier),
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'https://example.com',
                connectTimeoutMs: 15000,
                receiveTimeoutMs: 30000,
                sendTimeoutMs: 15000,
              ),
            ),
            offlineHistoryRepositoryProvider
                .overrideWithValue(_DummyOfflineHistoryRepository()),
            networkStatusProvider.overrideWith((Ref ref) {
              return networkController.stream;
            }),
          ],
          child: const MaterialApp(home: StartPage()),
        ),
      );

      networkController.add(NetworkStatus.online);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Автономно'), findsOneWidget);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(StartPage)),
      );
      expect(container.read(manualAutonomousModeProvider), isFalse);

      Switch autonomousSwitch = tester.widget<Switch>(
        find.byKey(const Key('autonomous-mode-switch')),
      );
      expect(autonomousSwitch.value, isFalse);
      expect(autonomousSwitch.onChanged, isNotNull);
      expect(find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'),
          findsOneWidget);
      expect(find.text('\u0421\u0435\u0440\u0438\u0438'), findsOneWidget);

      await tester.tap(find.byKey(const Key('autonomous-mode-switch')));
      await tester.pump();

      expect(container.read(manualAutonomousModeProvider), isTrue);

      autonomousSwitch = tester.widget<Switch>(
        find.byKey(const Key('autonomous-mode-switch')),
      );
      expect(autonomousSwitch.value, isTrue);
      expect(find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'),
          findsNothing);
      expect(find.text('\u0421\u0435\u0440\u0438\u0438'), findsNothing);

      await tester.tap(find.text(
          '\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('No downloaded video available to continue.'),
        findsOneWidget,
      );

      ScaffoldMessenger.of(
        tester.element(find.byType(StartPage)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('autonomous-mode-switch')));
      await tester.pump();

      expect(container.read(manualAutonomousModeProvider), isFalse);

      autonomousSwitch = tester.widget<Switch>(
        find.byKey(const Key('autonomous-mode-switch')),
      );
      expect(autonomousSwitch.value, isFalse);
      expect(find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'),
          findsOneWidget);
      expect(find.text('\u0421\u0435\u0440\u0438\u0438'), findsOneWidget);
    },
  );

  testWidgets('manual autonomous choice persists with a new StartPage instance',
      (
    WidgetTester tester,
  ) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );
    final _DummyOfflineHistoryRepository offlineHistoryRepository =
        _DummyOfflineHistoryRepository();
    addTearDown(offlineHistoryRepository.close);

    Widget buildPage(String pageKey) {
      return ProviderScope(
        overrides: <Override>[
          authNotifierProvider.overrideWith((Ref ref) => authNotifier),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com',
              connectTimeoutMs: 15000,
              receiveTimeoutMs: 30000,
              sendTimeoutMs: 15000,
            ),
          ),
          offlineHistoryRepositoryProvider
              .overrideWithValue(offlineHistoryRepository),
          networkStatusProvider.overrideWith(
            (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.online),
          ),
        ],
        child: MaterialApp(
          home: StartPage(key: ValueKey<String>(pageKey)),
        ),
      );
    }

    await tester.pumpWidget(buildPage('first'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('autonomous-mode-switch')));
    await tester.pump();

    Switch autonomousSwitch = tester.widget<Switch>(
      find.byKey(const Key('autonomous-mode-switch')),
    );
    expect(autonomousSwitch.value, isTrue);

    await tester.pumpWidget(buildPage('second'));
    await tester.pumpAndSettle();

    autonomousSwitch = tester.widget<Switch>(
      find.byKey(const Key('autonomous-mode-switch')),
    );
    expect(autonomousSwitch.value, isTrue);
  });

  testWidgets('main menu reflects internet on and off state', (
    WidgetTester tester,
  ) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.onlineAuthenticated,
    );
    final StreamController<NetworkStatus> networkController =
        StreamController<NetworkStatus>();
    addTearDown(networkController.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authNotifierProvider.overrideWith((Ref ref) => authNotifier),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com',
              connectTimeoutMs: 15000,
              receiveTimeoutMs: 30000,
              sendTimeoutMs: 15000,
            ),
          ),
          offlineHistoryRepositoryProvider
              .overrideWithValue(_DummyOfflineHistoryRepository()),
          networkStatusProvider.overrideWith((Ref ref) {
            return networkController.stream;
          }),
        ],
        child: const MaterialApp(
          home: StartPage(),
        ),
      ),
    );

    networkController.add(NetworkStatus.online);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text(
        '\u0418\u043d\u0442\u0435\u0440\u043d\u0435\u0442 \u0432\u044b\u043a\u043b\u044e\u0447\u0435\u043d',
      ),
      findsNothing,
    );
    final ElevatedButton onlineFreshButton = tester.widget<ElevatedButton>(
      find.widgetWithText(
        ElevatedButton,
        '\u041d\u043e\u0432\u0438\u043d\u043a\u0438',
      ),
    );
    expect(onlineFreshButton.onPressed, isNotNull);

    networkController.add(NetworkStatus.offline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text(
        '\u0418\u043d\u0442\u0435\u0440\u043d\u0435\u0442 \u0432\u044b\u043a\u043b\u044e\u0447\u0435\u043d',
      ),
      findsOneWidget,
    );
    expect(
      find.text('\u0418\u0441\u0442\u043e\u0440\u0438\u044f'),
      findsOneWidget,
    );
    final ElevatedButton offlineHistoryButton = tester.widget<ElevatedButton>(
      find.widgetWithText(
        ElevatedButton,
        '\u0418\u0441\u0442\u043e\u0440\u0438\u044f',
      ),
    );
    expect(offlineHistoryButton.onPressed, isNotNull);
    final ElevatedButton offlineContinueButton = tester.widget<ElevatedButton>(
      find.widgetWithText(
        ElevatedButton,
        '\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c',
      ),
    );
    expect(offlineContinueButton.onPressed, isNotNull);
    expect(
        find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'), findsNothing);
  });

  testWidgets(
      'main menu switches live between online and offline network state', (
    WidgetTester tester,
  ) async {
    final AuthNotifier authNotifier = AuthNotifier(
      initialMode: AppAccessMode.offlineFallback,
    );
    final StreamController<NetworkStatus> networkController =
        StreamController<NetworkStatus>();
    addTearDown(networkController.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authNotifierProvider.overrideWith((Ref ref) => authNotifier),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'https://example.com',
              connectTimeoutMs: 15000,
              receiveTimeoutMs: 30000,
              sendTimeoutMs: 15000,
            ),
          ),
          offlineHistoryRepositoryProvider
              .overrideWithValue(_DummyOfflineHistoryRepository()),
          networkStatusProvider.overrideWith((Ref ref) {
            return networkController.stream;
          }),
        ],
        child: const MaterialApp(
          home: StartPage(),
        ),
      ),
    );

    networkController.add(NetworkStatus.online);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'),
        findsOneWidget);
    expect(find.text('\u0421\u0435\u0440\u0438\u0438'), findsOneWidget);
    expect(find.text('Offline mode'), findsNothing);
    Switch autonomousSwitch = tester.widget<Switch>(
      find.byKey(const Key('autonomous-mode-switch')),
    );
    expect(autonomousSwitch.value, isFalse);
    expect(autonomousSwitch.onChanged, isNotNull);

    networkController.add(NetworkStatus.offline);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
        find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'), findsNothing);
    expect(find.text('\u0421\u0435\u0440\u0438\u0438'), findsNothing);
    expect(
      find.text('\u0418\u0441\u0442\u043e\u0440\u0438\u044f'),
      findsOneWidget,
    );
    expect(
      find.text('\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c'),
      findsOneWidget,
    );
    expect(find.text('Offline mode'), findsNothing);
    autonomousSwitch = tester.widget<Switch>(
      find.byKey(const Key('autonomous-mode-switch')),
    );
    expect(autonomousSwitch.value, isTrue);
    expect(autonomousSwitch.onChanged, isNull);

    networkController.add(NetworkStatus.online);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('\u041d\u043e\u0432\u0438\u043d\u043a\u0438'),
        findsOneWidget);
    expect(find.text('\u0421\u0435\u0440\u0438\u0438'), findsOneWidget);
    expect(find.text('Offline mode'), findsNothing);
    autonomousSwitch = tester.widget<Switch>(
      find.byKey(const Key('autonomous-mode-switch')),
    );
    expect(autonomousSwitch.value, isFalse);
    expect(autonomousSwitch.onChanged, isNotNull);
  });
}

class _DummyOfflineHistoryRepository extends OfflineHistoryRepository {
  _DummyOfflineHistoryRepository()
      : this._create(AppDatabase(executor: NativeDatabase.memory()));

  _DummyOfflineHistoryRepository._create(AppDatabase database)
      : _database = database,
        super(
          database: database,
          localVideoMetadataRepository: LocalVideoMetadataRepository(
            VideoMetadataDao(database),
          ),
        );

  final AppDatabase _database;

  Future<void> close() => _database.close();

  @override
  Future<List<OfflineHistoryItem>> listHistory({int limit = 100}) async {
    return const <OfflineHistoryItem>[];
  }

  @override
  Future<OfflineHistoryItem?> findLatestPlayable() async => null;
}
