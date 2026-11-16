import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:localtube_flutter/features/notes/data/notes_repository.dart';
import 'package:localtube_flutter/features/notes/domain/notes_models.dart';
import 'package:localtube_flutter/features/settings/presentation/settings_page.dart';
import 'package:localtube_flutter/app/router/app_routes.dart';
import 'package:localtube_flutter/features/app_updates/app_updates.dart';
import 'package:go_router/go_router.dart';

import 'features/app_updates/app_updates_widget_test.dart' show metadata;

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

  Widget buildOnlineStartPage({
    List<Override> extraOverrides = const <Override>[],
    Widget app = const MaterialApp(home: StartPage()),
  }) {
    return ProviderScope(
      overrides: <Override>[
        ...extraOverrides,
        authNotifierProvider.overrideWith(
          (Ref ref) =>
              AuthNotifier(initialMode: AppAccessMode.onlineAuthenticated),
        ),
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
        networkStatusProvider.overrideWith(
          (Ref ref) => Stream<NetworkStatus>.value(NetworkStatus.online),
        ),
      ],
      child: app,
    );
  }

  Widget buildWithSettings(int publishedVersionCode) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: <RouteBase>[
        GoRoute(path: AppRoutes.home, builder: (_, __) => const StartPage()),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const SettingsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    return buildOnlineStartPage(
      extraOverrides: <Override>[
        installedAppProvider.overrideWithValue(() async =>
            const InstalledApp('org.localtube.app.debug', 10, '1.0.10')),
        updateSourceProvider.overrideWithValue((String channel) async =>
            metadata(channel, 'org.localtube.app.debug',
                publishedVersionCode)),
      ],
      app: AppUpdateLifecycleListener(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('a newer version badges Settings, where the update card lives', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWithSettings(11));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('app-updates-card')), findsNothing);
    expect(find.text('Доступна новая версия'), findsNothing);
    final Finder settings = find.byKey(const Key('settings-button'));
    expect(
      tester
          .widget<Badge>(
              find.descendant(of: settings, matching: find.byType(Badge)))
          .isLabelVisible,
      isTrue,
    );
    expect(find.byTooltip('Настройки · доступно обновление'), findsOneWidget);

    await tester.tap(settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.byKey(const Key('app-updates-card')), findsOneWidget);
    expect(find.text('Preview · Установлена: 1.0.10 (10)'), findsOneWidget);
    expect(find.text('Доступна: 1.0.11 (11)'), findsOneWidget);
    expect(find.text('Доступна новая версия'), findsOneWidget);
    expect(find.text('Проверить обновления'), findsOneWidget);
  });

  testWidgets('without a newer version Settings carries no badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWithSettings(10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final Finder settings = find.byKey(const Key('settings-button'));
    expect(
      tester
          .widget<Badge>(
              find.descendant(of: settings, matching: find.byType(Badge)))
          .isLabelVisible,
      isFalse,
    );
    expect(find.byTooltip('Настройки'), findsOneWidget);
    expect(find.byKey(const Key('app-updates-card')), findsNothing);
  });

  testWidgets(
      'top row shows the version double button instead of the menu title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWithSettings(10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Главное меню'), findsNothing);
    final Finder button = find.byKey(const Key('app-version-update-button'));
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.text('1.0.10')),
        findsOneWidget);
    expect(find.descendant(of: button, matching: find.text('Preview')),
        findsOneWidget);
    expect(find.byTooltip('Версия 1.0.10 (10) · Preview'), findsOneWidget);
    expect(find.byTooltip('Проверить обновления'), findsOneWidget);
  });

  testWidgets('the check reports an up-to-date build', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWithSettings(10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('app-update-check-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Новых обновлений нет'), findsOneWidget);
    expect(find.widgetWithText(SnackBarAction, 'Настройки'), findsNothing);
  });

  testWidgets('a found update offers Settings from the check result', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildWithSettings(11));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('app-update-check-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Доступна версия 1.0.11'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(SnackBarAction, 'Настройки'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('app-updates-card')), findsOneWidget);
    expect(find.text('Доступна: 1.0.11 (11)'), findsOneWidget);
  });

  testWidgets('the check button spins and is disabled while checking', (
    WidgetTester tester,
  ) async {
    final Completer<Map<String, dynamic>?> pending =
        Completer<Map<String, dynamic>?>();
    int calls = 0;
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildOnlineStartPage(
      extraOverrides: <Override>[
        installedAppProvider.overrideWithValue(() async =>
            const InstalledApp('org.localtube.app.stable', 10, '1.0.10')),
        updateSourceProvider.overrideWithValue((String channel) {
          calls++;
          return pending.future;
        }),
      ],
      app: const AppUpdateLifecycleListener(
        child: MaterialApp(home: StartPage()),
      ),
    ));
    await tester.pump();

    // The version is known before the server answers; Stable has no mark.
    final Finder button = find.byKey(const Key('app-version-update-button'));
    expect(find.descendant(of: button, matching: find.text('1.0.10')),
        findsOneWidget);
    expect(find.descendant(of: button, matching: find.text('Preview')),
        findsNothing);
    Animation<double> turns() => tester
        .widget<RotationTransition>(find.descendant(
            of: button, matching: find.byType(RotationTransition)))
        .turns;
    expect(find.byTooltip('Проверка обновлений…'), findsOneWidget);
    expect(turns().status, AnimationStatus.forward);
    final double before = turns().value;
    await tester.pump(const Duration(milliseconds: 200));
    expect(turns().value, isNot(before));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Проверка обновлений…'))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    await tester.tap(find.byKey(const Key('app-update-check-button')));
    await tester.pump();
    expect(calls, 1);

    pending.complete(metadata('stable', 'org.localtube.app.stable', 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Проверить обновления'), findsOneWidget);
    expect(turns().isAnimating, isFalse);
    expect(turns().value, 0);
    final SemanticsNode check =
        tester.getSemantics(find.bySemanticsLabel('Проверить обновления'));
    expect(check.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Проверить обновления'));
    await tester.pump();
    expect(calls, 2);
    semantics.dispose();
  });

  testWidgets('a narrow phone keeps the check full size and drops the rest', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildWithSettings(10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    final Finder button = find.byKey(const Key('app-version-update-button'));
    expect(button, findsOneWidget);
    expect(find.descendant(of: button, matching: find.text('Preview')),
        findsNothing);
    expect(find.descendant(of: button, matching: find.text('1.0.10')),
        findsNothing);
    expect(find.byKey(const Key('app-update-check-button')).hitTestable(),
        findsOneWidget);
    final Size check =
        tester.getSize(find.byKey(const Key('app-update-check-button')));
    expect(check.width, greaterThanOrEqualTo(40));
    expect(check.height, greaterThanOrEqualTo(38));
    // The rest of the top row is still there.
    expect(find.byKey(const Key('settings-button')), findsOneWidget);
    expect(find.byKey(const Key('autonomous-mode-switch')), findsOneWidget);
  });

  // Widths where the bar's own actions still fit with the test font; each
  // leaves the title a different slot: none, the check alone, or more.
  for (final (double width, double scale) layout in <(double, double)>[
    (360, 1.0),
    (380, 1.0),
    (412, 1.3),
    (480, 1.5),
    (600, 2.0),
  ]) {
    testWidgets(
        'enlarged text on ${layout.$1}px never clips the check '
        '(x${layout.$2})', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(layout.$1, 700);
      tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildWithSettings(10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Главное меню'), findsNothing);
      final Finder check = find.byKey(const Key('app-update-check-button'));
      if (check.evaluate().isEmpty) {
        // No room even for the check: Settings still offers it.
        expect(
            find.byKey(const Key('app-version-update-button')), findsNothing);
        return;
      }
      expect(check.hitTestable(), findsOneWidget);
      final Rect rect = tester.getRect(check);
      expect(rect.width, greaterThanOrEqualTo(40));
      expect(rect.right, lessThanOrEqualTo(layout.$1));
      await tester.tap(check);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Новых обновлений нет'), findsOneWidget);
    });
  }

  for (final bool bold in <bool>[false, true]) {
    testWidgets('a shown version is never cut short (bold text: $bold)', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(boldText: bold);
      addTearDown(tester.view.reset);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      tester.view.physicalSize = const Size(380, 700);
      await tester.pumpWidget(buildWithSettings(10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      int shown = 0;
      // Steps through the slot sizes around both thresholds.
      for (double width = 380; width <= 560; width += 2) {
        tester.view.physicalSize = Size(width, 700);
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final String text in <String>['1.0.10', 'Preview']) {
          final Finder found = find.descendant(
              of: find.byKey(const Key('app-version-update-button')),
              matching: find.text(text));
          if (found.evaluate().isEmpty) continue;
          shown++;
          expect(
            tester.renderObject<RenderParagraph>(found).didExceedMaxLines,
            isFalse,
            reason: '$text at $width',
          );
        }
      }
      expect(shown, greaterThan(0));
    });
  }

  testWidgets('a build without a known version shows no double button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildOnlineStartPage(
      extraOverrides: <Override>[
        installedAppProvider.overrideWithValue(() async => null),
      ],
      app: const AppUpdateLifecycleListener(
        child: MaterialApp(home: StartPage()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('app-version-update-button')), findsNothing);
    expect(find.text('Главное меню'), findsNothing);
  });

  testWidgets('Windows main menu opens the Films screen entry', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(buildOnlineStartPage());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final ElevatedButton filmsButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('start-films-button')),
      );
      expect(filmsButton.onPressed, isNotNull);
      expect(find.text('Фильмы'), findsOneWidget);

      await tester.tap(find.byKey(const Key('autonomous-mode-switch')));
      await tester.pump();
      expect(find.byKey(const Key('start-films-button')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Android main menu has no Films entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildOnlineStartPage());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('start-films-button')), findsNothing);
  });

  testWidgets('notes are a button at the bottom of the menu, with their count',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildOnlineStartPage(extraOverrides: <Override>[
      notesShelfProvider.overrideWith(
        (Ref ref) async => const NotesShelfData(
          items: <NotesShelfItem>[NotesShelfItem(videoId: 9, title: 'Лекция')],
          count: 140,
        ),
      ),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Лекция'), findsNothing);
    final Finder notes = find.byKey(const Key('start-notes-button'));
    expect(find.descendant(of: notes, matching: find.text('Заметки · 140')),
        findsOneWidget);
    final List<ElevatedButton> menu =
        tester.widgetList<ElevatedButton>(find.byType(ElevatedButton)).toList();
    expect(menu.last.key, const Key('start-notes-button'));
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
