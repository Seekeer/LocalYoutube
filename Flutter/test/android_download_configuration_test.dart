import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('Android 14 allows the downloader to start a dataSync service', () {
    final Iterable<String> permissions =
        RegExp(r'<uses-permission\b[^>]*>').allMatches(manifest).map(
              (RegExpMatch match) => match.group(0)!,
            );
    expect(
      permissions,
      contains(contains(
        'android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"',
      )),
      reason:
          'Android 14 rejects foreground downloads without this permission.',
    );
  });

  test('WorkManager foreground downloads declare the dataSync service type',
      () {
    final Iterable<String> services =
        RegExp(r'<service\b[^>]*>').allMatches(manifest).map(
              (RegExpMatch match) => match.group(0)!,
            );
    final String downloaderService = services.firstWhere(
      (String service) => service.contains(
        'android:name="androidx.work.impl.foreground.SystemForegroundService"',
      ),
      orElse: () => '',
    );
    expect(
      downloaderService,
      contains('android:foregroundServiceType="dataSync"'),
      reason:
          'Android must recognize the WorkManager worker as a data transfer.',
    );
  });
}
