import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/app_updates/app_updates.dart';

import 'apk_test_boundaries.dart';
import 'package:localtube_flutter/features/app_updates/apk_update_controller.dart';

void main() {
  for (final channel in ['preview', 'stable']) {
    testWidgets('$channel installation sees a newer version in the menu',
        (tester) async {
      final id = channel == 'preview'
          ? 'org.localtube.app.debug'
          : 'org.localtube.app.stable';
      await tester.pumpWidget(ProviderScope(overrides: [
        apkDownloadServiceProvider.overrideWithValue(FakeApkDownloads()),
        installedAppProvider
            .overrideWithValue(() async => InstalledApp(id, 10, '1.0.10')),
        updateSourceProvider.overrideWithValue((requestedChannel) async {
          expect(requestedChannel, channel);
          return metadata(channel, id, 11);
        }),
      ], child: const MaterialApp(home: Scaffold(body: AppUpdatesMenu()))));
      await tester.pumpAndSettle();
      expect(find.text('Доступна новая версия'), findsOneWidget);
      expect(find.textContaining('1.0.10 (10)'), findsOneWidget);
      expect(find.textContaining('1.0.11 (11)'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Скачать обновление'), findsNothing);
      await tester.tap(find.text('Проверить обновления'));
      await tester.pumpAndSettle();
      expect(find.text('Доступна новая версия'), findsOneWidget);
    });
  }
  for (final code in [9, 10]) {
    testWidgets('versionCode $code does not offer a downgrade or reinstall',
        (tester) async {
      await tester.pumpWidget(app(
          (_) async => metadata('preview', 'org.localtube.app.debug', code)));
      await tester.pumpAndSettle();
      expect(find.text('Новых обновлений нет'), findsOneWidget);
      expect(find.text('Доступна новая версия'), findsNothing);
    });
  }

  testWidgets('wrong application ID is rejected', (tester) async {
    await tester.pumpWidget(app(
        (_) async => metadata('preview', 'org.localtube.app.stable', 11)));
    await tester.pumpAndSettle();
    expect(find.text('Сервер вернул несовместимые сведения об обновлении'),
        findsOneWidget);
    expect(find.text('Доступна новая версия'), findsNothing);
  });

  testWidgets(
      'missing builds differs from no update and a manual network failure',
      (tester) async {
    var fail = false;
    await tester.pumpWidget(app((_) async {
      if (fail) throw Exception('offline');
      return null;
    }));
    await tester.pumpAndSettle();
    expect(find.text('Для этого канала ещё нет опубликованных сборок'),
        findsOneWidget);
    fail = true;
    await tester.tap(find.text('Проверить обновления'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Сервер обновлений недоступен'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('startup and repeated resumes share one active check',
      (tester) async {
    final pending = Completer<Map<String, dynamic>?>();
    var requests = 0;
    await tester.pumpWidget(app((_) {
      requests++;
      return pending.future;
    }, lifecycle: true));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(requests, 1);
    expect(find.text('Проверка обновлений…'), findsOneWidget);
    pending.complete(metadata('preview', 'org.localtube.app.debug', 11));
    await tester.pumpAndSettle();
    expect(find.text('Доступна новая версия'), findsOneWidget);
  });
}

Map<String, dynamic> metadata(String channel, String id, int code) => {
      'channel': channel,
      'applicationId': id,
      'versionCode': code,
      'versionName': '1.0.$code',
      'artifactId': '$code-${'a' * 64}',
      'size': 4,
      'sha256': 'a' * 64,
      'downloadUrl': '/app-updates/$channel/packages/$code-${'a' * 64}',
    };

Widget app(UpdateSource source, {bool lifecycle = false}) {
  Widget child = const MaterialApp(home: Scaffold(body: AppUpdatesMenu()));
  if (lifecycle) child = AppUpdateLifecycleListener(child: child);
  return ProviderScope(overrides: [
    apkDownloadServiceProvider.overrideWithValue(FakeApkDownloads()),
    installedAppProvider.overrideWithValue(() async =>
        const InstalledApp('org.localtube.app.debug', 10, '1.0.10')),
    updateSourceProvider.overrideWithValue(source),
  ], child: child);
}
