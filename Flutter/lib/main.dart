import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/app_bootstrap.dart';
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
      final BootstrapResult bootstrap = await AppBootstrap.initialize(
        environmentOverride: environmentOverride,
      );
      crashReporter = bootstrap.crashReporter;
      _installCrashHandlers(bootstrap.crashReporter);
      Widget appChild = LocalTubeApp(router: bootstrap.router);

      // What makes this installation able to be a Receiver. It is not behind a setting: a device
      // offers itself as a Receiver through Receiver Mode, and a Handoff that reached an
      // installation which could not open a player would simply run out of time.
      appChild = CastReceiverPlayerHost(
        router: bootstrap.router,
        child: appChild,
      );

      appChild = AppUpdateLifecycleListener(child: appChild);

      runApp(
        ProviderScope(
          overrides: bootstrap.overrides,
          child: AppSyncLifecycleListener(
            child: appChild,
          ),
        ),
      );
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
