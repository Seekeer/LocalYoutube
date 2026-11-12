import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/app/bootstrap/bootstrap_providers.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/features/app_updates/apk_update_controller.dart';
import 'package:localtube_flutter/features/app_updates/app_updates.dart';
import 'package:localtube_flutter/features/app_updates/windows_update_controller.dart';

import 'apk_test_boundaries.dart';
import 'app_updates_widget_test.dart' show metadata;

const installed = InstalledApp(windowsApplicationId, 10, '1.1.10');

Map<String, dynamic> windowsMetadata(int code) => {
      'channel': 'windows-stable',
      'applicationId': windowsApplicationId,
      'versionCode': code,
      'versionName': '1.1.$code',
      'artifactId': '$code-${'c' * 64}',
      'size': 8,
      'sha256': 'c' * 64,
      'downloadUrl': '/app-updates/windows-stable/packages/$code-${'c' * 64}',
    };

AvailableUpdate windowsUpdate(int code) =>
    AvailableUpdate.parse(windowsMetadata(code), installed);

class FakeWindowsInstaller implements WindowsUpdateInstaller {
  AvailableUpdate? selection;
  WindowsApplyResult? result;
  bool valid = true;
  Object? downloadError;
  Completer<void>? downloadGate;
  String? prepareFailure;
  Object? launchError;
  Uri? url;
  int downloads = 0;
  int clears = 0;
  int launches = 0;
  int exits = 0;
  int releases = 0;
  bool busy = false;
  final List<String> events = [];

  @override
  Future<WindowsApplyResult?> takeApplyResult() async {
    final value = result;
    result = null;
    return value;
  }

  @override
  Future<AvailableUpdate?> reconcile(InstalledApp installed) async {
    final saved = selection;
    if (saved != null && saved.versionCode > installed.versionCode && valid) {
      return saved;
    }
    clears++;
    selection = null;
    return null;
  }

  @override
  Future<void> download(InstalledApp installed, AvailableUpdate update,
      Uri url, void Function(double progress) onProgress,
      Future<void> canceled) async {
    if (busy) throw const WindowsUpdateBusy();
    selection = update;
    downloads++;
    this.url = url;
    onProgress(0.5);
    final gate = downloadGate;
    if (gate != null) {
      await Future.any([gate.future, canceled]);
      if (!gate.isCompleted) throw const WindowsDownloadCanceled();
    }
    if (downloadError case final error?) throw error;
  }

  @override
  Future<bool> verify(AvailableUpdate update) async => valid;
  @override
  Future<String?> prepare(InstalledApp installed, AvailableUpdate update) async {
    events.add('prepare');
    return prepareFailure;
  }

  @override
  Future<void> launchApplier(AvailableUpdate update) async {
    events.add('launch');
    if (launchError case final error?) throw error;
    launches++;
  }

  @override
  Future<void> release() async {
    releases++;
  }

  @override
  Future<void> exitApplication() async {
    events.add('exit');
    exits++;
  }
}

WindowsUpdateController controller(FakeWindowsInstaller installer,
        {String? Function()? block, InstalledApp? app = installed}) =>
    WindowsUpdateController(installer, () async => app, block ?? () => null,
        (path) => Uri(scheme: 'http', host: 'lan.test', port: 5000, path: path));

void main() {
  test('Windows identity resolves its own channel and rejects Android metadata',
      () {
    expect(installed.channel, 'windows-stable');
    expect(installed.channelLabel, 'Windows Stable');
    const preview = InstalledApp(windowsPreviewApplicationId, 10, '1.1.10');
    expect(preview.channel, 'windows-preview');
    expect(preview.channelLabel, 'Windows Preview');
    expect(() => AvailableUpdate.parse(windowsMetadata(11), preview),
        throwsFormatException);
    final previewMetadata = {
      ...windowsMetadata(11),
      'channel': 'windows-preview',
      'applicationId': windowsPreviewApplicationId,
      'downloadUrl': '/app-updates/windows-preview/packages/11-${'c' * 64}',
    };
    expect(AvailableUpdate.parse(previewMetadata, preview).versionCode, 11);
    expect(() => AvailableUpdate.parse(previewMetadata, installed),
        throwsFormatException);
    expect(windowsUpdate(11).versionCode, 11);
    expect(
        () => AvailableUpdate.parse(
            metadata('stable', 'org.localtube.app.stable', 11), installed),
        throwsFormatException);
    final stable = InstalledApp(
        const String.fromEnvironment('LOCALTUBE_STABLE_APPLICATION_ID',
            defaultValue: 'org.localtube.app.stable'),
        10,
        '1.0.10');
    expect(() => AvailableUpdate.parse(windowsMetadata(11), stable),
        throwsFormatException);
  });

  test('Windows updates use only the HTTPS API; Android keeps the LAN listener',
      () {
    const config = AppConfig(
        apiBaseUrl: 'https://api.example.test:9999/',
        connectTimeoutMs: 1,
        receiveTimeoutMs: 1,
        sendTimeoutMs: 1,
        localApiHost: '192.0.2.10',
        localApiPort: 55);
    expect(
        updateServerUri(
                config, 'windows-stable', '/app-updates/windows-stable/latest')
            .toString(),
        'https://api.example.test:9999/app-updates/windows-stable/latest');
    expect(
        updateServerUri(config, 'stable', '/app-updates/stable/latest')
            .toString(),
        'http://192.0.2.10:55/app-updates/stable/latest');
    const plain = AppConfig(
        apiBaseUrl: 'http://api.example.test',
        connectTimeoutMs: 1,
        receiveTimeoutMs: 1,
        sendTimeoutMs: 1,
        localApiHost: '192.0.2.10',
        localApiPort: 55);
    expect(() => updateServerUri(plain, 'windows-stable', '/x'),
        throwsStateError);
  });

  group('system installer files', () {
    late Directory root;
    late SystemWindowsUpdateInstaller files;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('localtube-updates-');
      files = SystemWindowsUpdateInstaller(
          directory: Directory('${root.path}/updates'),
          application: Directory('${root.path}/app'));
    });
    tearDown(() => root.delete(recursive: true));

    test('selection survives a restart and the package is hash-checked',
        () async {
      final update = windowsUpdate(11);
      await files.saveSelection(installed, update);
      final loaded = await files.loadSelection(installed);
      expect(loaded?.artifactId, update.artifactId);
      expect(await files.verify(update), isFalse);
      await File('${root.path}/updates/${update.artifactId}.zip')
          .writeAsBytes(List<int>.filled(8, 1));
      expect(await files.verify(update), isFalse);
    });

    test('cleanup and results wait while the applier holds its lock',
        () async {
      await files.saveSelection(installed, windowsUpdate(11));
      final result = File('${root.path}/updates/apply-result.json');
      await result.writeAsString(
          '\uFEFF{"status":"failed","versionCode":11,"reason":"busy"}');
      final lock = File('${root.path}/updates/applying.lock');
      await lock.writeAsString('1');
      await files.reconcile(installed);
      expect(await files.takeApplyResult(), isNull);
      expect(await files.loadSelection(installed), isNotNull);
      expect(await files.prepare(installed, windowsUpdate(11)),
          contains('уже устанавливается'));
      await lock.delete();
      // No package exists: preparation fails (or tar.exe is absent off
      // Windows) and must not keep the lock either way.
      try {
        expect(await files.prepare(installed, windowsUpdate(11)), isNotNull);
      } on ProcessException {
        // Expected on non-Windows test runners.
      }
      expect(await lock.exists(), isFalse,
          reason: 'a failed preparation releases its lock');
      final taken = await files.takeApplyResult();
      expect(taken?.applied, isFalse);
      expect(taken?.reason, 'busy');
      expect(await result.exists(), isFalse);
      await files.reconcile(installed);
      expect(await files.loadSelection(installed), isNull);
    });

    test('a complete newer download survives startup reconciliation',
        () async {
      final bytes = List<int>.filled(8, 7);
      final update = AvailableUpdate.parse({
        ...windowsMetadata(11),
        'artifactId': '11-${sha256.convert(bytes)}',
        'sha256': '${sha256.convert(bytes)}',
        'downloadUrl':
            '/app-updates/windows-stable/packages/11-${sha256.convert(bytes)}',
      }, installed);
      await files.saveSelection(installed, update);
      await File('${root.path}/updates/${update.artifactId}.zip')
          .writeAsBytes(bytes);
      expect((await files.reconcile(installed))?.artifactId, update.artifactId);
      expect(await files.loadSelection(installed), isNotNull);
      const upgraded = InstalledApp(windowsApplicationId, 11, '1.1.11');
      expect(await files.reconcile(upgraded), isNull);
      expect(await files.loadSelection(installed), isNull);
    });

    test('an applier that died long ago no longer blocks cleanup', () async {
      await files.saveSelection(installed, windowsUpdate(11));
      final marker = File('${root.path}/updates/applying.lock');
      await marker.writeAsString('1');
      await marker.setLastModified(
          DateTime.now().subtract(const Duration(minutes: 11)));
      await files.reconcile(installed);
      expect(await marker.exists(), isFalse);
      expect(await files.loadSelection(installed), isNull);
    });

    test('another process holding the updater lock blocks every change',
        () async {
      await files.saveSelection(installed, windowsUpdate(11));
      final never = Completer<void>();
      // Byte-range locks are per handle on Windows; POSIX locks are per
      // process, so this contention can only be shown on Windows.
      final other = await File('${root.path}/updates/updater.lock')
          .open(mode: FileMode.append);
      await other.lock(FileLock.exclusive);
      try {
        await files.reconcile(installed);
        expect(await files.loadSelection(installed), isNotNull);
        expect(await files.prepare(installed, windowsUpdate(11)),
            contains('уже устанавливается'));
        await expectLater(
            files.download(installed, windowsUpdate(12),
                Uri.parse('https://example.test/x'), (_) {}, never.future),
            throwsA(isA<WindowsUpdateBusy>()));
      } finally {
        await other.close();
      }
      await files.reconcile(installed);
      expect(await files.loadSelection(installed), isNull);
    }, skip: !Platform.isWindows);
  });

  test('download verifies the package before offering installation', () async {
    final installer = FakeWindowsInstaller();
    final updates = controller(installer);
    await updates.download(windowsUpdate(11));
    expect(updates.state.phase, WindowsUpdatePhase.ready);
    expect(installer.selection?.versionCode, 11);
    expect(installer.url.toString(),
        'http://lan.test:5000/app-updates/windows-stable/packages/11-${'c' * 64}');
    expect(installer.launches, 0);
  });

  test('corrupt or failed downloads can be retried', () async {
    final installer = FakeWindowsInstaller()..valid = false;
    final updates = controller(installer);
    await updates.download(windowsUpdate(11));
    expect(updates.state.phase, WindowsUpdatePhase.failed);
    expect(updates.state.message, contains('Повторите скачивание'));
    installer
      ..valid = true
      ..downloadError = Exception('offline');
    await updates.download(windowsUpdate(11));
    expect(updates.state.phase, WindowsUpdatePhase.failed);
    expect(updates.state.message, contains('Проверьте подключение к серверу'));
    installer.downloadError = null;
    await updates.download(windowsUpdate(11));
    expect(updates.state.phase, WindowsUpdatePhase.ready);
    expect(installer.downloads, 3);
  });

  test('download can be canceled and started again', () async {
    final installer = FakeWindowsInstaller()..downloadGate = Completer<void>();
    final updates = controller(installer);
    final running = updates.download(windowsUpdate(11));
    await Future<void>.delayed(Duration.zero);
    expect(updates.state.phase, WindowsUpdatePhase.downloading);
    expect(updates.state.progress, 0.5);
    updates.cancel();
    await running;
    expect(updates.state.phase, WindowsUpdatePhase.canceled);
    installer.downloadGate = null;
    await updates.download(windowsUpdate(11));
    expect(updates.state.phase, WindowsUpdatePhase.ready);
  });

  test('a download held by another LocalTube process is reported', () async {
    final installer = FakeWindowsInstaller()..busy = true;
    final updates = controller(installer);
    await updates.download(windowsUpdate(11));
    expect(updates.state.phase, WindowsUpdatePhase.failed);
    expect(updates.state.message, contains('другом окне LocalTube'));
  });

  test('older or same versions are never downloaded', () async {
    final installer = FakeWindowsInstaller();
    final updates = controller(installer);
    await updates.download(AvailableUpdate.parse(windowsMetadata(10), installed));
    expect(updates.state.phase, WindowsUpdatePhase.failed);
    expect(installer.downloads, 0);
  });

  test('installation is explicit, prepared, then restarts LocalTube', () async {
    final installer = FakeWindowsInstaller();
    final updates = controller(installer);
    await updates.download(windowsUpdate(11));
    expect(installer.events, isEmpty);
    await updates.install();
    expect(installer.events, ['prepare', 'launch', 'exit']);
  });

  test('blocked, unprepared or failed launches keep the package for retry',
      () async {
    String? block = 'Закройте просмотр перед установкой обновления';
    final installer = FakeWindowsInstaller();
    final updates = controller(installer, block: () => block);
    await updates.download(windowsUpdate(11));
    await updates.install();
    expect(installer.events, isEmpty);
    expect(updates.state.message, block);
    expect(updates.state.phase, WindowsUpdatePhase.ready);

    block = null;
    installer.prepareFailure = 'Нет прав на запись в папку LocalTube';
    await updates.install();
    expect(installer.events, ['prepare']);
    expect(updates.state.phase, WindowsUpdatePhase.ready);
    expect(updates.state.installFailed, isTrue);
    expect(updates.state.message, installer.prepareFailure);

    installer
      ..prepareFailure = null
      ..launchError = Exception('powershell missing');
    await updates.install();
    expect(installer.exits, 0);
    expect(installer.releases, 1);
    expect(updates.state.phase, WindowsUpdatePhase.ready);
    expect(updates.state.message, contains('Можно повторить'));

    installer.launchError = null;
    await updates.install();
    expect(installer.exits, 1);
  });

  test('a failed apply restores the verified package with a retry', () async {
    final installer = FakeWindowsInstaller()
      ..selection = windowsUpdate(11)
      ..result = const WindowsApplyResult(false, 11, 'file in use');
    final updates = controller(installer);
    await updates.initialize();
    expect(updates.state.phase, WindowsUpdatePhase.ready);
    expect(updates.state.installFailed, isTrue);
    expect(updates.state.message, contains('прежняя версия восстановлена'));
    expect(updates.state.message, contains('file in use'));
  });

  test('a successful apply is reported and its files are cleaned up', () async {
    const updated = InstalledApp(windowsApplicationId, 11, '1.1.11');
    final installer = FakeWindowsInstaller()
      ..selection = windowsUpdate(11)
      ..result = const WindowsApplyResult(true, 11, '');
    final updates = controller(installer, app: updated);
    await updates.initialize();
    expect(installer.clears, 1);
    expect(updates.state.phase, WindowsUpdatePhase.idle);
    expect(updates.state.message, 'Обновление установлено: 1.1.11');
  });

  test('an interrupted download is discarded silently at startup', () async {
    final installer = FakeWindowsInstaller()
      ..selection = windowsUpdate(11)
      ..valid = false;
    final updates = controller(installer);
    await updates.initialize();
    expect(installer.clears, 1);
    expect(updates.state.phase, WindowsUpdatePhase.idle);
    expect(updates.state.message, isNull);
  });

  testWidgets('menu offers download, then installation with restart',
      (tester) async {
    final installer = FakeWindowsInstaller();
    await tester.pumpWidget(ProviderScope(overrides: [
      apkDownloadServiceProvider.overrideWithValue(FakeApkDownloads()),
      windowsUpdatesEnabledProvider.overrideWithValue(true),
      appConfigProvider.overrideWithValue(const AppConfig(
          apiBaseUrl: 'https://api.example.test',
          connectTimeoutMs: 1,
          receiveTimeoutMs: 1,
          sendTimeoutMs: 1)),
      windowsUpdateInstallerProvider.overrideWithValue(installer),
      updateInstallBlockProvider.overrideWithValue(null),
      installedAppProvider.overrideWithValue(() async => installed),
      updateSourceProvider.overrideWithValue((channel) async {
        expect(channel, 'windows-stable');
        return windowsMetadata(11);
      }),
    ], child: const MaterialApp(home: Scaffold(body: AppUpdatesMenu()))));
    await tester.pumpAndSettle();
    expect(find.text('Доступна новая версия'), findsOneWidget);
    expect(find.textContaining('Windows Stable · Установлена: 1.1.10'),
        findsOneWidget);
    expect(find.text('Установить и перезапустить'), findsNothing);
    await tester.tap(find.text('Скачать обновление'));
    await tester.pumpAndSettle();
    expect(find.text('Обновление скачано и проверено'), findsOneWidget);
    expect(find.text('Скачать обновление'), findsNothing);
    expect(installer.events, isEmpty);
    await tester.tap(find.text('Установить и перезапустить'));
    // The restart message keeps an indeterminate indicator running.
    await tester.pump();
    await tester.pump();
    expect(installer.events, ['prepare', 'launch', 'exit']);
    expect(find.text('LocalTube перезапустится с новой версией…'), findsOneWidget);
  });

  testWidgets('local Windows builds without a version show no update card',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      apkDownloadServiceProvider.overrideWithValue(FakeApkDownloads()),
      installedAppProvider.overrideWithValue(() async => null),
      updateSourceProvider.overrideWithValue((_) async => null),
    ], child: const MaterialApp(home: Scaffold(body: AppUpdatesMenu()))));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });
}
