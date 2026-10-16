import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'update_models.dart';

class SavedApk {
  const SavedApk(this.applicationId, this.update, this.taskId, this.path);
  final String applicationId;
  final AvailableUpdate update;
  final String taskId;
  final String path;

  Map<String, dynamic> toJson() => {
        'applicationId': applicationId,
        'channel': InstalledApp(applicationId, 1, '').channel,
        'versionCode': update.versionCode,
        'versionName': update.versionName,
        'artifactId': update.artifactId,
        'size': update.size,
        'sha256': update.sha256,
        'downloadUrl': update.downloadUrl,
        'taskId': taskId,
      };
}

enum ApkTransferStatus { running, complete, failed, canceled }

class ApkTransferEvent {
  const ApkTransferEvent(this.taskId, this.status, [this.progress = 0]);
  final String taskId;
  final ApkTransferStatus status;
  final double progress;
}

// All filesystem and background_downloader operations live at this boundary.
// A saved record is an immutable version selection, independent of latest.
abstract interface class ApkDownloadService {
  Stream<ApkTransferEvent> get events;
  Future<void> initialize();
  Future<SavedApk?> load(InstalledApp installed);
  Future<SavedApk> prepare(
      InstalledApp installed, AvailableUpdate update, Uri url);
  Future<bool> enqueue(SavedApk apk);
  Future<bool> isActive(SavedApk apk);
  Future<void> cancel(SavedApk apk);
  Future<bool> verify(SavedApk apk);
  Future<bool> requestNotifications();
  void dispose();
}

class BackgroundApkDownloadService implements ApkDownloadService {
  static const group = 'app-updates';
  final FileDownloader _downloader = FileDownloader();
  final _events = StreamController<ApkTransferEvent>.broadcast();
  final Map<String, DownloadTask> _prepared = {};
  Directory? _directory;
  Future<void>? _initializing;

  @override
  Stream<ApkTransferEvent> get events => _events.stream;

  @override
  Future<void> initialize() => _initializing ??=
          _initialize().catchError((Object error, StackTrace stack) {
        _initializing = null;
        Error.throwWithStackTrace(error, stack);
      });

  Future<void> _initialize() async {
    _directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/app-updates');
    await _directory!.create(recursive: true);
    _downloader.registerCallbacks(
      group: group,
      taskStatusCallback: (event) {
        final status = switch (event.status) {
          TaskStatus.complete => ApkTransferStatus.complete,
          TaskStatus.failed ||
          TaskStatus.notFound ||
          TaskStatus.paused =>
            ApkTransferStatus.failed,
          TaskStatus.canceled => ApkTransferStatus.canceled,
          _ => ApkTransferStatus.running,
        };
        if (!_events.isClosed) {
          _events.add(ApkTransferEvent(event.task.taskId, status));
        }
      },
      taskProgressCallback: (event) {
        if (!_events.isClosed && event.progress >= 0 && event.progress < 1) {
          _events.add(ApkTransferEvent(
              event.task.taskId, ApkTransferStatus.running, event.progress));
        }
      },
    );
    await _downloader.configure(globalConfig: [(Config.runInForeground, true)]);
    _downloader.configureNotificationForGroup(group,
        running: const TaskNotification(
            'Обновление LocalTube', 'Скачивание {progress}'),
        complete: const TaskNotification('Обновление LocalTube',
            'Загрузка завершена. Откройте меню приложения для проверки.'),
        error: const TaskNotification('Обновление LocalTube',
            'Ошибка загрузки. Повторите в меню приложения.'),
        progressBar: true,
        tapOpensFile: false);
    await _downloader.trackTasksInGroup(group);
    await _downloader.resumeFromBackground();
  }

  File get _record => File('${_directory!.path}/selected.json');

  @override
  Future<SavedApk?> load(InstalledApp installed) async {
    await initialize();
    if (!await _record.exists()) return null;
    try {
      final json =
          jsonDecode(await _record.readAsString()) as Map<String, dynamic>;
      final update = AvailableUpdate.parse(json, installed);
      final taskId = json['taskId'] as String;
      final apk = SavedApk(installed.applicationId, update, taskId,
          '${_directory!.path}/${update.artifactId}.apk');
      // Never restore a task for a different file/group from plugin storage.
      return apk;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<SavedApk> prepare(
      InstalledApp installed, AvailableUpdate update, Uri url) async {
    await initialize();
    final previous = await _downloader.allTasks(group: group);
    if (previous.isNotEmpty &&
        !await _downloader
            .cancelTasksWithIds(previous.map((task) => task.taskId))) {
      throw StateError('Cannot stop previous APK task');
    }
    final task = DownloadTask(
        url: url.toString(),
        filename: '${update.artifactId}.apk',
        directory: _directory!.path,
        baseDirectory: BaseDirectory.root,
        group: group,
        updates: Updates.statusAndProgress,
        retries: 3,
        allowPause: false);
    final apk = SavedApk(
        installed.applicationId, update, task.taskId, await task.filePath());
    final file = File(apk.path);
    if (await file.exists()) await file.delete();
    final pending = File('${_record.path}.tmp');
    await pending.writeAsString(jsonEncode(apk.toJson()), flush: true);
    await pending.rename(_record.path);
    _prepared[apk.taskId] = task;
    return apk;
  }

  @override
  Future<bool> enqueue(SavedApk apk) async =>
      _downloader.enqueue(_prepared.remove(apk.taskId)!);

  @override
  Future<bool> isActive(SavedApk apk) async {
    final task = await _downloader.taskForId(apk.taskId);
    return task != null &&
        task.group == group &&
        await task.filePath() == apk.path;
  }

  @override
  Future<void> cancel(SavedApk apk) async {
    if (!await _downloader.cancelTaskWithId(apk.taskId)) {
      throw StateError('Cannot cancel APK task');
    }
  }

  @override
  Future<bool> verify(SavedApk apk) => verifyApkFile(apk);

  @override
  Future<bool> requestNotifications() async {
    var status =
        await _downloader.permissions.status(PermissionType.notifications);
    if (status != PermissionStatus.granted) {
      status =
          await _downloader.permissions.request(PermissionType.notifications);
    }
    return status == PermissionStatus.granted;
  }

  @override
  void dispose() {
    _downloader.unregisterCallbacks(group: group);
    unawaited(_events.close());
  }
}

Future<bool> verifyApkFile(SavedApk apk) async {
  try {
    final file = File(apk.path);
    if (!await file.exists() || await file.length() != apk.update.size) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == apk.update.sha256;
  } on FileSystemException {
    return false;
  }
}
