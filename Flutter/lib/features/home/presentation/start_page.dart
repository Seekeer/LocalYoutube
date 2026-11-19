import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/router/auth_notifier.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/network/network_status.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../shared/widgets/autonomous_mode_card.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../../shared/widgets/resolved_thumbnail_image.dart';
import '../../../shared/widgets/video_list_item.dart';
import '../../../shared/widgets/watch_progress.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../app_updates/app_updates.dart';
import '../../app_updates/app_version_update_button.dart';
import '../../catalog/presentation/catalog_controller.dart';
import '../../catalog/data/local_video_metadata_repository.dart';
import '../../downloads/data/offline_history_repository.dart';
import '../../player/data/local_playback_repository.dart';
import '../../films/presentation/films_page.dart';
import '../../notes/data/notes_repository.dart';
import '../../player/presentation/player_navigation_result.dart';

class StartPage extends ConsumerStatefulWidget {
  const StartPage({super.key});

  @override
  ConsumerState<StartPage> createState() => _StartPageState();
}

class _StartPageState extends ConsumerState<StartPage> {
  /// Opens a screen; on the way back «Продолжить» and «Недавнее» are read
  /// again, since the person may have watched or deleted something there.
  Future<T?> _push<T extends Object?>(String location, {Object? extra}) async {
    final T? result = await context.push<T>(location, extra: extra);
    _refreshShelves();
    return result;
  }

  void _refreshShelves() {
    if (!mounted) {
      return;
    }
    ref.invalidate(continueCandidateProvider);
    ref.invalidate(recentStripProvider);
  }

  /// Wide windows (tablets, Windows) keep the menu a readable column.
  static const double _maxContentWidth = 560;

  static const String _labelDownloaded =
      '\u0421\u043a\u0430\u0447\u0430\u043d\u043d\u043e\u0435';
  static const String _labelFresh =
      '\u041d\u043e\u0432\u0438\u043d\u043a\u0438';
  static const String _labelContinue =
      '\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c';
  static const String _labelHistory =
      '\u0418\u0441\u0442\u043e\u0440\u0438\u044f';
  static const String _labelSeries = 'Сериалы';
  static const String _labelFilms = '\u0424\u0438\u043b\u044c\u043c\u044b';
  static const String _labelNotes =
      '\u0417\u0430\u043c\u0435\u0442\u043a\u0438';

  /// Deliberately the product's own word: Receiver Mode is set behind this entry.
  static const String _labelCast = 'Cast';
  static const String _labelSettings = 'Настройки';
  static const String _labelSettingsWithUpdate =
      'Настройки · доступно обновление';
  static const String _labelDownloading = 'Загрузки';
  static const String _internetOff =
      '\u0418\u043d\u0442\u0435\u0440\u043d\u0435\u0442 \u0432\u044b\u043a\u043b\u044e\u0447\u0435\u043d';
  static const String _availableAfterReconnect = 'Доступно после подключения';
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
    final bool updateNeedsAttention = ref.watch(appUpdateAttentionProvider);
    final int notesCount =
        ref.watch(notesShelfProvider).valueOrNull?.count ?? 0;
    final ContinueCandidate? candidate =
        ref.watch(continueCandidateProvider).valueOrNull;
    final List<ContinueCandidate> recent =
        ref.watch(recentStripProvider).valueOrNull ??
            const <ContinueCandidate>[];
    final LtPalette palette = LtPalette.of(context);
    final bool hasVersion =
        ref.watch(appUpdateControllerProvider).installed != null;

    final List<_StartTile> watchTiles = <_StartTile>[
      if (canUseOnlineActions)
        _StartTile(
          label: _labelFresh,
          hint: 'Свежее с сервера',
          icon: Icons.auto_awesome_rounded,
          tone: palette.sun,
          onPressed: _isBusy ? null : _openFresh,
        ),
      _StartTile(
        label: _labelHistory,
        hint: useOfflineActions ? 'Смотрели здесь' : 'Что смотрели',
        icon: Icons.history_rounded,
        tone: palette.cobalt,
        onPressed: _isBusy
            ? null
            : useOfflineActions
                ? _openOfflineHistory
                : _openHistory,
      ),
      if (canUseOnlineActions)
        _StartTile(
          label: _labelSeries,
          hint: 'По сезонам',
          icon: Icons.video_library_rounded,
          tone: palette.cobalt,
          onPressed: _isBusy ? null : _openSeries,
        ),
      if (canUseOnlineActions && filmsMenuAvailable)
        _StartTile(
          key: const Key('start-films-button'),
          label: _labelFilms,
          hint: 'Каталог фильмов',
          icon: Icons.movie_rounded,
          tone: palette.coral,
          onPressed: _isBusy ? null : _openFilms,
        ),
      _StartTile(
        key: const Key('start-notes-button'),
        label: _labelNotes,
        badgeCount: notesCount,
        hint: notesCount > 0 ? 'Ждут разбора' : 'Темы и отзывы',
        icon: Icons.edit_note_rounded,
        tone: palette.cobalt,
        onPressed: _isBusy ? null : _openNotes,
      ),
    ];
    final List<_StartTile> deviceTiles = <_StartTile>[
      _StartTile(
        label: _labelDownloaded,
        hint: 'Смотреть без сети',
        icon: Icons.download_done_rounded,
        tone: palette.mint,
        onPressed: _isBusy ? null : _openDownloaded,
      ),
      _StartTile(
        label: _labelDownloading,
        hint: canUseOnlineActions ? 'Очередь' : _availableAfterReconnect,
        icon: Icons.downloading_rounded,
        tone: palette.mint,
        onPressed: (!canUseOnlineActions || _isBusy) ? null : _openDownloading,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        // The mark stands for the brand; the top row itself belongs to the version and the
        // update check, as it did before.
        leadingWidth: 60,
        leading: const Padding(
          padding: EdgeInsets.only(left: LtSizes.gutter),
          child: Align(
            alignment: Alignment.centerLeft,
            child: LtLogoMark(size: 30),
          ),
        ),
        titleSpacing: 8,
        // A build without a known version has no update button to show, so
        // the brand's name takes the place.
        title: hasVersion
            ? AppVersionUpdateButton(
                onOpenSettings: () => _push(AppRoutes.settings),
              )
            : Text(
                'LocalTube',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
        actions: <Widget>[
          IconButton(
            key: const Key('cast-settings-button'),
            onPressed: () => _push(AppRoutes.cast),
            icon: const Icon(Icons.cast_rounded),
            tooltip: _labelCast,
          ),
          IconButton(
            key: const Key('settings-button'),
            onPressed: () => _push(AppRoutes.settings),
            icon: Badge(
              isLabelVisible: updateNeedsAttention,
              child: const Icon(Icons.settings_outlined),
            ),
            tooltip: updateNeedsAttention
                ? _labelSettingsWithUpdate
                : _labelSettings,
          ),
          const SizedBox(width: 4),
        ],
        bottom: _isBusy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  LtSizes.gutter,
                  4,
                  LtSizes.gutter,
                  0,
                ),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (!internetEnabled)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: StateFeedbackBanner(
                            message: _internetOff,
                            tone: StateFeedbackTone.warning,
                          ),
                        ),
                      const Spacer(),
                      _ContinueCard(
                        label: _labelContinue,
                        candidate: candidate,
                        apiBaseUrl: ref.read(appConfigProvider).apiBaseUrl,
                        allowNetworkThumbnail: canUseOnlineActions,
                        onPressed: _isBusy
                            ? null
                            : () => _openLatestVideo(
                                  useOfflinePlayback: useOfflineActions,
                                ),
                      ),
                      const SizedBox(height: 12),
                      const AutonomousModeCard(),
                      if (recent.isNotEmpty) ...<Widget>[
                        LtSectionHeader(
                          'Недавнее',
                          // The 48 dp tap area overhangs the header line so
                          // it keeps the other headers' spacing.
                          trailing: SizedBox(
                            width: 72,
                            height: 24,
                            child: OverflowBox(
                              maxHeight: 48,
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                key: const Key('start-recent-all'),
                                onPressed: () => _push(
                                  '${AppRoutes.catalog}/${CatalogSection.latest.key}',
                                ),
                                // The text ends on the cards' edge; the tap
                                // area still is 48 dp.
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(left: 16),
                                  minimumSize: const Size(48, 48),
                                  alignment: Alignment.centerRight,
                                ),
                                child: const Text('Все'),
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
                        ),
                        _RecentStrip(
                          items: recent,
                          onReturn: _refreshShelves,
                          apiBaseUrl: ref.read(appConfigProvider).apiBaseUrl,
                          allowNetworkThumbnail: canUseOnlineActions,
                        ),
                      ],
                      const LtSectionHeader(
                        'Библиотека',
                        padding: EdgeInsets.fromLTRB(0, 12, 0, 10),
                      ),
                      _TileGrid(tiles: watchTiles),
                      const LtSectionHeader('На телефоне'),
                      _TileGrid(tiles: deviceTiles),
                      SizedBox(
                        height: MediaQuery.viewPaddingOf(context).bottom + 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _openDownloaded() async {
    if (!mounted) {
      return;
    }
    await _push('${AppRoutes.downloads}?mode=downloaded');
  }

  Future<void> _openFresh() async {
    if (!mounted) {
      return;
    }
    await _push('${AppRoutes.catalog}/${CatalogSection.fresh.key}');
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
          await _push<PlayerNavigationResult>(
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
      _showSnackBar('Нет скачанного видео, которое можно продолжить.');
      return;
    }

    final PlayerNavigationResult? result = await _push<PlayerNavigationResult>(
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
    await _push('${AppRoutes.catalog}/${CatalogSection.history.key}');
  }

  Future<void> _openOfflineHistory() async {
    if (!mounted) {
      return;
    }
    await _push(AppRoutes.offlineHistory);
  }

  Future<void> _openSeries() async {
    if (!mounted) {
      return;
    }
    await _push('${AppRoutes.catalog}/${CatalogSection.series.key}');
  }

  Future<void> _openNotes() async {
    if (!mounted) {
      return;
    }
    await _push(AppRoutes.notes);
  }

  Future<void> _openFilms() async {
    if (!mounted) {
      return;
    }
    await _push(AppRoutes.films);
  }

  Future<void> _openDownloading() async {
    if (!mounted) {
      return;
    }
    await _push(AppRoutes.downloads);
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

/// The video «Продолжить» would open, shown on the card before it is tapped.
class ContinueCandidate {
  const ContinueCandidate({
    required this.videoId,
    required this.title,
    this.thumbnailLocalPath,
    this.positionSeconds = 0,
    this.durationSeconds,
  });

  final int videoId;
  final String title;
  final String? thumbnailLocalPath;
  final double positionSeconds;
  final int? durationSeconds;

  /// How much is left, as «Осталось 32 мин», or null when it is not known.
  String? get remainingLabel {
    final int? duration = durationSeconds;
    if (duration == null || duration <= 0) {
      return null;
    }
    final int left = (duration - positionSeconds).round();
    if (left <= 0) {
      return 'Просмотрено';
    }
    final int minutes = (left / 60).ceil();
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int rest = minutes % 60;
      return rest == 0 ? 'Осталось $hours ч' : 'Осталось $hours ч $rest мин';
    }
    return 'Осталось $minutes мин';
  }

  double? get watchedFraction {
    final int? duration = durationSeconds;
    if (duration == null || duration <= 0 || positionSeconds <= 0) {
      return null;
    }
    return (positionSeconds / duration).clamp(0.0, 1.0).toDouble();
  }
}

/// What «Продолжить» points at, read from what the phone already has: the
/// last downloaded video watched here in autonomous mode, otherwise the top of
/// the cached «Последние» list. Null until something is known; the card then
/// shows its plain form and the tap still finds the video.
final AutoDisposeFutureProvider<ContinueCandidate?> continueCandidateProvider =
    FutureProvider.autoDispose<ContinueCandidate?>((Ref ref) async {
  final bool offline = ref.watch(effectiveAutonomousModeProvider);
  try {
    if (offline) {
      final OfflineHistoryItem? item =
          await ref.read(offlineHistoryRepositoryProvider).findLatestPlayable();
      if (item == null) {
        return null;
      }
      return ContinueCandidate(
        videoId: item.videoId,
        title: item.title,
        thumbnailLocalPath: item.thumbnailLocalPath,
        positionSeconds: item.positionSeconds,
        durationSeconds: item.durationSeconds,
      );
    }
    final List<CatalogItem> items = await ref
        .read(catalogRepositoryProvider)
        .readCachedSection(CatalogSection.latest);
    if (items.isEmpty) {
      return null;
    }
    final CatalogItem item = items.first;
    final LocalVideoMetadata? metadata = await ref
        .read(localVideoMetadataRepositoryProvider)
        .findByVideoId(item.id);
    double position = 0;
    for (final PlaybackPositionSnapshot snapshot in await ref
        .read(localPlaybackRepositoryProvider)
        .listRecent(limit: 20)) {
      if (snapshot.videoId == item.id) {
        position = snapshot.positionSeconds;
        break;
      }
    }
    return ContinueCandidate(
      videoId: item.id,
      title: item.title,
      thumbnailLocalPath: metadata?.thumbnailLocalPath,
      positionSeconds: position,
      durationSeconds: metadata?.durationSeconds,
    );
  } catch (_) {
    return null;
  }
});

/// The first thing on the main screen: back to the video that was playing,
/// with its cover, its title and how much is left.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.label,
    required this.candidate,
    required this.apiBaseUrl,
    required this.allowNetworkThumbnail,
    required this.onPressed,
  });

  final String label;
  final ContinueCandidate? candidate;
  final String apiBaseUrl;
  final bool allowNetworkThumbnail;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color background = dark ? const Color(0xFF2A39B0) : LtColors.primary;
    final ContinueCandidate? item = candidate;
    final double? watched = item?.watchedFraction;
    final String? remaining = item?.remainingLabel;

    return Opacity(
      opacity: onPressed == null ? 0.6 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(LtSizes.radiusL),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('start-continue-card'),
          onTap: onPressed,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Row(
                  children: <Widget>[
                    if (item == null)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 36,
                          color: background,
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 144,
                          height: 81,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              ResolvedThumbnailImage(
                                width: 144,
                                height: 81,
                                localPath: item.thumbnailLocalPath,
                                networkUrl: Uri.parse(apiBaseUrl)
                                    .resolve(
                                      '/api/files/getImage?fileId=${item.videoId}&isMobile=true',
                                    )
                                    .toString(),
                                allowNetworkFallback: allowNetworkThumbnail,
                              ),
                              if (Theme.of(context).brightness ==
                                  Brightness.dark)
                                const ColoredBox(color: Color(0x24000000)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            label,
                            style: (item == null
                                    ? text.titleLarge
                                    : text.labelLarge)
                                ?.copyWith(
                              color: item == null
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item?.title ?? 'С того места, где остановились',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: (item == null
                                    ? text.bodyMedium
                                    : text.titleMedium)
                                ?.copyWith(
                              color: item == null
                                  ? Colors.white.withValues(alpha: 0.82)
                                  : Colors.white,
                              fontWeight: item == null ? null : FontWeight.w700,
                            ),
                          ),
                          if (remaining != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              remaining,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (watched != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 4,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.2),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: watched,
                      child: const ColoredBox(color: LtColors.coral),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartTile {
  const _StartTile({
    this.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.tone,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final Key? key;
  final int badgeCount;
  final String label;
  final String hint;
  final IconData icon;
  final LtTone tone;
  final VoidCallback? onPressed;
}

/// Section tiles two to a row, icon beside the name: big enough to hit with a
/// thumb, low enough that the whole menu fits on one screen.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<_StartTile> tiles;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: _TileView(tile: tiles[i])),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < tiles.length
                    ? _TileView(tile: tiles[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
      if (i + 2 < tiles.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(children: rows);
  }
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile});

  final _StartTile tile;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool enabled = tile.onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Card(
        child: InkWell(
          key: tile.key,
          onTap: tile.onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
            child: Row(
              children: <Widget>[
                Badge(
                  backgroundColor: LtColors.primary,
                  isLabelVisible: tile.badgeCount > 0,
                  label: Text('${tile.badgeCount}'),
                  offset: const Offset(6, -6),
                  child: LtToneIcon(icon: tile.icon, tone: tile.tone, size: 42),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        tile.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      Text(
                        tile.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The videos after the one «Продолжить» points at: the rest of the cached
/// «Последние» list, or of this phone's history in autonomous mode.
final AutoDisposeFutureProvider<List<ContinueCandidate>> recentStripProvider =
    FutureProvider.autoDispose<List<ContinueCandidate>>((Ref ref) async {
  final bool offline = ref.watch(effectiveAutonomousModeProvider);
  try {
    if (offline) {
      final List<OfflineHistoryItem> items =
          await ref.read(offlineHistoryRepositoryProvider).listHistory();
      return <ContinueCandidate>[
        for (final OfflineHistoryItem item in items.skip(1).take(8))
          if (item.isPlayableOffline)
            ContinueCandidate(
              videoId: item.videoId,
              title: item.title,
              thumbnailLocalPath: item.thumbnailLocalPath,
              positionSeconds: item.positionSeconds,
              durationSeconds: item.durationSeconds,
            ),
      ];
    }
    final List<CatalogItem> items = await ref
        .read(catalogRepositoryProvider)
        .readCachedSection(CatalogSection.latest);
    final Map<int, double> positions = <int, double>{
      for (final PlaybackPositionSnapshot s in await ref
          .read(localPlaybackRepositoryProvider)
          .listRecent(limit: 200))
        s.videoId: s.positionSeconds,
    };
    final List<ContinueCandidate> result = <ContinueCandidate>[];
    for (final CatalogItem item in items.skip(1).take(8)) {
      final LocalVideoMetadata? metadata = await ref
          .read(localVideoMetadataRepositoryProvider)
          .findByVideoId(item.id);
      result.add(
        ContinueCandidate(
          videoId: item.id,
          title: item.title,
          thumbnailLocalPath: metadata?.thumbnailLocalPath,
          positionSeconds: positions[item.id] ?? 0,
          durationSeconds: metadata?.durationSeconds,
        ),
      );
    }
    return result;
  } catch (_) {
    return const <ContinueCandidate>[];
  }
});

/// «Недавнее»: a row of covers to swipe through, between «Продолжить» and the
/// sections.
class _RecentStrip extends StatelessWidget {
  /// Called after the player opened from the strip closes.
  final VoidCallback onReturn;

  const _RecentStrip({
    required this.onReturn,
    required this.items,
    required this.apiBaseUrl,
    required this.allowNetworkThumbnail,
  });

  final List<ContinueCandidate> items;
  final String apiBaseUrl;
  final bool allowNetworkThumbnail;

  static const double _width = 172;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox(
      height: _width * 9 / 16 + 6 + MediaQuery.textScalerOf(context).scale(44),
      child: ListView.separated(
        key: const Key('start-recent-strip'),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final ContinueCandidate item = items[index];
          return SizedBox(
            width: _width,
            child: InkWell(
              borderRadius: BorderRadius.circular(LtSizes.radiusM),
              onTap: () => unawaited(
                context.push<Object?>(
                  '${AppRoutes.player}/${item.videoId}',
                  extra: <String, String>{'title': item.title},
                ).then((_) => onReturn()),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  VideoCover(
                    width: _width,
                    localImagePath: item.thumbnailLocalPath,
                    imageUrl: Uri.parse(apiBaseUrl)
                        .resolve(
                          '/api/files/getImage?fileId=${item.videoId}&isMobile=true',
                        )
                        .toString(),
                    allowNetworkFallback: allowNetworkThumbnail,
                    watchedFraction: item.watchedFraction,
                    isDownloaded: false,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (watchProgressLabel(
                    item.watchedFraction,
                    item.durationSeconds == null
                        ? null
                        : Duration(seconds: item.durationSeconds!),
                  )
                      case final String state)
                    Text(
                      state,
                      maxLines: 1,
                      style: text.labelMedium?.copyWith(
                        color: watchProgressColor(
                          context,
                          item.watchedFraction,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
