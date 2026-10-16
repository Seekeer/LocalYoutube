import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'app/bootstrap/bootstrap_providers.dart';
import 'core/config/server_connection.dart';
import 'core/storage/secure_storage_service.dart';
import 'features/server_connection/presentation/server_connection_page.dart';
import 'app/cast/cast_receiver_player_host.dart';
import 'app/sync/app_sync_lifecycle_listener.dart';
import 'core/config/app_config.dart';
import 'core/crash/crash_reporter.dart';
import 'features/player/presentation/lock_screen_playback_service.dart';
import 'features/app_updates/app_updates.dart';

Future<void> main() async {
  await runLocalTubeApp();
}

Future<void> runLocalTubeApp({
  AppEnvironment? environmentOverride,
}) async {
  CrashReporter? crashReporter;

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await _initializeMediaControls();
      runApp(_ConfiguredApplication(
        environment: environmentOverride,
        onBootstrap: (bootstrap) {
          crashReporter = bootstrap.crashReporter;
          _installCrashHandlers(bootstrap.crashReporter);
        },
      ));
    },
    (Object error, StackTrace stackTrace) {
      final CrashReporter? reporter = crashReporter;
      if (reporter == null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            context: ErrorDescription('runZonedGuarded in main'),
          ),
        );
        return;
      }

      unawaited(
        reporter.recordError(
          error,
          stackTrace,
          reason: 'runZonedGuarded in main',
          fatal: true,
        ),
      );
    },
  );
}

void _installCrashHandlers(CrashReporter crashReporter) {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    unawaited(crashReporter.recordFlutterError(details, fatal: true));
  };

  PlatformDispatcher.instance.onError = (
    Object error,
    StackTrace stackTrace,
  ) {
    unawaited(
      crashReporter.recordError(
        error,
        stackTrace,
        reason: 'PlatformDispatcher.onError',
        fatal: true,
      ),
    );
    return true;
  };
}

Future<void> _initializeMediaControls() async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return;
  }
  await LockScreenPlaybackService.instance.initialize();
}

class _ConfiguredApplication extends StatefulWidget {
  const _ConfiguredApplication(
      {required this.environment, required this.onBootstrap});
  final AppEnvironment? environment;
  final void Function(BootstrapResult) onBootstrap;
  @override
  State<_ConfiguredApplication> createState() => _ConfiguredApplicationState();
}

class _ConfiguredApplicationState extends State<_ConfiguredApplication> {
  final _storage = SecureStorageService();
  BootstrapResult? _bootstrap;
  ServerConnection? _connection;
  bool _loading = true;
  bool _editing = false;
  String? _error;
  late final AppConfig _base;

  @override
  void initState() {
    super.initState();
    _base = AppConfig.fromEnvironment(environmentOverride: widget.environment);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _connection = await ServerConnectionStore(_storage).load();
      const requiresConfiguration =
          bool.fromEnvironment('LOCALTUBE_REQUIRE_SERVER_CONFIG');
      if (_connection == null &&
          (requiresConfiguration ||
              _base.apiBaseUrl.contains('example.invalid'))) {
        setState(() {
          _loading = false;
          _editing = true;
        });
      } else {
        await _start();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось открыть настройки. Попробуйте ещё раз.';
        });
      }
    }
  }

  Future<void> _start() async {
    final connection = _connection;
    final bootstrap = await AppBootstrap.initialize(
      environmentOverride: widget.environment,
      configOverride: connection?.applyTo(_base),
      secureStorageOverride: _storage,
      databaseFileName:
          connection == null || connection.apiBaseUrl == _base.apiBaseUrl
              ? null
              : connection.databaseName,
    );
    widget.onBootstrap(bootstrap);
    if (mounted) {
      setState(() {
        _bootstrap = bootstrap;
        _loading = false;
        _editing = false;
        _error = null;
      });
    }
  }

  Future<void> _edit() async {
    // This action is exposed only on the signed-out login screen.
    final bootstrap = _bootstrap!;
    if (!await (bootstrap.canChangeServer?.call() ?? Future.value(true))) {
      throw const FormatException(
          'Перед сменой сервера завершите или отмените загрузки.');
    }
    if (!mounted) return;
    setState(() {
      _bootstrap = null;
      _loading = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    await bootstrap.shutdown?.call();
    if (mounted) {
      setState(() {
        _editing = true;
        _loading = false;
      });
    }
  }

  Future<void> _save(ServerConnection connection) async {
    await ServerConnectionStore(_storage).save(connection,
        previousApiBaseUrl: _connection?.apiBaseUrl ?? _base.apiBaseUrl);
    final previous = _bootstrap;
    // Unmount lifecycle listeners before shutting down their dependencies.
    setState(() {
      _bootstrap = null;
      _loading = true;
      _editing = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    await previous?.shutdown?.call();
    _connection = connection;
    try {
      await _start();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Не удалось запустить приложение. Повторите попытку.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return MaterialApp(
          title: 'LocalTube',
          theme: ThemeData(useMaterial3: true),
          home: ServerConnectionPage(
              initial: _connection ??
                  (_base.apiBaseUrl.contains('example.invalid')
                      ? null
                      : ServerConnection(
                          apiBaseUrl: _base.apiBaseUrl,
                          localApiHost: _base.enableLocalApiRoute
                              ? _base.localApiHost
                              : '',
                          localApiPort: _base.enableLocalApiRoute
                              ? _base.localApiPort
                              : 0)),
              onSave: _save));
    }
    if (_loading || _bootstrap == null) {
      return MaterialApp(
          home: Scaffold(
              body: Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!),
                          TextButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = null;
                                });
                                unawaited(_load());
                              },
                              child: const Text('Повторить'))
                        ]))));
    }
    final bootstrap = _bootstrap!;
    return ProviderScope(
        key: ObjectKey(bootstrap),
        overrides: [
          ...bootstrap.overrides,
          serverConnectionActionProvider.overrideWithValue(() async {
            try {
              await _edit();
            } on FormatException catch (error) {
              final context =
                  bootstrap.router.routerDelegate.navigatorKey.currentContext;
              if (context != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.message)));
              }
            }
          }),
        ],
        child: AppSyncLifecycleListener(
            child: AppUpdateLifecycleListener(
          child: CastReceiverPlayerHost(
              router: bootstrap.router,
              child: LocalTubeApp(router: bootstrap.router)),
        )));
  }
}
