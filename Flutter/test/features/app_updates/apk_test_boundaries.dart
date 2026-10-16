import 'dart:async';

import 'package:localtube_flutter/features/app_updates/apk_download_service.dart';
import 'package:localtube_flutter/features/app_updates/apk_update_controller.dart';
import 'package:localtube_flutter/features/app_updates/update_models.dart';

class FakeApkDownloads implements ApkDownloadService {
  final updates = StreamController<ApkTransferEvent>.broadcast();
  SavedApk? saved;
  bool active = false;
  bool valid = true;
  bool notifications = true;
  bool accepted = true;
  int starts = 0;
  int cancels = 0;
  Uri? url;
  Completer<bool>? verification;
  Completer<void>? cancellation;
  @override
  Stream<ApkTransferEvent> get events => updates.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<SavedApk?> load(InstalledApp installed) async => saved;
  @override
  Future<SavedApk> prepare(
      InstalledApp installed, AvailableUpdate update, Uri url) async {
    this.url = url;
    return saved = SavedApk(installed.applicationId, update,
        'task-${starts + 1}', '/private/${update.artifactId}.apk');
  }

  @override
  Future<bool> enqueue(SavedApk apk) async {
    starts++;
    active = accepted;
    return accepted;
  }

  @override
  Future<bool> isActive(SavedApk apk) async => active;
  @override
  Future<void> cancel(SavedApk apk) async {
    if (cancellation != null) await cancellation!.future;
    active = false;
    cancels++;
  }

  @override
  Future<bool> verify(SavedApk apk) async =>
      verification == null ? valid : await verification!.future;
  @override
  Future<bool> requestNotifications() async => notifications;
  void emit(ApkTransferStatus status, [double progress = 0]) {
    if (status != ApkTransferStatus.running) active = false;
    updates.add(ApkTransferEvent(saved!.taskId, status, progress));
  }

  @override
  void dispose() {
    if (!updates.isClosed) unawaited(updates.close());
  }
}

class FakeApkInstaller implements ApkInstaller {
  bool allowed = true;
  bool fail = false;
  int settings = 0;
  int launches = 0;
  Completer<bool>? permission;
  @override
  Future<bool> canInstall() async =>
      permission == null ? allowed : await permission!.future;
  @override
  Future<void> openPermissionSettings() async {
    settings++;
  }

  @override
  Future<void> launch(SavedApk apk) async {
    launches++;
    if (fail) throw Exception('Canceled/unavailable installer');
  }
}
