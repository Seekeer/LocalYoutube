import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

class LocalTubeApp extends ConsumerWidget {
  const LocalTubeApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LocalTube',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      builder: (BuildContext context, Widget? child) {
        // Transparent status and navigation bars: the app draws edge to edge, under the
        // punch-hole camera and the gesture handle, and every screen pads for them itself.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyleFor(Theme.of(context).brightness),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
