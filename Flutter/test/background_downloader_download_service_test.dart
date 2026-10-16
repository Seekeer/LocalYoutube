import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
// The plugin exposes permissions through FileDownloader but does not export its interface.
// ignore: implementation_imports
import 'package:background_downloader/src/permissions.dart' show Permissions;
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/auth/token_repository.dart';
import 'package:localtube_flutter/core/config/app_config.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/downloads/data/background_downloader_download_service.dart';
import 'package:localtube_flutter/features/downloads/data/local_downloads_repository.dart';
import 'package:localtube_flutter/features/downloads/domain/download_models.dart';
import 'package:mocktail/mocktail.dart';

class _MockDownloader extends Mock implements FileDownloader {}

class _MockPermissions extends Mock implements Permissions {}

class _MockDownloadsRepository extends Mock
    implements LocalDownloadsRepository {}

class _MockTokenRepository extends Mock implements TokenRepository {}

class _MockLogService extends Mock implements LogService {}

void main() {
  late _MockDownloader downloader;
  late _MockPermissions permissions;
  late _MockDownloadsRepository repository;
  late _MockTokenRepository tokens;
  late _MockLogService logs;
  late BackgroundDownloaderDownloadService service;

  BackgroundDownloaderDownloadService createService(
      DownloadPlatformKind platform) {
    return BackgroundDownloaderDownloadService(
      localDownloadsRepository: repository,
      appConfig: const AppConfig(
        apiBaseUrl: 'https://example.com',
        connectTimeoutMs: 1000,
        receiveTimeoutMs: 1000,
        sendTimeoutMs: 1000,
      ),
      tokenRepository: tokens,
      logService: logs,
      platformKind: platform,
      downloader: downloader,
    );
  }

  setUpAll(() {
    registerFallbackValue(DownloadTask(url: 'https://example.com/video.mp4'));
    registerFallbackValue(TaskNotification('Download', '{filename}'));
    registerFallbackValue(DownloadItem(
      videoId: 1,
      status: DownloadStatus.paused,
      progress: 0,
      remoteUrl: '/api/files/getFileById?fileId=1',
      queuedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ));
  });

  setUp(() {
    downloader = _MockDownloader();
    permissions = _MockPermissions();
    repository = _MockDownloadsRepository();
    tokens = _MockTokenRepository();
    logs = _MockLogService();
    when(() => downloader.permissions).thenReturn(permissions);
    when(() => permissions.status(PermissionType.notifications))
        .thenAnswer((_) async => PermissionStatus.denied);
    when(() => permissions.request(PermissionType.notifications))
        .thenAnswer((_) async => PermissionStatus.granted);
    when(() => downloader.configure(
            globalConfig: any<Object?>(named: 'globalConfig')))
        .thenAnswer((_) async => <(String, String)>[]);
    when(() => downloader.configureNotificationForGroup(
          any(),
          running: any(named: 'running'),
          complete: any(named: 'complete'),
          error: any(named: 'error'),
          progressBar: any(named: 'progressBar'),
          tapOpensFile: any(named: 'tapOpensFile'),
        )).thenReturn(downloader);
    when(() => downloader.trackTasks()).thenAnswer((_) async => downloader);
    when(() => downloader.resumeFromBackground()).thenAnswer((_) async {});
    when(() => downloader.updates)
        .thenAnswer((_) => const Stream<TaskUpdate>.empty());
    when(() => downloader.enqueue(any())).thenAnswer((_) async => true);
    when(() => repository.listAll()).thenAnswer((_) async => <DownloadItem>[]);
    when(() => repository.findByVideoId(any())).thenAnswer((_) async => null);
    when(() => repository.queueDownload(
          videoId: any(named: 'videoId'),
          remoteUrl: any(named: 'remoteUrl'),
          title: any(named: 'title'),
          queuedAt: any(named: 'queuedAt'),
          taskId: any(named: 'taskId'),
          localPath: any(named: 'localPath'),
        )).thenAnswer((_) async {});
    when(() => repository.save(any())).thenAnswer((_) async {});
    when(() => tokens.read()).thenAnswer((_) async => null);
    service = createService(DownloadPlatformKind.android);
    addTearDown(() => service.dispose());
  });

  test('requests notification permission before starting an Android download',
      () async {
    await service.enqueue(
        videoId: 1, remoteUrl: '/api/files/getFileById?fileId=1');

    verifyInOrder(<void Function()>[
      () => permissions.request(PermissionType.notifications),
      () => downloader.enqueue(any()),
    ]);
  });

  test('requests notification permission when resuming a saved download',
      () async {
    when(() => repository.findByVideoId(1))
        .thenAnswer((_) async => DownloadItem(
              videoId: 1,
              status: DownloadStatus.paused,
              progress: 0.5,
              remoteUrl: '/api/files/getFileById?fileId=1',
              queuedAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ));
    when(() => downloader.taskCanResume(any())).thenAnswer((_) async => false);

    await service.resume(1);

    verifyInOrder(<void Function()>[
      () => permissions.request(PermissionType.notifications),
      () => downloader.enqueue(any()),
    ]);
  });

  test('concurrent downloads wait for the same notification permission request',
      () async {
    await service.initialize();
    final Completer<PermissionStatus> permissionResult =
        Completer<PermissionStatus>();
    final Completer<void> permissionRequested = Completer<void>();
    when(() => permissions.request(PermissionType.notifications))
        .thenAnswer((_) {
      permissionRequested.complete();
      return permissionResult.future;
    });

    final Future<void> first = service.enqueue(
      videoId: 1,
      remoteUrl: '/api/files/getFileById?fileId=1',
    );
    final Future<void> second = service.enqueue(
      videoId: 2,
      remoteUrl: '/api/files/getFileById?fileId=2',
    );
    await permissionRequested.future;
    verifyNever(() => downloader.enqueue(any()));
    permissionResult.complete(PermissionStatus.granted);
    await Future.wait(<Future<void>>[first, second]);

    verify(() => permissions.request(PermissionType.notifications)).called(1);
    verify(() => downloader.enqueue(any())).called(2);
  });

  test('does not request already granted notification permission', () async {
    when(() => permissions.status(PermissionType.notifications))
        .thenAnswer((_) async => PermissionStatus.granted);

    await service.enqueue(
        videoId: 1, remoteUrl: '/api/files/getFileById?fileId=1');

    verifyNever(() => permissions.request(PermissionType.notifications));
    verify(() => downloader.enqueue(any())).called(1);
  });

  test('denied notification permission is requested once and logged', () async {
    when(() => permissions.request(PermissionType.notifications))
        .thenAnswer((_) async => PermissionStatus.denied);

    await service.enqueue(
        videoId: 1, remoteUrl: '/api/files/getFileById?fileId=1');
    await service.enqueue(
        videoId: 2, remoteUrl: '/api/files/getFileById?fileId=2');

    verify(() => permissions.request(PermissionType.notifications)).called(1);
    verify(() => logs.warn(any())).called(1);
    verify(() => downloader.enqueue(any())).called(2);
  });

  test('Windows downloads do not request Android notification permission',
      () async {
    await service.dispose();
    service = createService(DownloadPlatformKind.windows);

    await service.enqueue(
        videoId: 1, remoteUrl: '/api/files/getFileById?fileId=1');

    verifyNever(() => permissions.status(PermissionType.notifications));
    verifyNever(() => permissions.request(PermissionType.notifications));
    verify(() => downloader.enqueue(any())).called(1);
  });
}
