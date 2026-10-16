import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPathProviderPlatform;

  setUp(() {
    originalPathProviderPlatform = PathProviderPlatform.instance;
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPathProviderPlatform;
  });

  test('retains only last N entries in memory buffer', () {
    final LogService logService = LogService(maxInMemoryEntries: 2);

    logService.info('first');
    logService.info('second');
    logService.info('third');

    final List<LogEntry> entries = logService.entries;
    expect(entries.length, 2);
    expect(entries[0].message, 'second');
    expect(entries[1].message, 'third');
  });

  test('masks secrets in log message and error payload', () {
    final LogService logService = LogService();

    logService.info(
      'Authorization: Bearer abc.def.ghi '
      'password=myPassword '
      'https://example.com?access_token=token123',
    );
    logService.error(
      'login failed with refresh_token: refresh123',
      Exception('apiKey=secretValue'),
      StackTrace.current,
    );

    final List<LogEntry> entries = logService.entries;
    expect(entries, hasLength(2));
    expect(entries[0].message, contains('Bearer ***'));
    expect(entries[0].message, isNot(contains('myPassword')));
    expect(entries[0].message, contains('password=***'));
    expect(entries[0].message, contains('access_token=***'));
    expect(entries[1].message, contains('refresh_token: ***'));
    expect(entries[1].error, isNot(contains('secretValue')));
    expect(entries[1].error, contains('apiKey=***'));
  });

  test('saves log snapshot to a separate file', () async {
    final Directory logDirectory =
        await Directory.systemTemp.createTemp('localtube_logs_test_');
    final Directory exportDirectory =
        await Directory.systemTemp.createTemp('localtube_logs_export_');
    addTearDown(() async {
      for (final Directory directory in <Directory>[
        logDirectory,
        exportDirectory,
      ]) {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    });

    final LogService logService = LogService(
      logDirectory: logDirectory,
      exportDirectory: exportDirectory,
    );
    await logService.initialize();
    logService.info('snapshot message');

    final String? savedPath = await logService.saveSnapshot();

    expect(savedPath, isNotNull);
    expect(savedPath, isNot(endsWith('localtube.log')));
    expect(savedPath,
        startsWith('${exportDirectory.path}${Platform.pathSeparator}'));
    final File snapshotFile = File(savedPath!);
    expect(await snapshotFile.exists(), isTrue);
    expect(await snapshotFile.readAsString(), contains('snapshot message'));
  });

  test(
      'prefers Downloads for snapshot export even when log file lives elsewhere',
      () async {
    final Directory logDirectory =
        await Directory.systemTemp.createTemp('localtube_logs_live_');
    final Directory downloadsDirectory =
        await Directory.systemTemp.createTemp('localtube_logs_downloads_');
    final Directory externalDirectory =
        await Directory.systemTemp.createTemp('localtube_logs_external_');
    addTearDown(() async {
      for (final Directory directory in <Directory>[
        logDirectory,
        downloadsDirectory,
        externalDirectory,
      ]) {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    });

    PathProviderPlatform.instance = _FakePathProviderPlatform(
      downloadsPath: downloadsDirectory.path,
      androidDownloadsPath: downloadsDirectory.path,
      externalStoragePath: externalDirectory.path,
      applicationDocumentsPath: logDirectory.path,
    );

    final LogService logService = LogService(
      logDirectory: logDirectory,
      isAndroidOverride: true,
    );
    await logService.initialize();
    logService.info('snapshot to downloads');

    final String? savedPath = await logService.saveSnapshot();

    expect(savedPath, isNotNull);
    expect(
      savedPath,
      startsWith(
        '${downloadsDirectory.path}${Platform.pathSeparator}LocalTubeLogs${Platform.pathSeparator}',
      ),
    );
    expect(savedPath, isNot(contains(logDirectory.path)));
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    this.downloadsPath,
    this.androidDownloadsPath,
    this.applicationDocumentsPath,
    this.externalStoragePath,
  });

  final String? downloadsPath;
  final String? androidDownloadsPath;
  final String? applicationDocumentsPath;
  final String? externalStoragePath;

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      applicationDocumentsPath;

  @override
  Future<String?> getDownloadsPath() async => downloadsPath;

  @override
  Future<String?> getExternalStoragePath() async => externalStoragePath;

  @override
  Future<List<String>?> getExternalStoragePaths(
      {StorageDirectory? type}) async {
    if (type == StorageDirectory.downloads) {
      if (androidDownloadsPath == null) {
        return null;
      }
      return <String>[androidDownloadsPath!];
    }
    if (externalStoragePath == null) {
      return null;
    }
    return <String>[externalStoragePath!];
  }
}
