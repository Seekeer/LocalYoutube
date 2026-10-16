import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/router/auth_notifier.dart';
import '../../../core/errors/failure.dart';
import '../../../core/network/network_status.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../app_updates/app_updates.dart';
import '../../catalog/presentation/catalog_controller.dart';
import '../../downloads/data/offline_history_repository.dart';
import '../../downloads/domain/download_models.dart';
import '../../downloads/domain/download_service.dart';
import '../../player/presentation/player_navigation_result.dart';

class StartPage extends ConsumerStatefulWidget {
  const StartPage({super.key});

  @override
  ConsumerState<StartPage> createState() => _StartPageState();
}

class _StartPageState extends ConsumerState<StartPage> {
  static const double _buttonWidth = 500;
  static const double _buttonMarginVertical = 10;
  static const double _buttonFontSize = 50;
  static const List<Color> _buttonPalette = <Color>[
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFF4511E),
    Color(0xFF5E35B1),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFF546E7A),
    Color(0xFF6D4C41),
  ];

  static const String _titleMainMenu =
      '\u0413\u043b\u0430\u0432\u043d\u043e\u0435 \u043c\u0435\u043d\u044e';
  static const String _labelDownloaded =
      '\u0421\u043a\u0430\u0447\u0430\u043d\u043d\u043e\u0435';
  static const String _labelFresh =
      '\u041d\u043e\u0432\u0438\u043d\u043a\u0438';
  static const String _labelContinue =
      '\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c';
  static const String _labelHistory =
      '\u0418\u0441\u0442\u043e\u0440\u0438\u044f';
  static const String _labelSeries = '\u0421\u0435\u0440\u0438\u0438';
  static const String _labelAutonomous =
      '\u0410\u0432\u0442\u043e\u043d\u043e\u043c\u043d\u043e';
  /// Deliberately the product's own word: Receiver Mode is set behind this entry.
  static const String _labelCast = 'Cast';
  static const String _labelDownloading =
      '\u0421\u043a\u0430\u0447\u0438\u0432\u0430\u0435\u043c\u043e\u0435';
  static const String _labelLogs =
      '\u041f\u043e\u043a\u0430\u0437\u0430\u0442\u044c \u043b\u043e\u0433\u0438';
  static const String _labelLogout =
      '\u0420\u0430\u0437\u043b\u043e\u0433\u0438\u043d\u0438\u0442\u044c\u0441\u044f';
  static const String _internetOff =
      '\u0418\u043d\u0442\u0435\u0440\u043d\u0435\u0442 \u0432\u044b\u043a\u043b\u044e\u0447\u0435\u043d';
  static const String _availableAfterReconnect = 'Available after reconnect';
  static const String _noVideosAvailable =
      '\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u043d\u044b\u0445 \u0432\u0438\u0434\u0435\u043e';

  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthNotifier>(
      authNotifierProvider,
      (_, AuthNotifier notifier) => _showPendingAccessNotice(notifier),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authNotifierProvider);
    final NetworkStatus? networkStatus = ref.watch(networkStatusProvider).value;
    final bool internetEnabled = networkStatus != NetworkStatus.offline;
    final bool useOfflineActions = ref.watch(effectiveAutonomousModeProvider);
    final bool canUseOnlineActions = !useOfflineActions;
    final AppUpdateState updateState = ref.watch(appUpdateControllerProvider);
    final bool promoteUpdateMenu = updateState.status == UpdateStatus.available &&
        updateState.available != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(_titleMainMenu),
        actions: <Widget>[
          IconButton(
            key: const Key('cast-settings-button'),
            onPressed: () => context.push(AppRoutes.cast),
            icon: const Icon(Icons.cast),
            tooltip: _labelCast,
          ),
          const Center(child: Text(_labelAutonomous)),
          Switch(
            key: const Key('autonomous-mode-switch'),
            value: useOfflineActions,
            onChanged: internetEnabled
                ? (bool value) {
                    ref.read(manualAutonomousModeProvider.notifier).state =
                        value;
                  }
                : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth < _buttonWidth
              ? constraints.maxWidth
              : _buttonWidth;
          return SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      if (_isBusy)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: CircularProgressIndicator(),
                        ),
                      if (!internetEnabled)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: StateFeedbackBanner(
                            message: _internetOff,
                            tone: StateFeedbackTone.warning,
                          ),
                        ),
                      if (promoteUpdateMenu) const AppUpdatesMenu(),
                      _buildMenuButton(
                        label: _labelDownloaded,
                        width: width,
                        backgroundColor: _buttonPalette[0],
                        onPressed: _isBusy ? null : _openDownloaded,
                      ),
                      if (canUseOnlineActions)
                        _buildMenuButton(
                          label: _labelFresh,
                          width: width,
                          backgroundColor: _buttonPalette[1],
                          onPressed: (!canUseOnlineActions || _isBusy)
                              ? null
                              : _openFresh,
                          disabledHint: _availableAfterReconnect,
                        ),
                      _buildMenuButton(
                        label: _labelContinue,
                        width: width,
                        backgroundColor: _buttonPalette[2],
                        onPressed: _isBusy
                            ? null
                            : () => _openLatestVideo(
                                  useOfflinePlayback: useOfflineActions,
                                ),
                      ),
                      _buildMenuButton(
                        label: _labelHistory,
                        width: width,
                        backgroundColor: _buttonPalette[3],
                        onPressed: _isBusy
                            ? null
                            : useOfflineActions
                                ? _openOfflineHistory
                                : _openHistory,
                      ),
                      if (canUseOnlineActions)
                        _buildMenuButton(
                          label: _labelSeries,
                          width: width,
                          backgroundColor: _buttonPalette[4],
                          onPressed: (!canUseOnlineActions || _isBusy)
                              ? null
                              : _openSeries,
                          disabledHint: _availableAfterReconnect,
                        ),
                      _buildMenuButton(
                        label: _labelDownloading,
                        width: width,
                        backgroundColor: _buttonPalette[5],
                        onPressed: (!canUseOnlineActions || _isBusy)
                            ? null
                            : _openDownloading,
                        disabledHint: _availableAfterReconnect,
                      ),
                      _buildMenuButton(
                        label: _labelLogs,
                        width: width,
                        backgroundColor: _buttonPalette[6],
                        onPressed: _isBusy ? null : _openLogs,
                      ),
                      _buildMenuButton(
                        label: _labelLogout,
                        width: width,
                        backgroundColor: _buttonPalette[7],
                        onPressed: _isBusy ? null : _logout,
                      ),
                      if (!promoteUpdateMenu) const AppUpdatesMenu(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPendingAccessNotice(AuthNotifier notifier) {
    final String? notice = notifier.consumePendingAccessNotice();
    if (notice == null || notice.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notice)),
      );
    });
  }

  Widget _buildMenuButton({
    required String label,
    required double width,
    required Color backgroundColor,
    required VoidCallback? onPressed,
    String? disabledHint,
  }) {
    final Widget button = Padding(
      padding: const EdgeInsets.symmetric(vertical: _buttonMarginVertical),
      child: SizedBox(
        width: width,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            disabledBackgroundColor: backgroundColor.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            textStyle: const TextStyle(
              fontSize: _buttonFontSize,
              height: 1.1,
            ),
            foregroundColor: Colors.white,
          ),
          onPressed: onPressed,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
    if (onPressed != null || disabledHint == null || disabledHint.isEmpty) {
      return button;
    }
    return Tooltip(
      message: disabledHint,
      child: button,
    );
  }

  Future<void> _openDownloaded() async {
    if (!mounted) {
      return;
    }
    await context.push('${AppRoutes.downloads}?mode=downloaded');
  }

  Future<void> _openFresh() async {
    if (!mounted) {
      return;
    }
    await context.push('${AppRoutes.catalog}/${CatalogSection.fresh.key}');
  }

  Future<void> _openLatestVideo({required bool useOfflinePlayback}) async {
    await _runBusy(() async {
      if (useOfflinePlayback) {
        await _openLatestOfflineVideo();
        return;
      }

      await ref
          .read(catalogControllerProvider.notifier)
          .loadSection(CatalogSection.latest, forceRefresh: true);
      final CatalogState state = ref.read(catalogControllerProvider);
      if (!mounted) {
        return;
      }
      if (state.items.isEmpty) {
        final String message = state.error?.message ?? _noVideosAvailable;
        _showSnackBar(message);
        return;
      }
      final CatalogItem item = state.items.first;
      final String description = item.description.trim();
      final PlayerNavigationResult? result =
          await context.push<PlayerNavigationResult>(
        '${AppRoutes.player}/${item.id}',
        extra: <String, String>{
          'title': item.title,
          if (description.isNotEmpty) 'description': description,
        },
      );
      if (!mounted) {
        return;
      }
      showPlayerNavigationResultSnackBar(context, result);
    });
  }

  Future<void> _openLatestOfflineVideo() async {
    final OfflineHistoryItem? item =
        await ref.read(offlineHistoryRepositoryProvider).findLatestPlayable();
    if (!mounted) {
      return;
    }
    if (item == null) {
      _showSnackBar('No downloaded video available to continue.');
      return;
    }

    final PlayerNavigationResult? result =
        await context.push<PlayerNavigationResult>(
      '${AppRoutes.player}/${item.videoId}?position=${item.positionSeconds}',
      extra: <String, String>{
        'title': item.title,
        if (item.description.trim().isNotEmpty)
          'description': item.description.trim(),
      },
    );
    if (!mounted) {
      return;
    }
    showPlayerNavigationResultSnackBar(context, result);
  }

  Future<void> _openHistory() async {
    if (!mounted) {
      return;
    }
    await context.push('${AppRoutes.catalog}/${CatalogSection.history.key}');
  }

  Future<void> _openOfflineHistory() async {
    if (!mounted) {
      return;
    }
    await context.push(AppRoutes.offlineHistory);
  }

  Future<void> _openSeries() async {
    if (!mounted) {
      return;
    }
    await context.push('${AppRoutes.catalog}/${CatalogSection.series.key}');
  }

  Future<void> _openDownloading() async {
    if (!mounted) {
      return;
    }
    await context.push(AppRoutes.downloads);
  }

  Future<void> _openLogs() async {
    if (!mounted) {
      return;
    }
    await context.push(AppRoutes.logs);
  }

  Future<void> _logout() async {
    await _runBusy(() async {
      if (ref.read(authNotifierProvider).isOfflineFallback) {
        await ref.read(authRepositoryProvider).logoutOfflineFallback();
      } else {
        final DownloadService downloadService =
            ref.read(downloadServiceProvider);
        final List<DownloadItem> downloads =
            await ref.read(localDownloadsRepositoryProvider).listAll();
        for (final DownloadItem item in downloads) {
          await downloadService.deleteLocal(item.videoId);
        }

        final Failure? logoutFailure =
            await ref.read(logoutUseCaseProvider).call();
        if (!mounted) {
          return;
        }
        if (logoutFailure != null) {
          _showSnackBar(logoutFailure.message);
          return;
        }
      }
      if (!mounted) {
        return;
      }
      ref.read(authNotifierProvider).enterSignedOut();
      context.go(AppRoutes.login);
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        '\u041e\u0448\u0438\u0431\u043a\u0430: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
