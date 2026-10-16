import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap/bootstrap_providers.dart';
import '../cast/presentation/cast_controller.dart';
import '../cast/presentation/cast_receiver_controller.dart';
import 'apk_download_service.dart';
import 'update_sources.dart';
import 'update_models.dart';

// Distribution workflows opt in for both Preview and Stable.
final apkUpdatesEnabledProvider = Provider<bool>(
    (ref) => const bool.fromEnvironment('LOCALTUBE_APK_UPDATES_ENABLED'));

final apkDownloadServiceProvider = Provider<ApkDownloadService>((ref) {
  final service = BackgroundApkDownloadService();
  ref.onDispose(service.dispose);
  return service;
});

// Counts open viewing surfaces, including paused playback and fullscreen routes.
class UpdatePlaybackSurfaces extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  bool _disposed = false;
  void enter() {
    _count++;
    _notifyLater();
  }

  void leave() {
    _count--;
    _notifyLater();
  }

  void _notifyLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final openUpdatePlaybackSurfacesProvider =
    ChangeNotifierProvider<UpdatePlaybackSurfaces>(
        (ref) => UpdatePlaybackSurfaces());
final updateInstallBlockProvider = Provider<String?>((ref) {
  final controller = ref.watch(castControllerProvider);
  final receiver = ref.watch(castReceiverControllerProvider);
  if (controller.sessionId != null ||
      controller.phase != CastPhase.idle ||
      receiver.sessionId != null ||
      receiver.phase != CastReceiverPhase.idle) {
    return 'Установка недоступна во время Cast Session';
  }
  if (ref.watch(openUpdatePlaybackSurfacesProvider).count > 0) {
    return 'Закройте просмотр перед установкой обновления';
  }
  return null;
});

abstract interface class ApkInstaller {
  Future<bool> canInstall();
  Future<void> openPermissionSettings();
  Future<void> launch(SavedApk apk);
}

class AndroidApkInstaller implements ApkInstaller {
  static const _channel = MethodChannel('org.localtube.app/app_updates');
  @override
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;
  @override
  Future<void> openPermissionSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');
  @override
  Future<void> launch(SavedApk apk) =>
      _channel.invokeMethod<void>('installApk', {
        'path': apk.path,
        'versionCode': apk.update.versionCode,
        'size': apk.update.size,
        'sha256': apk.update.sha256,
      });
}

final apkInstallerProvider =
    Provider<ApkInstaller>((ref) => AndroidApkInstaller());
final apkUpdateControllerProvider =
    StateNotifierProvider<ApkUpdateController, ApkUpdateState>((ref) {
  return ApkUpdateController(
    ref.watch(apkDownloadServiceProvider),
    ref.watch(installedAppProvider),
    ref.watch(apkInstallerProvider),
    () => ref.read(openUpdatePlaybackSurfacesProvider).count > 0
        ? 'Закройте просмотр перед установкой обновления'
        : ref.read(updateInstallBlockProvider),
    (path) {
      final config = ref.read(appConfigProvider);
      if (config.localApiHost.trim().isEmpty || config.localApiPort <= 0) {
        throw StateError('LAN update server is not configured');
      }
      return Uri(
          scheme: 'http',
          host: config.localApiHost,
          port: config.localApiPort,
          path: path);
    },
  );
});

enum ApkUpdatePhase {
  idle,
  preparing,
  downloading,
  canceling,
  verifying,
  ready,
  failed,
  canceled
}

class ApkUpdateState {
  const ApkUpdateState(
      {this.phase = ApkUpdatePhase.idle,
      this.apk,
      this.progress = 0,
      this.message,
      this.installing = false,
      this.needsPermission = false});
  final ApkUpdatePhase phase;
  final SavedApk? apk;
  final double progress;
  final String? message;
  final bool installing;
  final bool needsPermission;
  bool get active =>
      phase == ApkUpdatePhase.preparing ||
      phase == ApkUpdatePhase.downloading ||
      phase == ApkUpdatePhase.canceling ||
      phase == ApkUpdatePhase.verifying;
}

class ApkUpdateController extends StateNotifier<ApkUpdateState> {
  ApkUpdateController(
      this._downloads, this._installed, this._installer, this._block, this._url)
      : super(const ApkUpdateState()) {
    _subscription = _downloads.events.listen((event) {
      _events = _events.then((_) => _onEvent(event)).catchError((Object _) {
        if (mounted) {
          _failed('Не удалось проверить файл. Повторите скачивание.');
        }
      });
    });
  }
  final ApkDownloadService _downloads;
  final InstalledAppSource _installed;
  final ApkInstaller _installer;
  final String? Function() _block;
  final Uri Function(String) _url;
  late final StreamSubscription<ApkTransferEvent> _subscription;
  Future<void> _events = Future.value();
  Future<void>? _initializing;
  bool _starting = false;
  bool _installing = false;
  String? _notice;

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      final installed = await _installed();
      if (!mounted || installed?.channel == null) return;
      await _downloads.initialize();
      final apk = await _downloads.load(installed!);
      if (!mounted ||
          apk == null ||
          apk.update.versionCode <= installed.versionCode) {
        return;
      }
      state = ApkUpdateState(phase: ApkUpdatePhase.downloading, apk: apk);
      if (!await _downloads.isActive(apk) &&
          mounted &&
          state.phase == ApkUpdatePhase.downloading) {
        await _verify(apk);
      }
    } catch (_) {
      if (mounted) {
        _failed('Не удалось восстановить загрузку. Повторите скачивание.');
      }
    }
  }

  Future<void> download(AvailableUpdate update) async {
    if (_starting || state.active || _installing) return;
    _starting = true;
    try {
      await initialize();
      if (!mounted || state.active) return;
      state = const ApkUpdateState(phase: ApkUpdatePhase.preparing);
      final installed = await _installed();
      if (installed?.channel == null ||
          update.versionCode <= installed!.versionCode ||
          !update.downloadUrl
              .startsWith('/app-updates/${installed.channel}/packages/')) {
        throw StateError('Incompatible or already installed APK');
      }
      _notice = await _downloads.requestNotifications()
          ? null
          : 'Уведомления отключены. Android может приостановить загрузку в фоне. Разрешите уведомления в настройках приложения.';
      final apk =
          await _downloads.prepare(installed, update, _url(update.downloadUrl));
      if (!mounted) return;
      state = ApkUpdateState(
          phase: ApkUpdatePhase.preparing, apk: apk, message: _notice);
      final accepted = await _downloads.enqueue(apk);
      if (!mounted) return;
      if (!accepted) {
        _failed('Не удалось начать загрузку. Повторите.');
      } else if (state.phase == ApkUpdatePhase.preparing) {
        state = ApkUpdateState(
            phase: ApkUpdatePhase.downloading, apk: apk, message: _notice);
      }
    } catch (_) {
      if (mounted) {
        _failed('Ошибка загрузки. Проверьте локальную сеть и повторите.');
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> cancel() async {
    final apk = state.apk;
    if (apk == null || state.phase != ApkUpdatePhase.downloading || _starting) {
      return;
    }
    state = ApkUpdateState(
        phase: ApkUpdatePhase.canceling, apk: apk, message: 'Отмена загрузки…');
    try {
      await _downloads.cancel(apk);
      if (mounted) {
        state = ApkUpdateState(
            phase: ApkUpdatePhase.canceled,
            apk: apk,
            message: 'Загрузка отменена');
      }
    } catch (_) {
      if (mounted) {
        state = ApkUpdateState(
            phase: ApkUpdatePhase.downloading,
            apk: apk,
            message: 'Не удалось отменить загрузку. Повторите отмену.');
      }
    }
  }

  Future<void> _onEvent(ApkTransferEvent event) async {
    if (!mounted) return;
    final apk = state.apk;
    if (apk == null ||
        apk.taskId != event.taskId ||
        (state.phase != ApkUpdatePhase.preparing &&
            state.phase != ApkUpdatePhase.downloading)) {
      return;
    }
    switch (event.status) {
      case ApkTransferStatus.running:
        state = ApkUpdateState(
            phase: ApkUpdatePhase.downloading,
            apk: apk,
            progress: event.progress.clamp(state.progress, 1),
            message: _notice);
      case ApkTransferStatus.complete:
        await _verify(apk);
      case ApkTransferStatus.failed:
        _failed('Ошибка загрузки или записи файла. Повторите скачивание.');
      case ApkTransferStatus.canceled:
        state = ApkUpdateState(
            phase: ApkUpdatePhase.canceled,
            apk: apk,
            message: 'Загрузка отменена');
    }
  }

  Future<void> _verify(SavedApk apk) async {
    state = ApkUpdateState(phase: ApkUpdatePhase.verifying, apk: apk);
    final valid = await _downloads.verify(apk);
    if (!mounted) return;
    state = ApkUpdateState(
        phase: valid ? ApkUpdatePhase.ready : ApkUpdatePhase.failed,
        apk: apk,
        message: valid
            ? 'APK проверен и готов к установке'
            : 'Файл отсутствует или повреждён. Повторите скачивание.');
  }

  void _failed(String message) => state = ApkUpdateState(
      phase: ApkUpdatePhase.failed, apk: state.apk, message: message);

  // Resume reconciles interrupted tasks and installed version, never launches an installer.
  Future<void> refresh() async {
    await initialize();
    if (_starting ||
        _installing ||
        !mounted ||
        state.phase == ApkUpdatePhase.canceling ||
        state.phase == ApkUpdatePhase.verifying) {
      return;
    }
    try {
      final installed = await _installed();
      final apk = state.apk;
      if (!mounted || apk == null || installed == null) return;
      if (installed.applicationId != apk.applicationId ||
          installed.versionCode >= apk.update.versionCode) {
        state = const ApkUpdateState();
      } else if (state.active && !await _downloads.isActive(apk)) {
        await _verify(apk);
      } else if (state.phase == ApkUpdatePhase.ready &&
          !await _downloads.verify(apk)) {
        _failed('Файл отсутствует или повреждён. Повторите скачивание.');
      }
    } catch (_) {
      if (mounted) {
        _failed('Не удалось проверить состояние APK. Повторите скачивание.');
      }
    }
  }

  Future<void> install() async {
    if (_installing ||
        state.phase != ApkUpdatePhase.ready ||
        state.apk == null) {
      return;
    }
    _installing = true;
    final apk = state.apk!;
    void message(String text, {bool permission = false}) {
      if (mounted) {
        state = ApkUpdateState(
            phase: ApkUpdatePhase.ready,
            apk: apk,
            message: text,
            installing: _installing,
            needsPermission: permission);
      }
    }

    try {
      message('Проверка перед установкой…');
      if (_block() case final reason?) {
        message(reason);
        return;
      }
      final installed = await _installed();
      if (installed == null ||
          installed.applicationId != apk.applicationId ||
          installed.channel == null ||
          apk.update.versionCode <= installed.versionCode) {
        state = const ApkUpdateState(
            message: 'Эта версия уже установлена или несовместима');
        return;
      }
      if (!await _downloads.verify(apk)) {
        _failed('Файл отсутствует или повреждён. Повторите скачивание.');
        return;
      }
      if (!await _installer.canInstall()) {
        message(
            'Для установки обновления разрешите Android устанавливать приложения из LocalTube. После возврата снова нажмите «Установить».',
            permission: true);
        return;
      }
      if (!mounted) return;
      // No awaits between this guard and invoking the Android boundary.
      if (_block() case final reason?) {
        message(reason);
        return;
      }
      await _installer.launch(apk);
      message('Установщик открыт. После возврата можно повторить установку.');
    } catch (_) {
      message('Установка не запущена или отменена. Можно повторить.');
    } finally {
      _installing = false;
      if (mounted && state.phase == ApkUpdatePhase.ready) {
        state = ApkUpdateState(
            phase: state.phase,
            apk: apk,
            message: state.message,
            needsPermission: state.needsPermission);
      }
    }
  }

  Future<void> openPermissionSettings() async {
    if (_installing || !state.needsPermission || _block() != null) return;
    try {
      await _installer.openPermissionSettings();
    } catch (_) {
      if (mounted) {
        state = ApkUpdateState(
            phase: state.phase,
            apk: state.apk,
            needsPermission: true,
            message: 'Не удалось открыть настройки. Можно повторить.');
      }
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
