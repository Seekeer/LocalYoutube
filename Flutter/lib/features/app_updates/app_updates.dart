import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_models.dart';
import 'update_sources.dart';
export 'update_sources.dart';
import 'apk_update_controller.dart';
export 'update_models.dart';

enum UpdateStatus {
  idle,
  checking,
  unsupported,
  noBuilds,
  current,
  available,
  unavailable,
  incompatible
}

class AppUpdateState {
  const AppUpdateState(this.status, {this.installed, this.available});

  final UpdateStatus status;
  final InstalledApp? installed;
  final AvailableUpdate? available;
}

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>((ref) =>
        AppUpdateController(
            ref.watch(installedAppProvider), ref.watch(updateSourceProvider)));

class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController(this._installedApp, this._source)
      : super(const AppUpdateState(UpdateStatus.idle));

  final InstalledAppSource _installedApp;
  final UpdateSource _source;
  Future<void>? _inFlight;

  Future<void> check() =>
      _inFlight ??= _check().whenComplete(() => _inFlight = null);

  Future<void> _check() async {
    InstalledApp? installed = state.installed;
    state = AppUpdateState(UpdateStatus.checking, installed: installed);
    try {
      installed = await _installedApp();
      if (installed?.channel == null) {
        if (mounted) {
          state =
              AppUpdateState(UpdateStatus.unsupported, installed: installed);
        }
        return;
      }
      final json = await _source(installed!.channel!);
      final update =
          json == null ? null : AvailableUpdate.parse(json, installed);
      if (!mounted) return;
      state = AppUpdateState(
          json == null
              ? UpdateStatus.noBuilds
              : update!.versionCode > installed.versionCode
                  ? UpdateStatus.available
                  : UpdateStatus.current,
          installed: installed,
          available:
              update != null && update.versionCode > installed.versionCode
                  ? update
                  : null);
    } on FormatException {
      if (mounted) {
        state = AppUpdateState(UpdateStatus.incompatible, installed: installed);
      }
    } catch (_) {
      if (mounted) {
        state = AppUpdateState(UpdateStatus.unavailable, installed: installed);
      }
    }
  }
}

class AppUpdatesMenu extends ConsumerStatefulWidget {
  const AppUpdatesMenu({super.key});

  @override
  ConsumerState<AppUpdatesMenu> createState() => _AppUpdatesMenuState();
}

class _AppUpdatesMenuState extends ConsumerState<AppUpdatesMenu> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted && ref.read(apkUpdatesEnabledProvider)) {
        unawaited(ref.read(apkUpdateControllerProvider.notifier).initialize());
      }
      if (mounted &&
          ref.read(appUpdateControllerProvider).status == UpdateStatus.idle) {
        unawaited(ref.read(appUpdateControllerProvider.notifier).check());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateControllerProvider);
    if (state.status == UpdateStatus.unsupported ||
        state.status == UpdateStatus.idle) {
      return const SizedBox.shrink();
    }
    final apkEnabled = ref.watch(apkUpdatesEnabledProvider);
    final apk = apkEnabled
        ? ref.watch(apkUpdateControllerProvider)
        : const ApkUpdateState();
    final installed = state.installed;
    final available = state.available;
    final download = apkEnabled ? (apk.apk?.update ?? available) : null;
    final message = switch (state.status) {
      UpdateStatus.checking => 'Проверка обновлений…',
      UpdateStatus.available => 'Доступна новая версия',
      UpdateStatus.current => 'Новых обновлений нет',
      UpdateStatus.noBuilds => 'Для этого канала ещё нет опубликованных сборок',
      UpdateStatus.unavailable =>
        'Сервер обновлений недоступен. Подключитесь к локальной сети и повторите проверку.',
      UpdateStatus.incompatible =>
        'Сервер вернул несовместимые сведения об обновлении',
      _ => '',
    };
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(available == null
                      ? Icons.system_update
                      : Icons.new_releases),
                  const SizedBox(width: 8),
                  const Text('Обновление приложения'),
                ]),
                if (installed != null)
                  Text(
                      '${installed.channel == 'preview' ? 'Preview' : 'Stable'} · Установлена: ${installed.versionName} (${installed.versionCode})'),
                if (available != null)
                  Text(
                      'Доступна: ${available.versionName} (${available.versionCode})'),
                Text(message, textAlign: TextAlign.center),
                if (apk.apk != null)
                  Text(
                      'APK: ${apk.apk!.update.versionName} (${apk.apk!.update.versionCode})'),
                if (apk.active) ...[
                  LinearProgressIndicator(
                      value: apk.phase == ApkUpdatePhase.downloading
                          ? apk.progress
                          : null),
                  Text(apk.phase == ApkUpdatePhase.verifying
                      ? 'Проверка APK…'
                      : apk.phase == ApkUpdatePhase.canceling
                          ? 'Отмена загрузки…'
                          : 'Скачивание: ${(apk.progress * 100).round()}%'),
                  if (apk.phase == ApkUpdatePhase.downloading)
                    TextButton(
                        onPressed: () => ref
                            .read(apkUpdateControllerProvider.notifier)
                            .cancel(),
                        child: const Text('Отменить загрузку')),
                ],
                if (apk.message != null)
                  Text(apk.message!, textAlign: TextAlign.center),
                if (apk.phase == ApkUpdatePhase.ready)
                  const _InstallApkAction(),
                if (!apk.active &&
                    apk.phase != ApkUpdatePhase.ready &&
                    download != null)
                  TextButton(
                      onPressed: () => ref
                          .read(apkUpdateControllerProvider.notifier)
                          .download(download),
                      child: Text(apk.phase == ApkUpdatePhase.failed ||
                              apk.phase == ApkUpdatePhase.canceled
                          ? 'Повторить скачивание'
                          : 'Скачать обновление')),
                TextButton(
                    onPressed: state.status == UpdateStatus.checking
                        ? null
                        : () => ref
                            .read(appUpdateControllerProvider.notifier)
                            .check(),
                    child: const Text('Проверить обновления')),
              ],
            )));
  }
}

// Kept above the router so checks also run when a player is open, without UI there.
class AppUpdateLifecycleListener extends ConsumerStatefulWidget {
  const AppUpdateLifecycleListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppUpdateLifecycleListener> createState() =>
      _AppUpdateLifecycleListenerState();
}

class _AppUpdateLifecycleListenerState
    extends ConsumerState<AppUpdateLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_check);
  }

  void _check() {
    if (mounted) {
      unawaited(ref.read(appUpdateControllerProvider.notifier).check());
      if (ref.read(apkUpdatesEnabledProvider)) {
        unawaited(ref.read(apkUpdateControllerProvider.notifier).refresh());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _InstallApkAction extends ConsumerWidget {
  const _InstallApkAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(updateInstallBlockProvider);
    final installing = ref.watch(apkUpdateControllerProvider).installing;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (reason != null) Text(reason, textAlign: TextAlign.center),
      if (ref.watch(apkUpdateControllerProvider).needsPermission)
        TextButton(
            onPressed: reason != null || installing
                ? null
                : () => ref
                    .read(apkUpdateControllerProvider.notifier)
                    .openPermissionSettings(),
            child: const Text('Открыть настройки установки')),
      TextButton(
          onPressed: reason != null || installing
              ? null
              : () => ref.read(apkUpdateControllerProvider.notifier).install(),
          child: const Text('Установить')),
    ]);
  }
}
