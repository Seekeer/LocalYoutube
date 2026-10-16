import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/features/app_updates/apk_download_service.dart';
import 'package:localtube_flutter/features/app_updates/apk_update_controller.dart';
import 'package:localtube_flutter/features/app_updates/app_updates.dart';
import 'package:localtube_flutter/features/cast/domain/cast_device_identity_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_registration_service.dart';
import 'package:localtube_flutter/features/cast/domain/cast_playback_endpoint.dart';
import 'package:localtube_flutter/features/cast/domain/cast_settings.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_controller.dart';
import 'package:localtube_flutter/features/cast/presentation/cast_receiver_controller.dart';

import '../cast/cast_doubles.dart';
import 'apk_test_boundaries.dart';
import 'app_updates_widget_test.dart' show metadata;

void main() {
  for (final channel in ['preview', 'stable']) {
    testWidgets(
        '$channel: explicit download, progress, cancel, retry, explicit installer',
        (tester) async {
      final h = await Harness.create(channel);
      await tester.pumpWidget(h.widget());
      await tester.pumpAndSettle();
      expect(h.downloads.starts, 0);
      expect(h.installer.launches, 0);
      await tester.tap(find.text('Скачать обновление'));
      await tester.pumpAndSettle();
      expect(h.downloads.starts, 1);
      expect(h.downloads.url!.host, '192.0.2.10');
      // A second request while active must not create another task.
      await h.controller.download(h.update);
      expect(h.downloads.starts, 1);
      h.downloads.emit(ApkTransferStatus.running, .42);
      await tester.pumpAndSettle();
      expect(find.text('Скачивание: 42%'), findsOneWidget);
      await tester.tap(find.text('Отменить загрузку'));
      await tester.pumpAndSettle();
      expect(h.downloads.cancels, 1);
      h.downloads.emit(ApkTransferStatus
          .complete); // stale completion cannot undo cancellation
      await tester.pumpAndSettle();
      expect(find.text('Установить'), findsNothing);
      await tester.tap(find.text('Повторить скачивание'));
      await tester.pumpAndSettle();
      h.downloads.emit(ApkTransferStatus.complete);
      await tester.pumpAndSettle();
      expect(find.text('Установить'), findsOneWidget);
      expect(h.installer.launches, 0);
      await tester.tap(find.text('Установить'));
      await tester.pumpAndSettle();
      expect(h.installer.launches, 1);
      expect(h.controller.state.phase, ApkUpdatePhase.ready);
      h.installer.fail = true;
      await tester.tap(find.text('Установить'));
      await tester.pumpAndSettle();
      expect(h.controller.state.phase, ApkUpdatePhase.ready);
      h.installer.fail = false;
      await tester.tap(find.text('Установить'));
      await tester.pumpAndSettle();
      expect(h.installer.launches, 3);
      h.installedCode = 11;
      await h.controller.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Установить'), findsNothing);
    });
  }

  testWidgets(
      'download survives menu removal and reports denied notifications and network retry',
      (tester) async {
    final h = await Harness.create('preview');
    h.downloads.notifications = false;
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скачать обновление'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Уведомления отключены'), findsOneWidget);
    await tester.pumpWidget(h.widget(menu: false));
    h.downloads.emit(ApkTransferStatus.running, .72);
    await tester.pumpAndSettle();
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    expect(find.text('Скачивание: 72%'), findsOneWidget);
    h.downloads.emit(ApkTransferStatus.failed);
    await tester.pumpAndSettle();
    expect(find.text('Повторить скачивание'), findsOneWidget);
    await tester.tap(find.text('Повторить скачивание'));
    await tester.pumpAndSettle();
    expect(h.downloads.starts, 2);
  });

  testWidgets('retry waits until platform cancellation completes',
      (tester) async {
    final h = await Harness.create('preview');
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скачать обновление'));
    await tester.pumpAndSettle();
    h.downloads.cancellation = Completer<void>();
    await tester.tap(find.text('Отменить загрузку'));
    await tester.pump();
    await h.controller.download(h.update);
    expect(h.downloads.starts, 1);
    h.downloads.cancellation!.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить скачивание'));
    await tester.pumpAndSettle();
    expect(h.downloads.starts, 2);
  });

  testWidgets('invalid completion is never ready and a clean retry succeeds',
      (tester) async {
    final h = await Harness.create('preview');
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    h.downloads.valid = false;
    await tester.tap(find.text('Скачать обновление'));
    await tester.pumpAndSettle();
    h.downloads.emit(ApkTransferStatus.complete);
    await tester.pumpAndSettle();
    expect(find.text('Установить'), findsNothing);
    expect(find.textContaining('повреждён'), findsOneWidget);
    h.downloads.valid = true;
    await tester.tap(find.text('Повторить скачивание'));
    await tester.pumpAndSettle();
    h.downloads.emit(ApkTransferStatus.complete);
    await tester.pumpAndSettle();
    expect(find.text('Установить'), findsOneWidget);
  });

  testWidgets(
      'permission explanation, denial, resume and retry never auto-install',
      (tester) async {
    final h = await Harness.create('preview');
    h.installer.allowed = false;
    await h.ready();
    await tester.pumpWidget(h.widget());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Установить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('разрешите Android'), findsOneWidget);
    expect(h.installer.settings, 0);
    await tester.tap(find.text('Открыть настройки установки'));
    await tester.pumpAndSettle();
    expect(h.installer.settings, 1);
    await h.controller.refresh();
    expect(h.installer.launches, 0);
    await tester.tap(find.text('Установить'));
    await tester.pumpAndSettle();
    expect(h.installer.launches, 0);
    h.installer.allowed = true;
    await h.controller.refresh();
    expect(h.installer.launches, 0);
    await tester.tap(find.text('Установить'));
    await tester.pumpAndSettle();
    expect(h.installer.launches, 1);
  });

  for (final role in ['local', 'controller', 'receiver']) {
    testWidgets(
        '$role: playback starting while permission check waits blocks installer',
        (tester) async {
      final h = await Harness.create('preview');
      await h.ready();
      await tester.pumpWidget(h.widget());
      await tester.pumpAndSettle();
      h.installer.permission = Completer<bool>();
      await tester.tap(find.text('Установить'));
      await tester.pump();
      await h.startPlayback(role);
      await tester.pump();
      h.installer.permission!.complete(true);
      await tester.pumpAndSettle();
      expect(h.installer.launches, 0);
      expect(h.gateway.ends, isEmpty);
      expect(h.gateway.returns, isEmpty);
      expect(
          find.textContaining(role == 'local'
              ? 'Закройте просмотр'
              : 'недоступна во время Cast'),
          findsWidgets);
    });
    testWidgets(
        '$role: downloading remains allowed while installation is blocked',
        (tester) async {
      final h = await Harness.create('preview');
      await h.startPlayback(role);
      await tester.pumpWidget(h.widget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Скачать обновление'));
      await tester.pumpAndSettle();
      expect(h.downloads.starts, 1);
      h.downloads.emit(ApkTransferStatus.complete);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Установить'))
              .onPressed,
          isNull);
      await h.controller
          .install(); // the controller independently guards the action
      expect(h.installer.launches, 0);
    });
  }

  test(
      'restart reconciles active, interrupted and verified files independently of latest',
      () async {
    final downloads = FakeApkDownloads();
    final h = await Harness.create('preview', downloads: downloads);
    await h.controller.download(h.update);
    final selection = downloads.saved;
    final h2 = await Harness.create('preview', downloads: downloads);
    await h2.controller.initialize();
    expect(h2.controller.state.phase, ApkUpdatePhase.downloading);
    downloads.active = false;
    downloads.valid = false;
    await h2.controller.refresh();
    expect(h2.controller.state.phase, ApkUpdatePhase.failed);
    downloads.valid = true;
    final h3 = await Harness.create('preview', downloads: downloads);
    await h3.controller.initialize();
    expect(h3.controller.state.phase, ApkUpdatePhase.ready);
    expect(h3.controller.state.apk, selection);
    expect(h3.installer.launches, 0);
    h3.installedCode = 12;
    await h3.controller.install();
    expect(h3.installer.launches, 0);
    expect(h3.controller.state.phase, ApkUpdatePhase.idle);
  });

  test(
      'real file verifier rejects wrong SHA-256, length, missing and changed bytes',
      () async {
    final directory = await Directory.systemTemp.createTemp('apk-verifier');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/update.apk');
    final bytes = [1, 2, 3, 4];
    final hash = sha256.convert(bytes).toString();
    final update = AvailableUpdate(11, '11', '11-$hash', 4, hash, '/apk');
    final apk =
        SavedApk('org.localtube.app.debug', update, 'task', file.path);
    expect(await verifyApkFile(apk), false);
    await file.writeAsBytes(bytes);
    expect(await verifyApkFile(apk), true);
    await file.writeAsBytes([4, 3, 2, 1]);
    expect(await verifyApkFile(apk), false);
    await file.writeAsBytes([1, 2, 3]);
    expect(await verifyApkFile(apk), false);
  });
}

class Harness {
  Harness(this.container, this.downloads, this.installer, this.gateway,
      this.cast, this.receiver, this.channel);
  final ProviderContainer container;
  final FakeApkDownloads downloads;
  final FakeApkInstaller installer;
  final FakeCastGateway gateway;
  final CastController cast;
  final CastReceiverController receiver;
  final String channel;
  int installedCode = 10;
  String get id => channel == 'preview'
      ? 'org.localtube.app.debug'
      : 'org.localtube.app.stable';
  AvailableUpdate get update => AvailableUpdate.parse(
      metadata(channel, id, 11), InstalledApp(id, 10, '10'));
  ApkUpdateController get controller =>
      container.read(apkUpdateControllerProvider.notifier);
  static Future<Harness> create(String channel,
      {FakeApkDownloads? downloads}) async {
    final gateway = FakeCastGateway();
    final settings = InMemoryCastSettingsRepository(CastSettings.defaults);
    final registration = CastRegistrationService(
        gateway: gateway,
        identityService: CastDeviceIdentityService(
            identityRepository: FixedCastDeviceIdentityRepository('device-1'),
            deviceModelSource: FakeDeviceModelSource('Pixel')),
        settingsRepository: settings,
        logService: NoopLogService());
    await registration.initialize();
    final cast = CastController(
        gateway: gateway,
        settingsRepository: settings,
        registrationService: registration,
        playbackEndpoint: FakeCastPlaybackEndpoint(
            playback: const CastLocalPlayback(
                videoId: 42, position: Duration.zero, isPlaying: false)),
        progressWriteOwnership: RecordingCastProgressWriteOwnership(),
        logService: NoopLogService());
    await cast.initialized;
    final receiver = CastReceiverController(
        gateway: gateway,
        playback: FakeCastReceiverPlayback(),
        progressWriter: RecordingCastProgressWriter(),
        identityRepository: FixedCastDeviceIdentityRepository('tv-2'),
        clock: FakeCastClock(),
        logService: NoopLogService());
    final service = downloads ?? FakeApkDownloads();
    final installer = FakeApkInstaller();
    late Harness harness;
    final container = ProviderContainer(overrides: [
      apkUpdatesEnabledProvider.overrideWithValue(true),
      appConfigProvider.overrideWithValue(const AppConfig(
          apiBaseUrl: 'https://api.example/api',
          connectTimeoutMs: 500,
          receiveTimeoutMs: 500,
          sendTimeoutMs: 500,
          localApiHost: '192.0.2.10',
          localApiPort: 5000)),
      installedAppProvider.overrideWithValue(
          () async => InstalledApp(harness.id, harness.installedCode, '10')),
      updateSourceProvider
          .overrideWithValue((_) async => metadata(channel, harness.id, 11)),
      apkDownloadServiceProvider.overrideWithValue(service),
      apkInstallerProvider.overrideWithValue(installer),
      castControllerProvider.overrideWith((_) => cast),
      castReceiverControllerProvider.overrideWith((_) => receiver),
    ]);
    harness = Harness(
        container, service, installer, gateway, cast, receiver, channel);
    addTearDown(() async {
      container.dispose();
      service.dispose();
      await registration.dispose();
      await gateway.close();
    });
    return harness;
  }

  Widget widget({bool menu = true}) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: menu ? const AppUpdatesMenu() : const SizedBox()))));
  Future<void> ready() async {
    await controller.download(update);
    downloads.emit(ApkTransferStatus.complete);
    await flushMicrotasks();
  }

  Future<void> startPlayback(String role) async {
    switch (role) {
      case 'local':
        container.read(openUpdatePlaybackSurfacesProvider).enter();
      case 'controller':
        gateway.emitDevices([castDevice(deviceId: 'tv-2', name: 'TV')]);
        await flushMicrotasks();
        await cast.selectReceiver('tv-2');
        await cast.startCast(videoId: 42);
      case 'receiver':
        gateway.emitPrepareCommand(videoId: 42);
        await flushMicrotasks();
    }
  }
}

Future<void> flushMicrotasks() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.value();
  }
}
