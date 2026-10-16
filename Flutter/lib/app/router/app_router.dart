import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/cast/presentation/cast_settings_page.dart';
import '../../features/catalog/domain/catalog_models.dart';
import '../../features/downloads/presentation/downloads_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/home/presentation/offline_history_page.dart';
import '../../features/home/presentation/start_page.dart';
import '../../features/logs/presentation/logs_page.dart';
import '../../features/player/presentation/player_page.dart';
import 'app_routes.dart';
import 'auth_notifier.dart';

GoRouter buildAppRouter({
  required AuthNotifier authNotifier,
}) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    redirect: (_, GoRouterState state) {
      final bool isSplashRoute = state.matchedLocation == AppRoutes.splash;
      final bool isLoginRoute = state.matchedLocation == AppRoutes.login;
      switch (authNotifier.accessMode) {
        case AppAccessMode.checkingSession:
          return isSplashRoute ? null : AppRoutes.splash;
        case AppAccessMode.signedOut:
          return isLoginRoute ? null : AppRoutes.login;
        case AppAccessMode.onlineAuthenticated:
        case AppAccessMode.offlineFallback:
          return (isSplashRoute || isLoginRoute) ? AppRoutes.home : null;
      }
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const _LaunchPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => LoginPage(authNotifier: authNotifier),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const StartPage(),
      ),
      GoRoute(
        path: '${AppRoutes.catalog}/:section',
        builder: (_, GoRouterState state) => HomePage(
          initialSection: parseCatalogSection(
            state.pathParameters['section'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.offlineHistory,
        builder: (_, __) => const OfflineHistoryPage(),
      ),
      GoRoute(
        path: '${AppRoutes.player}/:videoId',
        builder: (_, GoRouterState state) {
          String? title;
          String? description;
          final double? initialPositionSeconds = double.tryParse(
            state.uri.queryParameters['position'] ?? '',
          );
          final Object? extra = state.extra;
          if (extra is Map) {
            title = extra['title']?.toString();
            description = extra['description']?.toString();
          }
          return PlayerPage(
            videoId: state.pathParameters['videoId'] ?? '',
            videoTitle: title,
            videoDescription: description,
            initialPositionSeconds: initialPositionSeconds,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.downloads,
        builder: (_, GoRouterState state) {
          final bool showCompletedOnly =
              state.uri.queryParameters['mode'] == 'downloaded';
          return DownloadsPage(showCompletedOnly: showCompletedOnly);
        },
      ),
      GoRoute(
        path: AppRoutes.logs,
        builder: (_, __) => const LogsPage(),
      ),
      GoRoute(
        path: AppRoutes.cast,
        builder: (_, __) => const CastSettingsPage(),
      ),
    ],
  );
}

class _LaunchPage extends StatelessWidget {
  const _LaunchPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
