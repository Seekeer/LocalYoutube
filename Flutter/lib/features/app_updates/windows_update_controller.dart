import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/bootstrap/bootstrap_providers.dart';
import '../../core/config/windows_edition.dart';
import 'apk_update_controller.dart' show updateInstallBlockProvider;
import 'update_models.dart';
import 'update_sources.dart';
import 'windows_applier_launcher.dart';

// Only CI-built Windows bundles carry a version, so only they offer updates.
final windowsUpdatesEnabledProvider = Provider<bool>((ref) =>
    Platform.isWindows &&
    windowsVersionCode > 0 &&
    windowsVersionName.isNotEmpty);

final windowsUpdateInstallerProvider = Provider<WindowsUpdateInstaller>(
    (ref) => SystemWindowsUpdateInstaller());

final windowsUpdateControllerProvider =
    StateNotifierProvider<WindowsUpdateController, WindowsUpdateState>((ref) {
  return WindowsUpdateController(
    ref.watch(windowsUpdateInstallerProvider),
    ref.watch(installedAppProvider),
    () => ref.read(updateInstallBlockProvider),
    (path) =>
        updateServerUri(ref.read(appConfigProvider), windowsUpdateChannel, path),
  );
});

/// Outcome the applier script leaves for the next start of LocalTube.
class WindowsApplyResult {
  const WindowsApplyResult(this.applied, this.versionCode, this.reason);
  final bool applied;
  final int versionCode;
  final String reason;
}

class WindowsDownloadCanceled implements Exception {
  const WindowsDownloadCanceled();
}

/// Another LocalTube process of this installation is downloading or applying.
class WindowsUpdateBusy implements Exception {
  const WindowsUpdateBusy();
}

/// Filesystem, network and process operations of a portable Windows update.
abstract interface class WindowsUpdateInstaller {
  Future<WindowsApplyResult?> takeApplyResult();

  /// In one locked step: returns the saved selection when it is newer than
  /// [installed] and its package verifies; otherwise removes the selection,
  /// package, staging and backup and returns null. Changes nothing while
  /// another process of this installation holds the lock.
  Future<AvailableUpdate?> reconcile(InstalledApp installed);

  /// Records [update] as the selection and downloads it, holding the
  /// installation lock throughout. Throws [WindowsUpdateBusy] when another
  /// process holds it.
  Future<void> download(InstalledApp installed, AvailableUpdate update,
      Uri url, void Function(double progress) onProgress,
      Future<void> canceled);
  Future<bool> verify(AvailableUpdate update);

  /// Unpacks and checks the verified package. Returns a user-facing reason
  /// when this installation cannot be updated in place.
  Future<String?> prepare(InstalledApp installed, AvailableUpdate update);

  /// Starts the detached applier that waits for LocalTube to exit. The
  /// installation lock taken by [prepare] passes to the applier.
  Future<void> launchApplier(AvailableUpdate update);

  /// Releases the installation lock taken by [prepare] without installing.
  Future<void> release();
  Future<void> exitApplication();
}

enum WindowsUpdatePhase {
  idle,
  downloading,
  canceling,
  verifying,
  ready,
  installing,
  failed,
  canceled
}

class WindowsUpdateState {
  const WindowsUpdateState(
      {this.phase = WindowsUpdatePhase.idle,
      this.update,
      this.progress = 0,
      this.message,
      this.installFailed = false});
  final WindowsUpdatePhase phase;
  final AvailableUpdate? update;
  final double progress;
  final String? message;

  /// The last installation attempt failed; the verified package can be retried.
  final bool installFailed;
  bool get active =>
      phase == WindowsUpdatePhase.downloading ||
      phase == WindowsUpdatePhase.canceling ||
      phase == WindowsUpdatePhase.verifying ||
      phase == WindowsUpdatePhase.installing;
}

class WindowsUpdateController extends StateNotifier<WindowsUpdateState> {
  WindowsUpdateController(
      this._installer, this._installed, this._block, this._url)
      : super(const WindowsUpdateState());

  final WindowsUpdateInstaller _installer;
  final InstalledAppSource _installed;
  final String? Function() _block;
  final Uri Function(String) _url;
  Future<void>? _initializing;
  Completer<void>? _cancel;
  bool _starting = false;

  Future<void> initialize() => _initializing ??= _initialize();

  // Reports the previous installation attempt and restores a verified package.
  Future<void> _initialize() async {
    try {
      final installed = await _installed();
      if (!mounted || !(installed?.isWindows ?? false)) return;
      final result = await _installer.takeApplyResult();
      final selected = await _installer.reconcile(installed!);
      if (!mounted) return;
      final failure = result == null || result.applied
          ? null
          : 'Не удалось применить обновление, прежняя версия восстановлена'
              '${result.reason.isEmpty ? '' : ' (${result.reason})'}.';
      if (selected != null) {
        state = WindowsUpdateState(
            phase: WindowsUpdatePhase.ready,
            update: selected,
            message: failure == null
                ? 'Обновление скачано и готово к установке'
                : '$failure Можно повторить установку.',
            installFailed: failure != null);
        return;
      }
      // Installed, superseded or interrupted: nothing is left to install.
      if (result == null) return;
      state = failure == null
          ? WindowsUpdateState(
              message: 'Обновление установлено: ${installed.versionName}')
          : WindowsUpdateState(
              phase: WindowsUpdatePhase.failed,
              message: '$failure Повторите обновление.');
    } catch (_) {
      if (mounted) {
        state = const WindowsUpdateState(
            phase: WindowsUpdatePhase.failed,
            message: 'Не удалось проверить скачанное обновление. Повторите.');
      }
    }
  }

  Future<void> download(AvailableUpdate update) async {
    if (_starting || state.active) return;
    _starting = true;
    try {
      await initialize();
    } finally {
      _starting = false;
    }
    if (!mounted || state.active) return;
    final cancel = _cancel = Completer<void>();
    state = WindowsUpdateState(
        phase: WindowsUpdatePhase.downloading, update: update);
    try {
      final installed = await _installed();
      if (!(installed?.isWindows ?? false) ||
          update.versionCode <= installed!.versionCode ||
          !update.downloadUrl
              .startsWith('/app-updates/${installed.channel}/packages/')) {
        throw StateError('Incompatible or already installed update');
      }
      await _installer.download(installed, update, _url(update.downloadUrl),
          (progress) {
        if (mounted && state.phase == WindowsUpdatePhase.downloading) {
          state = WindowsUpdateState(
              phase: WindowsUpdatePhase.downloading,
              update: update,
              progress: progress.clamp(state.progress, 1));
        }
      }, cancel.future);
      if (!mounted) return;
      state =
          WindowsUpdateState(phase: WindowsUpdatePhase.verifying, update: update);
      final valid = await _installer.verify(update);
      if (!mounted) return;
      state = valid
          ? WindowsUpdateState(
              phase: WindowsUpdatePhase.ready,
              update: update,
              message: 'Обновление скачано и проверено')
          : WindowsUpdateState(
              phase: WindowsUpdatePhase.failed,
              update: update,
              message: 'Файл повреждён или изменён. Повторите скачивание.');
    } on WindowsDownloadCanceled {
      if (mounted) {
        state = WindowsUpdateState(
            phase: WindowsUpdatePhase.canceled,
            update: update,
            message: 'Загрузка отменена');
      }
    } on WindowsUpdateBusy {
      if (mounted) {
        state = WindowsUpdateState(
            phase: WindowsUpdatePhase.failed,
            update: update,
            message: 'Обновление уже скачивается или устанавливается в другом '
                'окне LocalTube. Повторите позже.');
      }
    } catch (_) {
      if (mounted) {
        state = WindowsUpdateState(
            phase: WindowsUpdatePhase.failed,
            update: update,
            message:
                'Ошибка загрузки. Проверьте подключение к серверу и повторите.');
      }
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  void cancel() {
    final cancel = _cancel;
    if (cancel == null ||
        cancel.isCompleted ||
        state.phase != WindowsUpdatePhase.downloading) {
      return;
    }
    state = WindowsUpdateState(
        phase: WindowsUpdatePhase.canceling,
        update: state.update,
        progress: state.progress,
        message: 'Отмена загрузки…');
    cancel.complete();
  }

  Future<void> install() async {
    final update = state.update;
    if (state.phase != WindowsUpdatePhase.ready || update == null) return;
    void retry(String message) {
      if (mounted) {
        state = WindowsUpdateState(
            phase: WindowsUpdatePhase.ready,
            update: update,
            message: message,
            installFailed: true);
      }
    }

    if (_block() case final reason?) {
      state = WindowsUpdateState(
          phase: WindowsUpdatePhase.ready, update: update, message: reason);
      return;
    }
    state = WindowsUpdateState(
        phase: WindowsUpdatePhase.installing,
        update: update,
        message: 'Подготовка установки…');
    try {
      final installed = await _installed();
      if (!(installed?.isWindows ?? false) ||
          update.versionCode <= installed!.versionCode) {
        if (installed != null) await _installer.reconcile(installed);
        if (mounted) {
          state = const WindowsUpdateState(
              message: 'Эта версия уже установлена или несовместима');
        }
        return;
      }
      if (!await _installer.verify(update)) {
        if (mounted) {
          state = WindowsUpdateState(
              phase: WindowsUpdatePhase.failed,
              update: update,
              message: 'Файл повреждён или изменён. Повторите скачивание.');
        }
        return;
      }
      if (await _installer.prepare(installed, update) case final reason?) {
        retry(reason);
        return;
      }
      // Playback or a Cast Session may have started while unpacking.
      if (_block() case final reason?) {
        await _installer.release();
        retry(reason);
        return;
      }
      if (mounted) {
        state = WindowsUpdateState(
            phase: WindowsUpdatePhase.installing,
            update: update,
            message: 'LocalTube перезапустится с новой версией…');
      }
      await _installer.launchApplier(update);
      await _installer.exitApplication();
    } catch (_) {
      try {
        await _installer.release();
      } catch (_) {
        // The stale lock expires on its own.
      }
      retry('Не удалось запустить установку. Можно повторить.');
    }
  }
}

class SystemWindowsUpdateInstaller implements WindowsUpdateInstaller {
  SystemWindowsUpdateInstaller({Directory? directory, Directory? application})
      : _directoryOverride = directory,
        _applicationOverride = application;

  final Directory? _directoryOverride;
  final Directory? _applicationOverride;

  /// OS lock on `updater.lock` this process holds from [prepare] until it
  /// exits (after launching the applier) or [release]s it.
  RandomAccessFile? _mutex;

  // AppData is shared by every portable copy of LocalTube, so each
  // installation folder gets its own update directory.
  Future<Directory> _directory() async {
    final installation = sha256
        .convert(utf8.encode(_application.absolute.path.toLowerCase()))
        .toString()
        .substring(0, 16);
    final directory = _directoryOverride ??
        Directory([
          (await getApplicationSupportDirectory()).path,
          'app-updates',
          'install-$installation',
        ].join(Platform.pathSeparator));
    await directory.create(recursive: true);
    return directory;
  }

  // `applying.lock` marks an applier that was launched and has not finished.
  // It is created and removed only under the `updater.lock` OS lock; an old
  // marker means the applier died before it took that lock.
  static const _applyLockTimeout = Duration(minutes: 10);
  Future<bool> _applying(Directory directory) async {
    final lock = File(_path(directory, 'applying.lock'));
    if (!await lock.exists()) return false;
    final age = DateTime.now().difference(await lock.lastModified());
    return age < _applyLockTimeout;
  }

  Directory get _application =>
      _applicationOverride ?? File(Platform.resolvedExecutable).parent;
  String get _executableName =>
      File(Platform.resolvedExecutable).uri.pathSegments.last;

  String _path(Directory directory, String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  Future<File> _package(AvailableUpdate update) async =>
      File(_path(await _directory(), '${update.artifactId}.zip'));

  /// Reads the saved selection without locking (diagnostics and tests).
  Future<AvailableUpdate?> loadSelection(InstalledApp installed) async =>
      _readSelection(await _directory(), installed);

  Future<AvailableUpdate?> _readSelection(
      Directory directory, InstalledApp installed) async {
    final record = File(_path(directory, 'selected.json'));
    if (!await record.exists()) return null;
    try {
      final json = jsonDecode(await record.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return AvailableUpdate.parse(json, installed);
    } on FormatException {
      return null;
    }
  }

  /// Records [update] as the selection (used by tests; downloads record it
  /// themselves under the lock).
  Future<void> saveSelection(InstalledApp installed, AvailableUpdate update) =>
      _exclusive<bool>(false, (directory) async {
        await _writeSelection(directory, installed, update);
        return true;
      });

  Future<void> _writeSelection(Directory directory, InstalledApp installed,
      AvailableUpdate update) async {
    final pending = File(_path(directory, 'selected.json.tmp'));
    await pending.writeAsString(
        jsonEncode({
          'channel': installed.channel,
          'applicationId': installed.applicationId,
          'versionCode': update.versionCode,
          'versionName': update.versionName,
          'artifactId': update.artifactId,
          'size': update.size,
          'sha256': update.sha256,
          'downloadUrl': update.downloadUrl,
        }),
        flush: true);
    await pending.rename(_path(directory, 'selected.json'));
  }

  // `updater.lock` is never deleted, so an OS lock on it is a real mutex
  // between LocalTube processes of one installation. The applier opens it
  // without sharing for the whole copy. The OS frees both on process exit.
  Future<RandomAccessFile?> _lockDirectory(Directory directory) async {
    RandomAccessFile? handle;
    try {
      handle = await File(_path(directory, 'updater.lock'))
          .open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      return handle;
    } on FileSystemException {
      await handle?.close();
      return null;
    }
  }

  Future<T> _exclusive<T>(
      T busy, Future<T> Function(Directory directory) body) async {
    final directory = await _directory();
    final handle = await _lockDirectory(directory);
    if (handle == null) return busy;
    try {
      return await body(directory);
    } finally {
      await handle.close();
    }
  }

  @override
  Future<WindowsApplyResult?> takeApplyResult() =>
      _exclusive<WindowsApplyResult?>(null, _takeApplyResult);

  Future<WindowsApplyResult?> _takeApplyResult(Directory directory) async {
    final file = File(_path(directory, 'apply-result.json'));
    if (await _applying(directory) || !await file.exists()) return null;
    try {
      // PowerShell may write a UTF-8 byte order mark.
      final text = (await file.readAsString()).replaceFirst('\uFEFF', '');
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;
      final code = json['versionCode'];
      final reason = json['reason'];
      return WindowsApplyResult(json['status'] == 'applied',
          code is int ? code : 0, reason is String ? reason : '');
    } on FormatException {
      return null;
    } finally {
      await file.delete();
    }
  }

  @override
  Future<AvailableUpdate?> reconcile(InstalledApp installed) =>
      _exclusive<AvailableUpdate?>(null, (directory) async {
        if (await _applying(directory)) return null;
        final selected = await _readSelection(directory, installed);
        if (selected != null &&
            selected.versionCode > installed.versionCode &&
            await verify(selected)) {
          return selected;
        }
        await for (final entry in directory.list()) {
          final name =
              entry.uri.pathSegments.lastWhere((part) => part.isNotEmpty);
          // The mutex file stays; an unread result waits for the next start.
          if (name == 'updater.lock' || name == 'apply-result.json') continue;
          await entry.delete(recursive: true);
        }
        return null;
      });

  @override
  Future<void> download(InstalledApp installed, AvailableUpdate update,
      Uri url, void Function(double progress) onProgress,
      Future<void> canceled) async {
    final directory = await _directory();
    final handle = await _lockDirectory(directory);
    if (handle == null) throw const WindowsUpdateBusy();
    try {
      if (await _applying(directory)) throw const WindowsUpdateBusy();
      await _writeSelection(directory, installed, update);
      await _download(directory, update, url, onProgress, canceled);
    } finally {
      await handle.close();
    }
  }

  Future<void> _download(Directory directory, AvailableUpdate update, Uri url,
      void Function(double progress) onProgress, Future<void> canceled) async {
    final package = await _package(update);
    final partial = File('${package.path}.part');
    // Only the selected version is kept; older or interrupted packages go.
    await for (final entry in directory.list()) {
      if (entry is File &&
          (entry.path.endsWith('.zip') || entry.path.endsWith('.zip.part'))) {
        await entry.delete();
      }
    }
    final token = CancelToken();
    unawaited(canceled.then((_) => token.cancel()));
    final client = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60)));
    try {
      await client.downloadUri(url, partial.path,
          cancelToken: token,
          deleteOnError: true,
          options: Options(headers: {'Cache-Control': 'no-cache'}),
          onReceiveProgress: (received, total) {
        final size = total > 0 ? total : update.size;
        onProgress(received / size);
      });
      await partial.rename(package.path);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const WindowsDownloadCanceled();
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  Future<bool> verify(AvailableUpdate update) async {
    try {
      final file = await _package(update);
      if (!await file.exists() || await file.length() != update.size) {
        return false;
      }
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString() == update.sha256;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<void> release() async {
    final mutex = _mutex;
    _mutex = null;
    await mutex?.close();
  }

  @override
  Future<String?> prepare(InstalledApp installed, AvailableUpdate update) async {
    const busy =
        'Обновление уже устанавливается. Дождитесь перезапуска LocalTube.';
    final directory = await _directory();
    if (_mutex == null) {
      final handle = await _lockDirectory(directory);
      if (handle == null) return busy;
      if (await _applying(directory)) {
        await handle.close();
        return busy;
      }
      _mutex = handle;
    }
    try {
      final reason = await _stage(directory, installed, update);
      if (reason != null) await release();
      return reason;
    } catch (_) {
      await release();
      rethrow;
    }
  }

  Future<String?> _stage(Directory directory, InstalledApp installed,
      AvailableUpdate update) async {
    final staging = Directory(_path(directory, 'staging'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    // tar.exe (bsdtar, Windows 10 1803+) refuses absolute and ".." paths.
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final tar = '$systemRoot\\System32\\tar.exe';
    final result = await Process.run(
        tar, ['-xf', (await _package(update)).path, '-C', staging.path]);
    if (result.exitCode != 0) {
      return 'Не удалось распаковать обновление. Повторите установку.';
    }
    try {
      final identity = jsonDecode(
          await File(_path(staging, 'localtube-update.json')).readAsString());
      if (identity is! Map<String, dynamic> ||
          identity['schemaVersion'] != 1 ||
          identity['channel'] != installed.channel ||
          identity['applicationId'] != installed.applicationId ||
          identity['versionCode'] != update.versionCode ||
          identity['versionName'] != update.versionName) {
        return 'Пакет обновления не соответствует ожидаемой версии. Повторите скачивание.';
      }
    } on FileSystemException {
      return 'В пакете обновления нет сведений о версии. Повторите скачивание.';
    } on FormatException {
      return 'В пакете обновления нет сведений о версии. Повторите скачивание.';
    }
    for (final name in [_executableName, 'flutter_windows.dll', 'data']) {
      if (await FileSystemEntity.type(_path(staging, name)) ==
          FileSystemEntityType.notFound) {
        return 'Пакет обновления неполный. Повторите скачивание.';
      }
    }
    final probe = File(_path(_application, '.localtube-update-check'));
    try {
      await probe.writeAsString('check', flush: true);
      await probe.delete();
    } on FileSystemException {
      return 'Нет прав на запись в папку LocalTube (${_application.path}). '
          'Переместите приложение в папку пользователя или обновите вручную.';
    }
    return null;
  }

  @override
  Future<void> launchApplier(AvailableUpdate update) async {
    final directory = await _directory();
    final script = File(_path(directory, 'apply-update.ps1'));
    await script.writeAsString(windowsApplyUpdateScript, flush: true);
    if (_mutex == null) throw StateError('Update was not prepared');
    final marker = File(_path(directory, 'applying.lock'));
    await marker.writeAsString('$pid', flush: true);
    try {
      await launchWindowsApplier(script.path, <String, String>{
        'ProcessId': '$pid',
        'Source': _path(directory, 'staging'),
        'Target': _application.path,
        'Backup': _path(directory, 'backup'),
        'Result': _path(directory, 'apply-result.json'),
        'Lock': marker.path,
        'MutexPath': _path(directory, 'updater.lock'),
        'Executable': Platform.resolvedExecutable,
        'VersionCode': '${update.versionCode}',
      });
      // The OS lock stays held until this process exits; the applier then
      // takes it over and removes the marker after writing its result.
    } catch (_) {
      await marker.delete();
      await release();
      rethrow;
    }
  }

  @override
  Future<void> exitApplication() async {
    await ServicesBinding.instance.exitApplication(AppExitType.required);
    exit(0);
  }
}

/// Copies the unpacked bundle over the installation after LocalTube exits.
/// Files are only added or replaced, never deleted, so data a user keeps next
/// to the executable survives. Any failure restores the replaced files and
/// removes the added ones; LocalTube is restarted in both cases.
const String windowsApplyUpdateScript = r'''
param(
  [Parameter(Mandatory = $true)][int]$ProcessId,
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Target,
  [Parameter(Mandatory = $true)][string]$Backup,
  [Parameter(Mandatory = $true)][string]$Result,
  [Parameter(Mandatory = $true)][string]$Lock,
  [Parameter(Mandatory = $true)][string]$MutexPath,
  [Parameter(Mandatory = $true)][string]$Executable,
  [Parameter(Mandatory = $true)][long]$VersionCode,
  [Parameter(Mandatory = $true)][string]$StartupSignal
)
$ErrorActionPreference = 'Stop'
[System.IO.File]::WriteAllText($StartupSignal, 'started')

function Write-Result([string]$Status, [string]$Reason) {
  $json = @{ schemaVersion = 1; status = $Status; versionCode = $VersionCode; reason = $Reason } |
    ConvertTo-Json -Compress
  [System.IO.File]::WriteAllText($Result, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Copy-WithRetry([string]$From, [string]$To) {
  for ($attempt = 1; ; $attempt++) {
    try {
      $directory = Split-Path -Parent $To
      if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
      }
      Copy-Item -LiteralPath $From -Destination $To -Force
      return
    } catch {
      # Antivirus scanners or a slow exit can hold files briefly.
      if ($attempt -ge 20) { throw }
      Start-Sleep -Milliseconds 500
    }
  }
}

$replaced = New-Object System.Collections.Generic.List[string]
$created = New-Object System.Collections.Generic.List[string]
$held = $null
try {
  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($process -and -not $process.WaitForExit(120000)) {
    throw 'LocalTube did not exit in time'
  }
  # Exclusive open: no LocalTube process can lock the update directory now.
  for ($attempt = 1; -not $held; $attempt++) {
    try {
      $held = [System.IO.File]::Open($MutexPath, 'OpenOrCreate', 'ReadWrite', 'None')
    } catch {
      if ($attempt -ge 240) { throw 'Update directory is busy' }
      Start-Sleep -Milliseconds 500
    }
  }
  if (Test-Path -LiteralPath $Backup) { Remove-Item -LiteralPath $Backup -Recurse -Force }
  New-Item -ItemType Directory -Path $Backup -Force | Out-Null
  $root = (Resolve-Path -LiteralPath $Source).ProviderPath.TrimEnd('\') + '\'
  foreach ($file in Get-ChildItem -LiteralPath $Source -Recurse -File) {
    $relative = $file.FullName.Substring($root.Length)
    $destination = Join-Path $Target $relative
    if (Test-Path -LiteralPath $destination) {
      Copy-WithRetry $destination (Join-Path $Backup $relative)
      $replaced.Add($relative)
    } else {
      $created.Add($destination)
    }
    Copy-WithRetry $file.FullName $destination
  }
  Write-Result 'applied' ''
} catch {
  $reason = $_.Exception.Message
  foreach ($relative in $replaced) {
    try { Copy-WithRetry (Join-Path $Backup $relative) (Join-Path $Target $relative) } catch { }
  }
  foreach ($path in $created) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
  try { Write-Result 'failed' $reason } catch { }
}
# The marker goes only while the directory is still held and the result exists.
if ($held) {
  Remove-Item -LiteralPath $Lock -Force -ErrorAction SilentlyContinue
  $held.Dispose()
}
Start-Process -FilePath $Executable -WorkingDirectory $Target
''';
