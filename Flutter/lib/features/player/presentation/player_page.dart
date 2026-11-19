import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../app_updates/apk_update_controller.dart';
import '../../../core/errors/failure.dart';
import '../../../core/network/network_status.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../bookmarks/domain/bookmark_models.dart';
import '../../cast/data/cast_playback_binding.dart';
import '../../cast/domain/cast_playback_endpoint.dart';
import '../../cast/presentation/cast_controller.dart';
import '../../cast/presentation/cast_entry_point.dart';
import '../../cast/presentation/remote_control_mode_view.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../downloads/domain/download_models.dart';
import '../domain/player_models.dart';
import '../domain/player_volume.dart';
import '../domain/usecases/jump_to_nearest_timestamp_use_case.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/presentation/mark_caption_dialog.dart';
import '../../notes/presentation/notes_section.dart';
import '../../notes/presentation/rating_dialog.dart';
import '../../transcript/presentation/transcript_panel.dart';
import 'player_chapter_bar.dart';
import 'player_controller.dart';
import 'player_keyboard_shortcuts.dart';
import 'player_navigation_result.dart';
import 'player_screen_stack.dart';
import 'player_stage_layout.dart';
import 'player_volume_control.dart';
import 'player_window_fullscreen.dart';

const MethodChannel _appControlChannel = MethodChannel(
  'org.localtube.app/app_control',
);

Future<void> _minimizeApp() async {
  try {
    await _appControlChannel.invokeMethod<void>('moveToBackground');
  } on MissingPluginException {
    await SystemNavigator.pop();
  }
}

/// The live video on the ordinary player page, for finding it in tests.
@visibleForTesting
const Key playerVideoSurfaceKey = Key('player-video-surface');

/// The space above and below the player page's content.
const double _pageVerticalPadding = 12;

/// The «Завершить просмотр» button, on the page and in fullscreen, for finding it in tests.
@visibleForTesting
const Key finishViewingButtonKey = Key('player-finish-viewing');

/// What fullscreen asks the page to do once it has closed, besides an ordinary close.
enum _FullscreenRequest {
  /// The viewer pressed «Завершить просмотр»: the Rating and delete dialogs belong to the page,
  /// and the page is what closes afterwards.
  finishViewing,
}

/// The chapters the server imported for the video; until they arrive, or when
/// they cannot (offline, an older server), the description's «00:00 Название»
/// lines by the server's rule.
List<VideoTimestamp> _chapters(
    WidgetRef ref, int videoId, String? description) {
  return ref.watch(videoChaptersProvider(videoId)).valueOrNull ??
      ref.read(extractTimestampsUseCaseProvider).call(description ?? '');
}

Future<void> _jumpToNearestTimestamp({
  required BuildContext context,
  required PlayerController controller,
  required Duration currentPosition,
  required List<VideoTimestamp> timestamps,
  required JumpToNearestTimestampUseCase jumpToNearestTimestampUseCase,
}) async {
  final VideoTimestamp? nearest = jumpToNearestTimestampUseCase.call(
    currentPosition: currentPosition,
    timestamps: timestamps,
  );
  if (nearest == null) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No next timestamp')));
    return;
  }
  await controller.seek(nearest.position);
}

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    super.key,
    required this.videoId,
    this.videoTitle,
    this.videoDescription,
    this.initialPositionSeconds,
  });

  final String videoId;
  final String? videoTitle;
  final String? videoDescription;
  final double? initialPositionSeconds;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver {
  UpdatePlaybackSurfaces? _updatePlaybackSurfaces;
  double? _dragSeconds;
  bool _downloadStartedForCurrentVideo = false;
  bool _isDeleteInProgress = false;
  bool _completionDialogShownForCurrentCompletion = false;
  bool _isDeleteDialogVisible = false;
  bool _isFullscreenOpen = false;
  bool _isFinishingViewing = false;

  /// Whether the phone layout has scrolled the controls out of sight.
  final ValueNotifier<bool> _controlsScrolledAway = ValueNotifier<bool>(false);

  /// The player's own keyboard focus: Space plays or pauses while it holds the focus, and Ctrl+F
  /// opens fullscreen from anywhere on the page.
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'Player keyboard');

  /// This page's local player, offered to the Cast Session while the page owns one. A Handoff reads
  /// the latest position through it and releases playback through it, without the Cast Controller
  /// ever having to know which screen is showing a video.
  CastPlaybackBinding? _castBinding;
  _PlayerCastLocalPlayer? _castLocalPlayer;

  /// This screen's place among the open player screens. Only the screen on top may play, so a
  /// player this screen left behind can never be heard from under another one.
  PlayerScreenStack? _screens;
  Object? _screenToken;

  int? get _resolvedVideoId => int.tryParse(widget.videoId);

  /// Whether playback has moved to a Receiver. In that mode this page owns no video player, so
  /// nothing here may read the player controller back - reading it would build one.
  bool get _isRemoteControlMode =>
      ref.read(castControllerProvider).isRemoteControlMode;

  @override
  void initState() {
    super.initState();
    final surfaces = ref.read(openUpdatePlaybackSurfacesProvider);
    surfaces.enter();
    _updatePlaybackSurfaces = surfaces;
    WidgetsBinding.instance.addObserver(this);

    final int? parsedVideoId = _resolvedVideoId;
    if (parsedVideoId != null && parsedVideoId > 0) {
      final int videoId = parsedVideoId;
      // Before anything builds this screen's player, so that player is on top from its start.
      final PlayerScreenStack screens = ref.read(playerScreenStackProvider);
      _screens = screens;
      _screenToken = screens.enter(videoId);
      final _PlayerCastLocalPlayer player = _PlayerCastLocalPlayer(
        readState: () => ref.read(playerControllerProvider(videoId)),
        readVolume: () => ref.read(playerVolumeProvider).value,
        pausePlayback: () =>
            ref.read(playerControllerProvider(videoId).notifier).pause(),
        resumePlayback: () =>
            ref.read(playerControllerProvider(videoId).notifier).play(),
        // A cast seek is not local navigation. The history of where the viewer jumped from belongs
        // to the person using this screen, and during a Cast Session that is not who is seeking.
        seekPlayback: (Duration position) => ref
            .read(playerControllerProvider(videoId).notifier)
            .seek(position, trackNavigation: false),
        setVolume: (double volume) => ref
            .read(playerControllerProvider(videoId).notifier)
            .setPlayerVolume(volume),
      );
      final CastPlaybackBinding binding = ref.read(castPlaybackBindingProvider);
      _castLocalPlayer = player;
      _castBinding = binding;
      // Offered only while this page actually owns a player. A page opened while playback already
      // lives on a Receiver owns none, and a player offered from there would be built by the very
      // first thing the Cast Session asked of it: readPlayback() and resume() both reach the player
      // controller, and reading an autoDispose provider is what constructs one. The ordinary
      // surface binds it in build() the moment the Cast Session ends, exactly as a page that cast
      // from here does.
      if (!_isRemoteControlMode) {
        binding.bind(player);
      }
      // The end-of-video choices should not wait for the video type.
      try {
        ref.read(notesRepositoryProvider).prefetchPostViewing(videoId);
      } catch (_) {
        // Without a network composition root (lightweight tests) there is
        // nothing to look up.
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_applyPreferredTitleIfNeeded());
      unawaited(_persistRouteMetadataIfNeeded());
      unawaited(_applyInitialPositionIfNeeded());
    });
  }

  @override
  void didUpdateWidget(covariant PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _downloadStartedForCurrentVideo = false;
      // The same screen now shows another video, so its place on the stack names that video.
      final Object? previousToken = _screenToken;
      final PlayerScreenStack screens =
          _screens ?? ref.read(playerScreenStackProvider);
      _screens = screens;
      final int? videoId = _resolvedVideoId;
      _screenToken =
          videoId != null && videoId > 0 ? screens.enter(videoId) : null;
      if (previousToken != null) {
        screens.leave(previousToken);
      }
    }
    if (oldWidget.videoTitle != widget.videoTitle) {
      unawaited(_applyPreferredTitleIfNeeded());
      unawaited(_persistRouteMetadataIfNeeded());
    }
    if (oldWidget.initialPositionSeconds != widget.initialPositionSeconds) {
      unawaited(_applyInitialPositionIfNeeded());
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _controlsScrolledAway.dispose();
    _updatePlaybackSurfaces?.leave();
    WidgetsBinding.instance.removeObserver(this);
    final Object? screenToken = _screenToken;
    if (screenToken != null) {
      _screens?.leave(screenToken);
    }
    final _PlayerCastLocalPlayer? player = _castLocalPlayer;
    if (player != null) {
      _castBinding?.unbind(player);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final int? videoId = _resolvedVideoId;
    if (videoId == null || _isRemoteControlMode) {
      return;
    }
    unawaited(
      ref
          .read(playerControllerProvider(videoId).notifier)
          .onLifecycleStateChanged(state),
    );
  }

  Future<void> _applyInitialPositionIfNeeded() async {
    final int? videoId = _resolvedVideoId;
    final double? rawSeconds = widget.initialPositionSeconds;
    if (videoId == null || rawSeconds == null || rawSeconds < 0) {
      return;
    }
    if (_isRemoteControlMode) {
      return;
    }
    final Duration position = Duration(
      milliseconds: (rawSeconds * 1000).round(),
    );
    await ref
        .read(playerControllerProvider(videoId).notifier)
        .applyExternalStartPosition(position);
  }

  Future<void> _applyPreferredTitleIfNeeded() async {
    final int? videoId = _resolvedVideoId;
    if (videoId == null || _isRemoteControlMode) {
      return;
    }
    await ref
        .read(playerControllerProvider(videoId).notifier)
        .setPreferredTitle(widget.videoTitle);
  }

  Future<void> _persistRouteMetadataIfNeeded() async {
    final int? videoId = _resolvedVideoId;
    if (videoId == null) {
      return;
    }
    await ref.read(localVideoMetadataRepositoryProvider).upsertRouteMetadata(
          videoId: videoId,
          title: widget.videoTitle,
          description: widget.videoDescription,
        );
  }

  @override
  Widget build(BuildContext context) {
    final int? videoId = _resolvedVideoId;
    if (videoId == null || videoId <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Плеер')),
        body: const Center(child: Text('Неверный номер видео')),
      );
    }

    // Remote Control Mode owns no local video player, so it is decided before the player
    // controller is ever touched: watching it here would build the very player this mode is
    // supposed to have given up.
    //
    // Returning here is also what makes the local-only affordances unreachable. Bookmarks,
    // downloads, deletion and the navigation history are all part of the surface below, so while
    // playback lives on the Receiver none of them is built at all - there is nothing to hide,
    // disable or guard one by one, and nothing that could be reached by a stale route.
    final CastUiState castState = ref.watch(castControllerProvider);
    if (castState.isRemoteControlMode) {
      return Scaffold(
        appBar: AppBar(title: Text(_resolvedTitle(videoId))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: RemoteControlModeView(
            // The timestamps come from the description this screen was opened with, and selecting
            // one is an absolute seek on the Receiver.
            timestamps: ref
                .read(extractTimestampsUseCaseProvider)
                .call(widget.videoDescription ?? ''),
          ),
        ),
      );
    }

    // The ordinary player surface is back, so this page offers its player to the Cast Session
    // again: a Handoff gave it up, and a viewer casting from here a second time must read a real
    // position rather than nothing at all. A player some other screen has since bound is left
    // alone, because it is the one actually on screen.
    final CastPlaybackBinding? binding = _castBinding;
    final _PlayerCastLocalPlayer? localPlayer = _castLocalPlayer;
    if (binding != null &&
        localPlayer != null &&
        binding.currentPlayer == null) {
      binding.bind(localPlayer);
    }

    final PlayerUiState state = ref.watch(playerControllerProvider(videoId));
    final PlayerController controller = ref.read(
      playerControllerProvider(videoId).notifier,
    );
    ref.listen<PlayerUiState>(playerControllerProvider(videoId), (
      PlayerUiState? previous,
      PlayerUiState next,
    ) {
      final bool wasCompleted = _isPlaybackCompleted(previous);
      final bool isCompleted = _isPlaybackCompleted(next);
      if (!isCompleted) {
        _completionDialogShownForCurrentCompletion = false;
        return;
      }
      if (wasCompleted ||
          _completionDialogShownForCurrentCompletion ||
          _isDeleteDialogVisible ||
          _isFullscreenOpen) {
        return;
      }
      _completionDialogShownForCurrentCompletion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isFullscreenOpen) {
          return;
        }
        unawaited(
          _onPlaybackCompleted(videoId: videoId, controller: controller),
        );
      });
    });
    final VideoPlayerController? videoController = controller.videoController;
    final List<VideoTimestamp> timestamps = _chapters(
      ref,
      videoId,
      widget.videoDescription,
    );
    final JumpToNearestTimestampUseCase jumpToNearestTimestampUseCase =
        ref.read(jumpToNearestTimestampUseCaseProvider);
    final bool isOffline = ref.watch(networkStatusProvider).maybeWhen(
          data: (NetworkStatus status) => status == NetworkStatus.offline,
          orElse: () => false,
        );
    final bool isOfflineFallback =
        ref.watch(authNotifierProvider).isOfflineFallback;
    final bool remoteActionsDisabled = isOffline || isOfflineFallback;

    final double maxSeconds =
        math.max(state.duration.inMilliseconds / 1000, 1).toDouble();
    final double positionSeconds =
        (_dragSeconds ?? state.position.inMilliseconds / 1000)
            .clamp(0, maxSeconds)
            .toDouble();

    final bool canToggleFullscreen = state.errorMessage == null &&
        !_isDeleteInProgress &&
        !_isFullscreenOpen;

    final ThemeData theme = Theme.of(context);
    final TextTheme text = theme.textTheme;
    final LtPalette palette = LtPalette.of(context);
    final bool playbackEnabled = state.errorMessage == null;
    final Duration shownPosition =
        Duration(milliseconds: (positionSeconds * 1000).round());

    final Widget video = _buildVideoSurface(
      videoId: videoId,
      state: state,
      controller: controller,
      videoController: videoController,
    );

    final Widget controls = Padding(
      padding: const EdgeInsets.symmetric(horizontal: LtSizes.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isOffline) ...<Widget>[
            const SizedBox(height: 10),
            StateFeedbackBanner(
              message: state.sourceKind == PlayableSourceKind.localFile
                  ? 'Нет сети — играет файл с телефона.'
                  : 'Нет сети — видео с сервера может не открыться.',
              tone: StateFeedbackTone.warning,
            ),
          ],
          if (state.isRecovering) ...<Widget>[
            const SizedBox(height: 10),
            const StateFeedbackBanner(
              message: 'Связь прервалась — переподключаемся…',
              tone: StateFeedbackTone.warning,
            ),
          ],
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
            StateFeedbackBanner(
              message: state.errorMessage!,
              tone: StateFeedbackTone.error,
            ),
          ],
          if (state.isLoading) ...<Widget>[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ],
          const SizedBox(height: 8),
          // One timeline: the chapters are the track, the played part is coral
          // as on every cover, and the thumb rides on it.
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: LtColors.coral,
              inactiveTrackColor: theme.colorScheme.onSurface.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.24 : 0.14,
              ),
              thumbColor: LtColors.coral,
              overlayColor: LtColors.coral.withValues(alpha: 0.14),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 0,
                pressedElevation: 0,
              ),
            ),
            child: ChapterTimeline(
              merged: timestamps.isNotEmpty,
              sliderPadding: EdgeInsets.zero,
              chapterBar: PlayerChapterBar(
                chapters: timestamps,
                duration: state.duration,
                position: shownPosition,
                isSeeking: _dragSeconds != null,
                enabled: playbackEnabled,
                fillColor: LtColors.coral,
                trackColor: theme.brightness == Brightness.dark
                    ? const Color(0xFF3D4263)
                    : const Color(0xFFCDD1E2),
                onSeek: (Duration start) => unawaited(controller.seek(start)),
              ),
              slider: Slider(
                min: 0,
                max: maxSeconds,
                value: positionSeconds,
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 12,
                ),
                onChanged: !playbackEnabled
                    ? null
                    : (double value) {
                        setState(() {
                          _dragSeconds = value;
                        });
                      },
                onChangeEnd: !playbackEnabled
                    ? null
                    : (double value) {
                        setState(() {
                          _dragSeconds = null;
                        });
                        unawaited(
                          controller.seek(
                            Duration(milliseconds: (value * 1000).round()),
                          ),
                        );
                      },
              ),
            ),
          ),
          // Times at the ends of the timeline, the volume between them.
          Transform.translate(
            offset: const Offset(0, -10),
            child: Row(
              children: <Widget>[
                Text(
                  _formatDuration(shownPosition),
                  style: _timeStyle(text),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints row) {
                      // The mute button is 48 dp; below 56 dp of track a
                      // slider is no use, and the phone's own volume remains.
                      final double track = math.min(132, row.maxWidth - 56);
                      if (track < 56) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: Theme(
                          data: theme.copyWith(
                            sliderTheme: theme.sliderTheme.copyWith(
                              trackHeight: 4,
                              trackShape: const EvenSliderTrackShape(),
                              activeTrackColor:
                                  theme.brightness == Brightness.dark
                                      ? const Color(0xFF6A7096)
                                      : const Color(0xFF8E94B3),
                              inactiveTrackColor:
                                  theme.brightness == Brightness.dark
                                      ? const Color(0xFF2A2E44)
                                      : const Color(0xFFDDE0EC),
                              thumbColor: theme.brightness == Brightness.dark
                                  ? const Color(0xFF8E94B3)
                                  : const Color(0xFF6B7190),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                                elevation: 0,
                                pressedElevation: 0,
                              ),
                            ),
                          ),
                          child: PlayerVolumeControl(
                            volume: ref.watch(playerVolumeProvider),
                            sliderWidth: track,
                            sliderPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Text(
                  _formatDuration(state.duration),
                  style: _timeStyle(text)?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _EqualSlots(
            children: <Widget>[
              _buildTransportButton(
                icon: Icons.undo_rounded,
                tooltip: 'Вернуться туда, откуда перешли',
                small: true,
                enabled: playbackEnabled && state.navigationEntries.isNotEmpty,
                onPressed: () => unawaited(
                  controller.seekToNavigationOrigin(
                    state.navigationEntries.last.id,
                  ),
                ),
              ),
              _buildTransportButton(
                icon: Icons.replay_10_rounded,
                tooltip: 'Назад на 10 с',
                enabled: playbackEnabled,
                onPressed: () => unawaited(
                  controller.seekRelative(const Duration(seconds: -10)),
                ),
              ),
              SizedBox.square(
                dimension: 72,
                child: IconButton.filled(
                  tooltip: state.isPlaying ? 'Пауза' : 'Воспроизвести',
                  style: IconButton.styleFrom(
                    backgroundColor: LtColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: !playbackEnabled
                      ? null
                      : () => unawaited(controller.togglePlayback()),
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 42,
                  ),
                ),
              ),
              _buildTransportButton(
                icon: Icons.forward_10_rounded,
                tooltip: 'Вперёд на 10 с',
                enabled: playbackEnabled,
                onPressed: () => unawaited(
                  controller.seekRelative(const Duration(seconds: 10)),
                ),
              ),
              _buildTransportButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'К следующей главе',
                enabled: playbackEnabled && timestamps.isNotEmpty,
                onPressed: () => unawaited(
                  _jumpToNearestTimestamp(
                    context: context,
                    controller: controller,
                    currentPosition: state.position,
                    timestamps: timestamps,
                    jumpToNearestTimestampUseCase:
                        jumpToNearestTimestampUseCase,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PlayerActionStrip(
            actions: <_PlayerAction>[
              _PlayerAction(
                icon: Icons.bookmark_add_outlined,
                label: 'Закладка',
                enabled: playbackEnabled && !_isDeleteInProgress,
                onPressed: () => unawaited(controller.addManualBookmark()),
              ),
              if (controller.hasSubtitleTracks)
                _PlayerAction(
                  icon: state.subtitlesEnabled
                      ? Icons.closed_caption
                      : Icons.closed_caption_off,
                  label: 'Субтитры',
                  tooltip: state.subtitlesEnabled
                      ? 'Выключить субтитры'
                      : 'Включить субтитры',
                  selected: state.subtitlesEnabled,
                  enabled: !state.isLoading && playbackEnabled,
                  onPressed: controller.toggleSubtitles,
                ),
              if (state.sourceKind != PlayableSourceKind.localFile &&
                  !_downloadStartedForCurrentVideo)
                _PlayerAction(
                  icon: Icons.download_outlined,
                  label: 'Скачать',
                  tooltip: remoteActionsDisabled
                      ? 'Доступно после подключения'
                      : 'Скачать на телефон',
                  enabled: playbackEnabled &&
                      !remoteActionsDisabled &&
                      !_isDeleteInProgress,
                  onPressed: () => unawaited(_downloadCurrentVideo(videoId)),
                ),
              _PlayerAction(
                key: finishViewingButtonKey,
                icon: Icons.task_alt,
                label: 'Просмотрено',
                tooltip: 'Завершить просмотр',
                enabled: !state.isLoading &&
                    playbackEnabled &&
                    !_isDeleteInProgress &&
                    !_isFinishingViewing,
                onPressed: () => unawaited(
                  _finishViewing(videoId: videoId, controller: controller),
                ),
              ),
              _PlayerAction(
                icon: Icons.link_rounded,
                label: 'Ссылка',
                tooltip: 'Скопировать ссылку',
                enabled: playbackEnabled && !_isDeleteInProgress,
                onPressed: () => unawaited(_shareVideo(videoId)),
              ),
              _PlayerAction(
                icon: Icons.delete_outline,
                label: 'Удалить',
                danger: true,
                enabled: playbackEnabled && !_isDeleteInProgress,
                onPressed: () => unawaited(
                  _startDeleteFlow(videoId: videoId, controller: controller),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget sections = Padding(
      padding: const EdgeInsets.fromLTRB(LtSizes.gutter, 8, LtSizes.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.navigationEntries.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            LtSectionCard(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: SizedBox(
                height: math.min(state.navigationEntries.length, 3) * 56.0,
                child: ListView.builder(
                  key: const PageStorageKey<String>('player-navigation'),
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: state.navigationEntries.length,
                  physics: state.navigationEntries.length > 3
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemBuilder: (BuildContext context, int index) {
                    final PlayerNavigationEntry entry =
                        state.navigationEntries[index];
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      leading: Icon(
                        Icons.undo_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        'Вернуться на ${_formatDuration(entry.fromPosition)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Вы перешли на ${_formatDuration(entry.toPosition)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: !playbackEnabled
                          ? null
                          : () => unawaited(
                                controller.seekToNavigationOrigin(entry.id),
                              ),
                    );
                  },
                ),
              ),
            ),
          ],
          if (timestamps.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                key: const PageStorageKey<String>('player-timestamps'),
                initiallyExpanded: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  'Главы · ${timestamps.length}',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: <Widget>[
                  for (final VideoTimestamp timestamp in timestamps)
                    _ChapterTile(
                      label: timestamp.label,
                      time: _formatDuration(timestamp.position),
                      isCurrent: _isCurrentChapter(
                        timestamps,
                        timestamp,
                        state.position,
                      ),
                      isPast: state.position >= timestamp.position,
                      onTap: !playbackEnabled
                          ? null
                          : () => unawaited(
                                controller.seek(timestamp.position),
                              ),
                    ),
                ],
              ),
            ),
          ],
          if (state.bookmarks.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: ExpansionTile(
                key: const PageStorageKey<String>('player-bookmarks'),
                initiallyExpanded: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  'Закладки · ${state.bookmarks.length}',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: <Widget>[
                  for (final BookmarkItem bookmark in state.bookmarks)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 8),
                      leading: _TimeBadge(
                        label: _formatDuration(bookmark.position),
                      ),
                      title: Text(
                        bookmark.caption.isEmpty
                            ? 'Закладка'
                            : bookmark.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge,
                      ),
                      subtitle: bookmark.isPendingSync
                          ? const Text('ещё не отправлена')
                          : null,
                      trailing: IconButton(
                        color: palette.subtle,
                        onPressed: !playbackEnabled
                            ? null
                            : () => unawaited(
                                  controller.deleteBookmark(bookmark.id),
                                ),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Удалить закладку',
                      ),
                      onTap: !playbackEnabled
                          ? null
                          : () => unawaited(controller.seek(bookmark.position)),
                      onLongPress: !playbackEnabled
                          ? null
                          : () => unawaited(
                                _editBookmarkCaption(
                                  controller: controller,
                                  bookmarkId: bookmark.id,
                                  caption: bookmark.caption,
                                ),
                              ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NotesSection(
                videoId: videoId,
                title: (widget.videoTitle ?? '').trim(),
                onPausePlayback: controller.pause,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TranscriptPanel(
                videoId: int.parse(widget.videoId),
                onSeek: (position) => controller.seek(position),
                onBookmark: controller.addTextBookmark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: CastEntryPoint(videoId: videoId),
            ),
          ),
        ],
      ),
    );

    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom + 24;

    // Fullscreen is where every player has it: a corner of the video.
    final Widget videoWithFullscreen = Stack(
      children: <Widget>[
        video,
        Positioned(
          right: 16,
          bottom: 16,
          child: IconButton(
            tooltip: 'На весь экран',
            onPressed: playbackEnabled && !_isDeleteInProgress
                ? () => unawaited(_openFullscreen(videoId: videoId))
                : null,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.55),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black.withValues(alpha: 0.25),
              disabledForegroundColor: Colors.white38,
              minimumSize: const Size.square(48),
              fixedSize: const Size.square(48),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
            ),
            icon: const Icon(Icons.fullscreen, size: 24),
          ),
        ),
      ],
    );

    return PlayerKeyboardShortcuts(
      focusNode: _keyboardFocusNode,
      onTogglePlayback: state.errorMessage != null
          ? null
          : () => unawaited(controller.togglePlayback()),
      onToggleFullscreen: canToggleFullscreen
          ? () => unawaited(_openFullscreen(videoId: videoId))
          : null,
      child: Scaffold(
        appBar: AppBar(
          shape: theme.brightness == Brightness.dark
              ? const Border(bottom: BorderSide(color: Color(0xFF1E2236)))
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _resolvedTitle(videoId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              _SourceLabel(
                icon: _sourceStatusIcon(state.sourceKind),
                label: _sourceStatusLabel(state.sourceKind),
              ),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewport) {
            final bool isPhonePortrait = viewport.maxWidth < 600 &&
                viewport.maxHeight > viewport.maxWidth;
            if (isPhonePortrait) {
              // On a phone the video stays at the top while the controls,
              // chapters and notes scroll under it, as in video apps. Once the
              // controls have scrolled away, a slim bar under the video keeps
              // play/pause and the progress in reach.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // A vertical video takes at most half the screen, so the
                  // controls under it always have room.
                  ColoredBox(
                    color: Colors.black,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: viewport.maxHeight * 0.5,
                      ),
                      child: Align(
                        heightFactor: 1,
                        child: videoWithFullscreen,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _controlsScrolledAway,
                    builder: (BuildContext context, bool away, _) =>
                        AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      child: away
                          ? _MiniPlaybackBar(
                              isPlaying: state.isPlaying,
                              enabled: playbackEnabled,
                              position: state.position,
                              duration: state.duration,
                              chapter: _currentChapterTitle(
                                timestamps,
                                state.position,
                              ),
                              format: _formatDuration,
                              onToggle: () =>
                                  unawaited(controller.togglePlayback()),
                              onSeekBy: (Duration by) =>
                                  unawaited(controller.seekRelative(by)),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification n) {
                        if (n.metrics.axis == Axis.vertical) {
                          _controlsScrolledAway.value = n.metrics.pixels > 240;
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(bottom: bottomInset),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[controls, sections],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // The video and the controls under it fit the window together, the way the
                  // web player caps its video: the page scrolls on to the notes and the rest,
                  // never down to the play button.
                  PlayerStageLayout(
                    availableHeight: viewport.maxHeight - _pageVerticalPadding,
                    video: videoWithFullscreen,
                    controls: controls,
                  ),
                  sections,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  TextStyle? _timeStyle(TextTheme text) => text.labelMedium?.copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );

  String? _currentChapterTitle(
    List<VideoTimestamp> timestamps,
    Duration position,
  ) {
    String? title;
    for (final VideoTimestamp t in timestamps) {
      if (position >= t.position) {
        title = t.label;
      }
    }
    return title;
  }

  bool _isCurrentChapter(
    List<VideoTimestamp> timestamps,
    VideoTimestamp chapter,
    Duration position,
  ) {
    VideoTimestamp? current;
    for (final VideoTimestamp t in timestamps) {
      if (position >= t.position) {
        current = t;
      }
    }
    return identical(current, chapter);
  }

  Widget _buildTransportButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
    bool small = false,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color tint = dark ? const Color(0xFF1E2446) : colors.primaryContainer;
    final Color onTint =
        dark ? const Color(0xFFC9CEFF) : colors.onPrimaryContainer;
    // One size for the four around play, so none of them looks like an
    // accident; the outer two only carry a lighter icon.
    return SizedBox.square(
      dimension: 56,
      child: IconButton.filledTonal(
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: tint,
          disabledBackgroundColor: tint.withValues(alpha: 0.5),
          foregroundColor: onTint,
        ),
        icon: Icon(icon, size: small ? 26 : 30),
      ),
    );
  }

  /// The live video, or a placeholder while there is none to show.
  ///
  /// On a phone the video runs edge to edge, the way video apps show it. It keeps its own aspect
  /// ratio inside whatever height [PlayerStageLayout] leaves it, so a tall window and a short one
  /// both show the whole picture.
  Widget _buildVideoSurface({
    required int videoId,
    required PlayerUiState state,
    required PlayerController controller,
    required VideoPlayerController? videoController,
  }) {
    final LtPalette palette = LtPalette.of(context);
    if (videoController == null || !videoController.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: palette.stage,
          child: Center(
            child: state.isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.videocam_off_outlined,
                        color: Colors.white70,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Видео не открылось',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    return AspectRatio(
      key: playerVideoSurfaceKey,
      aspectRatio: videoController.value.aspectRatio > 0
          ? videoController.value.aspectRatio
          : (16 / 9),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            VideoPlayer(videoController),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: state.errorMessage != null
                    ? null
                    : () {
                        // A click on the picture also gives the keyboard back to the player,
                        // out of a text field it was typing in, so Space works again.
                        _keyboardFocusNode.requestFocus();
                        unawaited(controller.togglePlayback());
                      },
                child: const SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: TranscriptCaptions(
                videoId: videoId,
                controller: videoController,
              ),
            ),
            if (state.isBuffering)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFullscreen({required int videoId}) async {
    setState(() {
      _isFullscreenOpen = true;
    });
    final Object? result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => _FullscreenPlayerView(
          videoId: videoId,
          videoTitle: widget.videoTitle,
          videoDescription: widget.videoDescription,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isFullscreenOpen = false;
    });
    // Back from fullscreen, the keyboard belongs to this page's player again.
    _keyboardFocusNode.requestFocus();
    if (result is PlayerNavigationResult) {
      Navigator.of(context).pop(result);
      return;
    }
    if (result == _FullscreenRequest.finishViewing) {
      await _finishViewing(
        videoId: videoId,
        controller: ref.read(playerControllerProvider(videoId).notifier),
      );
    }
  }

  /// «Завершить просмотр»: the video is saved as watched, the viewer is asked for a Rating and then
  /// whether to delete the file, and the player closes whatever they answer.
  Future<void> _finishViewing({
    required int videoId,
    required PlayerController controller,
  }) async {
    if (_isFinishingViewing || _isDeleteInProgress || _isDeleteDialogVisible) {
      return;
    }
    setState(() {
      _isFinishingViewing = true;
    });
    try {
      final bool marked = await controller.finishViewing();
      if (!mounted) {
        return;
      }
      if (!marked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Видео ещё не открылось')),
        );
        return;
      }
      await showFinishViewingRating(
        context: context,
        ref: ref,
        videoId: videoId,
        title: (widget.videoTitle ?? '').trim(),
      );
      if (!mounted) {
        return;
      }
      await _startDeleteFlow(videoId: videoId, controller: controller);
      // A delete has already closed the page; anything else - «Нет», a dismissed dialog, a delete
      // that failed - ends the viewing all the same.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFinishingViewing = false;
        });
      }
    }
  }

  Future<void> _downloadCurrentVideo(int videoId) async {
    try {
      await ref.read(downloadServiceProvider).enqueue(
            videoId: videoId,
            remoteUrl: '/api/files/getFileById?fileId=$videoId',
            title: (widget.videoTitle ?? '').trim().isEmpty
                ? null
                : widget.videoTitle!.trim(),
          );
      final DownloadItem? item = await ref
          .read(localDownloadsRepositoryProvider)
          .findByVideoId(videoId);
      final bool started = item != null &&
          (item.status == DownloadStatus.queued ||
              item.status == DownloadStatus.downloading ||
              item.status == DownloadStatus.completed);
      if (started && mounted) {
        setState(() {
          _downloadStartedForCurrentVideo = true;
        });
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            started
                ? 'Поставлено на скачивание'
                : 'Не удалось поставить на скачивание',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text('Не удалось поставить на скачивание')),
      );
    }
  }

  Future<void> _shareVideo(int videoId) async {
    final config = ref.read(appConfigProvider);
    final baseUrl = config.apiBaseUrl.replaceFirst('https://api.', 'https://');
    final url = '$baseUrl/#/player?videoId=$videoId';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка скопирована')),
      );
    }
  }

  String _resolvedTitle(int videoId) {
    final String title = (widget.videoTitle ?? '').trim();
    if (title.isNotEmpty) {
      return title;
    }
    return 'Видео №$videoId';
  }

  bool _isPlaybackCompleted(PlayerUiState? state) {
    if (state == null || state.duration <= Duration.zero) {
      return false;
    }
    return state.position >= state.duration;
  }

  /// The post-viewing menu comes first for ExternalVideo and Courses videos,
  /// then the usual end-of-video choices.
  Future<void> _onPlaybackCompleted({
    required int videoId,
    required PlayerController controller,
  }) async {
    bool showNotes = false;
    try {
      showNotes =
          await ref.read(notesRepositoryProvider).isPostViewingVideo(videoId);
    } catch (_) {
      showNotes = false;
    }
    if (!mounted || _isFullscreenOpen) {
      return;
    }
    if (showNotes) {
      await showPostViewingNotes(
        context: context,
        videoId: videoId,
        title: (widget.videoTitle ?? '').trim(),
      );
      if (!mounted || _isFullscreenOpen) {
        return;
      }
    }
    await _startDeleteFlow(
      videoId: videoId,
      controller: controller,
      allowRestart: true,
    );
  }

  Future<void> _editBookmarkCaption({
    required PlayerController controller,
    required int bookmarkId,
    required String caption,
  }) async {
    final String? updated = await showMarkCaptionDialog(
      context: context,
      caption: caption,
      onPausePlayback: controller.pause,
    );
    if (updated == null || !mounted) {
      return;
    }
    await controller.updateBookmarkCaption(bookmarkId, updated);
  }

  Future<void> _startDeleteFlow({
    required int videoId,
    required PlayerController controller,
    bool allowRestart = false,
  }) async {
    if (_isDeleteInProgress || _isDeleteDialogVisible) {
      return;
    }
    final DownloadItem? downloadItem =
        await ref.read(localDownloadsRepositoryProvider).findByVideoId(videoId);
    final bool canDeleteLocal =
        downloadItem?.status == DownloadStatus.completed;
    _isDeleteDialogVisible = true;
    final _PlayerDeleteAction? action = await _showDeleteDialog(
      canDeleteLocal: canDeleteLocal,
      allowRestart: allowRestart,
    );
    _isDeleteDialogVisible = false;
    if (!mounted || action == null || action == _PlayerDeleteAction.cancel) {
      return;
    }
    if (action == _PlayerDeleteAction.restart) {
      await controller.seek(Duration.zero, trackNavigation: false);
      await controller.play();
      return;
    }
    await _runDeleteAction(
      videoId: videoId,
      controller: controller,
      action: action,
    );
  }

  Future<_PlayerDeleteAction?> _showDeleteDialog({
    required bool canDeleteLocal,
    required bool allowRestart,
  }) {
    return showDialog<_PlayerDeleteAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Удалить файл?'),
          actions: <Widget>[
            if (canDeleteLocal)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PlayerDeleteAction.localOnly),
                child: const Text('Локально'),
              ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PlayerDeleteAction.serverOnly),
              child: const Text('С сервера'),
            ),
            if (canDeleteLocal)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PlayerDeleteAction.everywhere),
                child: const Text('Отовсюду'),
              ),
            if (allowRestart)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PlayerDeleteAction.restart),
                child: const Text('С начала'),
              ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PlayerDeleteAction.cancel),
              child: const Text('Нет'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runDeleteAction({
    required int videoId,
    required PlayerController controller,
    required _PlayerDeleteAction action,
  }) async {
    setState(() {
      _isDeleteInProgress = true;
    });
    try {
      await controller.pause();
      final CatalogRepository catalogRepository = ref.read(
        catalogRepositoryProvider,
      );
      switch (action) {
        case _PlayerDeleteAction.localOnly:
          final Failure? localFailure = await catalogRepository.deleteLocal(
            videoId,
          );
          if (localFailure != null) {
            _showDeleteFailure(localFailure.message);
            return;
          }
          if (mounted) {
            Navigator.of(context).pop(PlayerNavigationResult.deletedLocal);
          }
          return;
        case _PlayerDeleteAction.serverOnly:
          final Failure? serverFailure = await catalogRepository.deleteServer(
            videoId,
          );
          if (serverFailure != null) {
            _showDeleteFailure(serverFailure.message);
            return;
          }
          if (mounted) {
            Navigator.of(context).pop(PlayerNavigationResult.deletedServer);
          }
          return;
        case _PlayerDeleteAction.everywhere:
          final Failure? serverFailure = await catalogRepository.deleteServer(
            videoId,
          );
          if (serverFailure != null) {
            _showDeleteFailure(
              'Удаление с сервера не удалось: ${serverFailure.message}',
            );
            return;
          }
          final Failure? localFailure = await catalogRepository.deleteLocal(
            videoId,
          );
          if (localFailure != null) {
            _showDeleteFailure(
              'Видео удалено с сервера, но локальное удаление не удалось: ${localFailure.message}',
            );
            return;
          }
          if (mounted) {
            Navigator.of(context).pop(PlayerNavigationResult.deletedEverywhere);
          }
          return;
        case _PlayerDeleteAction.restart:
        case _PlayerDeleteAction.cancel:
          return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleteInProgress = false;
        });
      }
    }
  }

  void _showDeleteFailure(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _sourceStatusIcon(PlayableSourceKind? sourceKind) {
    return switch (sourceKind) {
      PlayableSourceKind.localFile => Icons.smartphone_rounded,
      PlayableSourceKind.remoteUrl => Icons.cloud_outlined,
      null => Icons.hourglass_bottom_rounded,
    };
  }

  String _sourceStatusLabel(PlayableSourceKind? sourceKind) {
    return switch (sourceKind) {
      PlayableSourceKind.localFile => 'Файл с телефона',
      PlayableSourceKind.remoteUrl => 'С сервера',
      null => 'Готовим видео…',
    };
  }

  String _formatDuration(Duration value) {
    final Duration normalized = value < Duration.zero ? Duration.zero : value;
    final int totalSeconds = normalized.inSeconds;
    final int minutes = (totalSeconds ~/ 60) % 60;
    final int seconds = totalSeconds % 60;
    final int hours = totalSeconds ~/ 3600;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}

class _FullscreenPlayerView extends ConsumerStatefulWidget {
  const _FullscreenPlayerView({
    required this.videoId,
    this.videoTitle,
    this.videoDescription,
  });

  final int videoId;
  final String? videoTitle;
  final String? videoDescription;

  @override
  ConsumerState<_FullscreenPlayerView> createState() =>
      _FullscreenPlayerViewState();
}

class _FullscreenPlayerViewState extends ConsumerState<_FullscreenPlayerView> {
  bool _showControls = false;
  bool _isScreenLocked = false;
  bool _showLockedOverlay = true;
  Timer? _lockedOverlayHideTimer;
  double? _dragSeconds;
  bool _isDeleteInProgress = false;
  bool _completionDialogShownForCurrentCompletion = false;
  bool _isDeleteDialogVisible = false;

  /// The keyboard inside fullscreen: Space plays or pauses, Ctrl+F and Escape leave fullscreen.
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'Fullscreen player keyboard',
  );

  /// With a mouse the controls come up when the pointer moves and go away once it rests, the way a
  /// desktop video player behaves. Touch never hovers, so on a phone nothing of this runs and the
  /// controls stay a double tap away.
  Timer? _pointerControlsHideTimer;
  bool _isPointerOverControls = false;
  static const Duration _pointerControlsHideDelay = Duration(seconds: 3);

  /// Whether the window has been asked to leave fullscreen already. The route asks once, as early
  /// as it can: when it is popped, or when it goes away without a pop.
  bool _hasLeftWindowFullscreen = false;

  /// Whether this route has already been asked to close because playback moved to a Receiver. A
  /// route is closed once, however many times it rebuilds while the closing frame is pending.
  bool _isLeavingForRemoteControlMode = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(
      SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    // On Windows the window itself goes fullscreen: no title bar, frame or taskbar over the video.
    unawaited(PlayerWindowFullscreen.setFullScreen(true));
  }

  @override
  void dispose() {
    _lockedOverlayHideTimer?.cancel();
    _pointerControlsHideTimer?.cancel();
    _keyboardFocusNode.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    // Normally already left when the route was popped; this covers a route removed without one.
    _leaveWindowFullscreen();
    super.dispose();
  }

  void _leaveWindowFullscreen() {
    if (_hasLeftWindowFullscreen) {
      return;
    }
    _hasLeftWindowFullscreen = true;
    unawaited(PlayerWindowFullscreen.setFullScreen(false));
  }

  @override
  Widget build(BuildContext context) {
    // Fullscreen is a local video player and nothing else: a live video surface, controls that
    // drive it, an "Add bookmark" button and the local navigation history. Remote Control Mode owns
    // no local player, so this route closes rather than turning itself into a second remote.
    //
    // Closing is the deliberate choice over rendering the remote surface here. The remote already
    // exists on the page this route was pushed from, and it is a portrait, scrolling surface, while
    // this route is landscape-locked and immersive: rendering it here would mean a second copy of
    // the same controls in a shape nobody asked for. Closing also takes every local-only affordance
    // away at once, which is what the mode requires, rather than hiding them one by one and leaving
    // the next one added to be found by the next reader.
    //
    // It is decided before the player controller is touched, for the same reason the page below
    // decides it first: watching it here would build the very player this mode has given up. What
    // is shown until the closing frame runs is deliberately empty, and it is one frame - the remote
    // the viewer wants is already built on the page underneath.
    final bool isRemoteControlMode =
        ref.watch(castControllerProvider).isRemoteControlMode;
    if (isRemoteControlMode) {
      _leaveForRemoteControlMode();
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      );
    }

    // Playback is local again, so a later Cast Session gets its own closing frame rather than
    // finding this route already marked as leaving.
    _isLeavingForRemoteControlMode = false;

    final PlayerUiState state = ref.watch(
      playerControllerProvider(widget.videoId),
    );
    final PlayerController controller = ref.read(
      playerControllerProvider(widget.videoId).notifier,
    );
    ref.listen<PlayerUiState>(playerControllerProvider(widget.videoId), (
      PlayerUiState? previous,
      PlayerUiState next,
    ) {
      final bool wasCompleted = _isPlaybackCompleted(previous);
      final bool isCompleted = _isPlaybackCompleted(next);
      if (!isCompleted) {
        _completionDialogShownForCurrentCompletion = false;
        return;
      }
      if (wasCompleted ||
          _completionDialogShownForCurrentCompletion ||
          _isDeleteDialogVisible ||
          _isScreenLocked) {
        return;
      }
      _completionDialogShownForCurrentCompletion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_onPlaybackCompleted(controller: controller));
      });
    });
    final VideoPlayerController? videoController = controller.videoController;
    final List<VideoTimestamp> timestamps = _chapters(
      ref,
      widget.videoId,
      widget.videoDescription,
    );
    final JumpToNearestTimestampUseCase jumpToNearestTimestampUseCase =
        ref.read(jumpToNearestTimestampUseCaseProvider);
    final double maxSeconds =
        math.max(state.duration.inMilliseconds / 1000, 1).toDouble();
    final double positionSeconds =
        (_dragSeconds ?? state.position.inMilliseconds / 1000)
            .clamp(0, maxSeconds)
            .toDouble();

    final bool isOverlayVisible =
        _isScreenLocked ? _showLockedOverlay : _showControls;
    // The punch-hole camera pads one side of a phone on its side; the other,
    // curved edge gets as much room, so the controls sit symmetrically.
    final EdgeInsets viewPadding = MediaQuery.viewPaddingOf(context);
    final double edgeBalance =
        math.max(0.0, viewPadding.left - viewPadding.right);
    String? chapterTitle;
    for (final VideoTimestamp t in timestamps) {
      if (state.position >= t.position) {
        chapterTitle = t.label;
      }
    }

    return PopScope<Object?>(
      // The window leaves fullscreen as the route starts closing, not once its animation is over.
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          _leaveWindowFullscreen();
        }
      },
      child: PlayerKeyboardShortcuts(
        focusNode: _keyboardFocusNode,
        onTogglePlayback: _isScreenLocked
            ? null
            : () => unawaited(controller.togglePlayback()),
        onToggleFullscreen: _closeFullscreen,
        onExitFullscreen: _closeFullscreen,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            top: false,
            bottom: false,
            child: MouseRegion(
              // The pointer is hidden together with the controls, so it does not sit over the video.
              cursor: isOverlayVisible
                  ? MouseCursor.defer
                  : SystemMouseCursors.none,
              onHover: _onPointerHover,
              child: GestureDetector(
                key: const Key('fullscreen-player-gesture-area'),
                behavior: HitTestBehavior.opaque,
                onTap: _isScreenLocked
                    ? _showLockedOverlayAfterTap
                    : () {
                        _keyboardFocusNode.requestFocus();
                        unawaited(controller.togglePlayback());
                      },
                onDoubleTap: _isScreenLocked
                    ? null
                    : () {
                        _pointerControlsHideTimer?.cancel();
                        setState(() {
                          _showControls = !_showControls;
                          if (!_showControls) {
                            _isPointerOverControls = false;
                          }
                        });
                      },
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (videoController != null &&
                        videoController.value.isInitialized)
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: videoController.value.size.width,
                          height: videoController.value.size.height,
                          child: VideoPlayer(videoController),
                        ),
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                    if (videoController != null &&
                        videoController.value.isInitialized)
                      Positioned.fill(
                          child: TranscriptCaptions(
                              videoId: widget.videoId,
                              controller: videoController)),
                    if (state.isBuffering)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Color(0x44000000),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ),
                    if (isOverlayVisible) ...<Widget>[
                      // Top: the title and the lock, over a dark fade.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _Scrim(
                          top: true,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                24, 14, 9 + edgeBalance, 28),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: _isScreenLocked
                                      ? Text(
                                          'Экран заблокирован — касания не работают',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Colors.white70),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Text(
                                              (widget.videoTitle ?? '').trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            if (chapterTitle != null)
                                              Text(
                                                chapterTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Colors.white70,
                                                    ),
                                              ),
                                          ],
                                        ),
                                ),
                                const SizedBox(width: 8),
                                // A locked screen is read-only, so it shows no volume either.
                                if (!_isScreenLocked)
                                  _holdControls(
                                    Theme(
                                      data: Theme.of(context).copyWith(
                                        sliderTheme: Theme.of(context)
                                            .sliderTheme
                                            .copyWith(
                                              trackHeight: 3,
                                              trackShape:
                                                  const EvenSliderTrackShape(),
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 7,
                                                elevation: 0,
                                                pressedElevation: 0,
                                              ),
                                            ),
                                      ),
                                      child: PlayerVolumeControl(
                                        volume: ref.watch(playerVolumeProvider),
                                        // A white speaker like the lock, an
                                        // opaque light-grey track.
                                        color: Colors.white,
                                        trackColor: const Color(0xFFBFBFBF),
                                        sliderWidth: 132,
                                        sliderPadding:
                                            const EdgeInsets.fromLTRB(
                                          0,
                                          0,
                                          8,
                                          0,
                                        ),
                                      ),
                                    ),
                                  ),
                                _holdControls(
                                  _fullscreenActionButton(
                                    icon: _isScreenLocked
                                        ? Icons.lock_open
                                        : Icons.lock_outline,
                                    tooltip: _isScreenLocked
                                        ? 'Разблокировать экран'
                                        : 'Заблокировать экран',
                                    onPressed: _toggleScreenLock,
                                    emphasized: _isScreenLocked,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!_isScreenLocked)
                        // Middle: the three buttons a thumb reaches for most.
                        Center(
                          child: _holdControls(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _fullscreenActionButton(
                                  icon: Icons.replay_10_rounded,
                                  tooltip: 'Назад на 10 с',
                                  size: 60,
                                  filled: true,
                                  onPressed: () => unawaited(
                                    controller.seekRelative(
                                      const Duration(seconds: -10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 36),
                                _fullscreenActionButton(
                                  icon: state.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  tooltip: state.isPlaying
                                      ? 'Пауза'
                                      : 'Воспроизвести',
                                  size: 76,
                                  emphasized: true,
                                  onPressed: controller.togglePlayback,
                                ),
                                const SizedBox(width: 36),
                                _fullscreenActionButton(
                                  icon: Icons.forward_10_rounded,
                                  tooltip: 'Вперёд на 10 с',
                                  size: 60,
                                  filled: true,
                                  onPressed: () => unawaited(
                                    controller.seekRelative(
                                      const Duration(seconds: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Bottom: the timeline, then everything else in one row. A locked screen
                      // keeps a live, read-only timeline so the viewer still sees where they are.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _Scrim(
                          top: false,
                          child: _holdControls(
                            Padding(
                              padding: EdgeInsets.fromLTRB(24, 28,
                                  24 + edgeBalance, 40 + viewPadding.bottom),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Transform.translate(
                                        offset: const Offset(0, -6),
                                        child: Text(
                                          _formatDuration(Duration(
                                            milliseconds:
                                                (positionSeconds * 1000)
                                                    .round(),
                                          )),
                                          style: _fullscreenTimeStyle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ChapterTimeline(
                                          merged: timestamps.isNotEmpty,
                                          chapterBar: PlayerChapterBar(
                                            chapters: timestamps,
                                            duration: state.duration,
                                            position: Duration(
                                              milliseconds:
                                                  (positionSeconds * 1000)
                                                      .round(),
                                            ),
                                            isSeeking: _dragSeconds != null,
                                            enabled: !_isScreenLocked,
                                            onSeek: (Duration start) =>
                                                unawaited(
                                                    controller.seek(start)),
                                            trackColor: Colors.white
                                                .withValues(alpha: 0.35),
                                            fillColor: LtColors.coral,
                                            textColor: Colors.white,
                                            compact: true,
                                          ),
                                          slider: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                              // With chapters the segments are the track
                                              // (gaps included); the slider adds its thumb.
                                              activeTrackColor:
                                                  timestamps.isNotEmpty
                                                      ? Colors.transparent
                                                      : LtColors.coral,
                                              inactiveTrackColor:
                                                  timestamps.isNotEmpty
                                                      ? Colors.transparent
                                                      : Colors.white24,
                                              thumbColor: LtColors.coral,
                                              overlayColor: Colors.white24,
                                              trackHeight: 4,
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                enabledThumbRadius: 7,
                                              ),
                                            ),
                                            child: Slider(
                                              min: 0,
                                              max: maxSeconds,
                                              value: positionSeconds,
                                              onChanged: _isScreenLocked
                                                  ? null
                                                  : (double value) {
                                                      setState(() {
                                                        _dragSeconds = value;
                                                      });
                                                    },
                                              onChangeEnd: _isScreenLocked
                                                  ? null
                                                  : (double value) {
                                                      setState(() {
                                                        _dragSeconds = null;
                                                      });
                                                      unawaited(
                                                        controller.seek(
                                                          Duration(
                                                            milliseconds:
                                                                (value * 1000)
                                                                    .round(),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Transform.translate(
                                        offset: const Offset(0, -6),
                                        child: Text(
                                          _formatDuration(state.duration),
                                          style: _fullscreenTimeStyle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!_isScreenLocked)
                                    Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: _fullscreenActionButton(
                                            icon: Icons.bookmark_add_outlined,
                                            tooltip: 'Закладка',
                                            label: 'Закладка',
                                            onPressed: _isDeleteInProgress
                                                ? null
                                                : () => unawaited(controller
                                                    .addManualBookmark()),
                                          ),
                                        ),
                                        if (controller.hasSubtitleTracks)
                                          Expanded(
                                            child: _fullscreenActionButton(
                                              icon: state.subtitlesEnabled
                                                  ? Icons.closed_caption
                                                  : Icons.closed_caption_off,
                                              tooltip: state.subtitlesEnabled
                                                  ? 'Выключить субтитры'
                                                  : 'Включить субтитры',
                                              emphasized:
                                                  state.subtitlesEnabled,
                                              label: 'Субтитры',
                                              onPressed:
                                                  controller.toggleSubtitles,
                                            ),
                                          ),
                                        Expanded(
                                          child: _fullscreenActionButton(
                                            icon: Icons.skip_next_rounded,
                                            tooltip: 'Следующая глава',
                                            label: 'След. глава',
                                            onPressed: _isDeleteInProgress
                                                ? null
                                                : () => unawaited(
                                                      _jumpToNearestTimestamp(
                                                        context: context,
                                                        controller: controller,
                                                        currentPosition:
                                                            state.position,
                                                        timestamps: timestamps,
                                                        jumpToNearestTimestampUseCase:
                                                            jumpToNearestTimestampUseCase,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _fullscreenActionButton(
                                            icon: Icons.undo_rounded,
                                            tooltip: 'Вернуться назад',
                                            label: state
                                                    .navigationEntries.isEmpty
                                                ? 'Вернуться'
                                                : 'Назад к ${_formatDuration(state.navigationEntries.last.fromPosition)}',
                                            onPressed: _isDeleteInProgress ||
                                                    state.navigationEntries
                                                        .isEmpty
                                                ? null
                                                : () => unawaited(
                                                      controller
                                                          .seekToNavigationOrigin(
                                                        state.navigationEntries
                                                            .last.id,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _fullscreenActionButton(
                                            icon: Icons
                                                .picture_in_picture_alt_outlined,
                                            tooltip: 'Пауза и свернуть',
                                            label: 'Свернуть',
                                            onPressed: _isDeleteInProgress
                                                ? null
                                                : () => unawaited(
                                                      _pauseAndMinimize(
                                                          controller),
                                                    ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _fullscreenActionButton(
                                            icon: Icons.headphones_rounded,
                                            tooltip: 'Свернуть',
                                            label: 'Фоном',
                                            onPressed: _isDeleteInProgress
                                                ? null
                                                : () =>
                                                    unawaited(_minimizeApp()),
                                          ),
                                        ),
                                        Expanded(
                                          child: _fullscreenActionButton(
                                            key: finishViewingButtonKey,
                                            icon: Icons.task_alt,
                                            tooltip: 'Завершить просмотр',
                                            label: 'Просмотрено',
                                            onPressed: _isDeleteInProgress ||
                                                    _isDeleteDialogVisible ||
                                                    state.isLoading ||
                                                    state.errorMessage != null
                                                ? null
                                                : () =>
                                                    Navigator.of(context).pop(
                                                      _FullscreenRequest
                                                          .finishViewing,
                                                    ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _fullscreenActionButton(
                                            icon: Icons.fullscreen_exit,
                                            tooltip:
                                                'Выйти из полноэкранного режима',
                                            label: 'Обычный вид',
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .maybePop(),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The height of the label under a fullscreen icon.
  static const double _fullscreenLabelHeight = 16;

  static const TextStyle _fullscreenTimeStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Controls under a mouse pointer stay up while it rests on them.
  Widget _holdControls(Widget child) {
    return MouseRegion(
      onEnter: (_) {
        _isPointerOverControls = true;
        _pointerControlsHideTimer?.cancel();
      },
      onExit: (_) {
        _isPointerOverControls = false;
        _restartPointerControlsTimer();
      },
      child: child,
    );
  }

  /// Closes fullscreen because playback has moved to a Receiver.
  ///
  /// The pop is scheduled rather than done here: this is reached from a build, and a route cannot
  /// be removed in the middle of one. Nothing local is alive while it is pending, because the build
  /// that scheduled it returned an empty surface.
  void _leaveForRemoteControlMode() {
    if (_isLeavingForRemoteControlMode) {
      return;
    }
    _isLeavingForRemoteControlMode = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // A Cast Session that ended inside this frame costs the viewer nothing: fullscreen is only
      // given up for a Receiver that is still playing.
      if (!ref.read(castControllerProvider).isRemoteControlMode) {
        _isLeavingForRemoteControlMode = false;
        return;
      }
      unawaited(Navigator.of(context).maybePop());
    });
  }

  void _closeFullscreen() {
    unawaited(Navigator.of(context).maybePop());
  }

  /// A mouse moved over fullscreen: bring the controls up (or, while the screen is locked, the
  /// unlock button) and hide them again once the pointer has rested for a while.
  void _onPointerHover(PointerHoverEvent event) {
    if (_isScreenLocked) {
      if (!_showLockedOverlay) {
        _showLockedOverlayAfterTap();
      }
      return;
    }
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }
    _restartPointerControlsTimer();
  }

  void _restartPointerControlsTimer() {
    _pointerControlsHideTimer?.cancel();
    if (_isScreenLocked || _isPointerOverControls) {
      return;
    }
    _pointerControlsHideTimer = Timer(_pointerControlsHideDelay, () {
      if (!mounted || _isScreenLocked || _isPointerOverControls) {
        return;
      }
      setState(() {
        _showControls = false;
      });
    });
  }

  Future<void> _pauseAndMinimize(PlayerController controller) async {
    await controller.pause();
    await _minimizeApp();
  }

  void _toggleScreenLock() {
    final bool wasLocked = _isScreenLocked;
    _pointerControlsHideTimer?.cancel();
    _isPointerOverControls = false;
    setState(() {
      _isScreenLocked = !_isScreenLocked;
      _dragSeconds = null;
    });
    if (!wasLocked) {
      _showLockedOverlayAfterTap();
    } else {
      _lockedOverlayHideTimer?.cancel();
    }
    if (!wasLocked) {
      return;
    }

    final PlayerUiState state = ref.read(
      playerControllerProvider(widget.videoId),
    );
    if (!_isPlaybackCompleted(state) ||
        _completionDialogShownForCurrentCompletion ||
        _isDeleteDialogVisible) {
      return;
    }
    _completionDialogShownForCurrentCompletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final PlayerController controller = ref.read(
        playerControllerProvider(widget.videoId).notifier,
      );
      unawaited(_startDeleteFlow(controller: controller, allowRestart: true));
    });
  }

  void _showLockedOverlayAfterTap() {
    if (!mounted || !_isScreenLocked) {
      return;
    }
    _lockedOverlayHideTimer?.cancel();
    setState(() {
      _showLockedOverlay = true;
    });
    _lockedOverlayHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_isScreenLocked) {
        return;
      }
      setState(() {
        _showLockedOverlay = false;
      });
    });
  }

  /// A round white button over the video. [emphasized] fills it white, for
  /// play/pause and for a switch that is on; [filled] gives it a glass circle;
  /// [label] puts a short name under it.
  Widget _fullscreenActionButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double size = 48,
    bool emphasized = false,
    bool filled = false,
    String? label,
  }) {
    // A labelled action is a compact 40 dp button so its name sits right
    // under the icon.
    final double box = label == null ? size : 40;
    final Widget button = IconButton(
      key: key,
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        minimumSize: Size.square(box),
        fixedSize: Size.square(box),
        tapTargetSize: label == null
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
        backgroundColor: emphasized
            ? LtColors.primary
            : filled
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.transparent,
        side: filled
            ? BorderSide(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.transparent,
        disabledForegroundColor: Colors.white38,
        highlightColor: Colors.white24,
      ),
      icon: Icon(icon, size: label == null ? size * 0.52 : 24),
    );
    if (label == null) {
      return button;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        button,
        // Every label gets the same one-line box in an equal slot, so the
        // icons share one line and the labels one size.
        Transform.translate(
          offset: const Offset(0, -3),
          child: SizedBox(
            height: _fullscreenLabelHeight,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: onPressed == null
                    ? Colors.white38
                    : Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration value) {
    final Duration normalized = value < Duration.zero ? Duration.zero : value;
    final int totalSeconds = normalized.inSeconds;
    final int minutes = (totalSeconds ~/ 60) % 60;
    final int seconds = totalSeconds % 60;
    final int hours = totalSeconds ~/ 3600;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  bool _isPlaybackCompleted(PlayerUiState? state) {
    if (state == null || state.duration <= Duration.zero) {
      return false;
    }
    return state.position >= state.duration;
  }

  Future<void> _onPlaybackCompleted({
    required PlayerController controller,
  }) async {
    bool showNotes = false;
    try {
      showNotes = await ref
          .read(notesRepositoryProvider)
          .isPostViewingVideo(widget.videoId);
    } catch (_) {
      showNotes = false;
    }
    if (!mounted) {
      return;
    }
    if (showNotes) {
      await showPostViewingNotes(
        context: context,
        videoId: widget.videoId,
        title: (widget.videoTitle ?? '').trim(),
      );
      if (!mounted) {
        return;
      }
    }
    await _startDeleteFlow(controller: controller, allowRestart: true);
  }

  Future<void> _startDeleteFlow({
    required PlayerController controller,
    bool allowRestart = false,
  }) async {
    if (_isDeleteInProgress || _isDeleteDialogVisible) {
      return;
    }
    final DownloadItem? downloadItem = await ref
        .read(localDownloadsRepositoryProvider)
        .findByVideoId(widget.videoId);
    final bool canDeleteLocal =
        downloadItem?.status == DownloadStatus.completed;
    _isDeleteDialogVisible = true;
    final _PlayerDeleteAction? action = await _showDeleteDialog(
      canDeleteLocal: canDeleteLocal,
      allowRestart: allowRestart,
    );
    _isDeleteDialogVisible = false;
    if (!mounted || action == null || action == _PlayerDeleteAction.cancel) {
      return;
    }
    if (action == _PlayerDeleteAction.restart) {
      await controller.seek(Duration.zero, trackNavigation: false);
      await controller.play();
      return;
    }
    await _runDeleteAction(controller: controller, action: action);
  }

  Future<_PlayerDeleteAction?> _showDeleteDialog({
    required bool canDeleteLocal,
    required bool allowRestart,
  }) {
    return showDialog<_PlayerDeleteAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Удалить файл?'),
          content:
              widget.videoTitle == null || widget.videoTitle!.trim().isEmpty
                  ? null
                  : Text(widget.videoTitle!.trim()),
          actions: <Widget>[
            if (canDeleteLocal)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PlayerDeleteAction.localOnly),
                child: const Text('Локально'),
              ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_PlayerDeleteAction.serverOnly),
              child: const Text('С сервера'),
            ),
            if (canDeleteLocal)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PlayerDeleteAction.everywhere),
                child: const Text('Отовсюду'),
              ),
            if (allowRestart)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PlayerDeleteAction.restart),
                child: const Text('С начала'),
              ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_PlayerDeleteAction.cancel),
              child: const Text('Нет'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runDeleteAction({
    required PlayerController controller,
    required _PlayerDeleteAction action,
  }) async {
    setState(() {
      _isDeleteInProgress = true;
    });
    try {
      await controller.pause();
      final CatalogRepository catalogRepository = ref.read(
        catalogRepositoryProvider,
      );
      switch (action) {
        case _PlayerDeleteAction.localOnly:
          final Failure? localFailure = await catalogRepository.deleteLocal(
            widget.videoId,
          );
          if (localFailure != null) {
            _showDeleteFailure(localFailure.message);
            return;
          }
          if (mounted) {
            Navigator.of(context).pop(PlayerNavigationResult.deletedLocal);
          }
          return;
        case _PlayerDeleteAction.serverOnly:
          final Failure? serverFailure = await catalogRepository.deleteServer(
            widget.videoId,
          );
          if (serverFailure != null) {
            _showDeleteFailure(serverFailure.message);
            return;
          }
          if (mounted) {
            Navigator.of(context).pop(PlayerNavigationResult.deletedServer);
          }
          return;
        case _PlayerDeleteAction.everywhere:
          final Failure? serverFailure = await catalogRepository.deleteServer(
            widget.videoId,
          );
          if (serverFailure != null) {
            _showDeleteFailure(
              'Удаление с сервера не удалось: ${serverFailure.message}',
            );
            return;
          }
          final Failure? localFailure = await catalogRepository.deleteLocal(
            widget.videoId,
          );
          if (localFailure != null) {
            _showDeleteFailure(
              'Видео удалено с сервера, но локальное удаление не удалось: ${localFailure.message}',
            );
            return;
          }
          if (mounted) {
            Navigator.of(context).pop(PlayerNavigationResult.deletedEverywhere);
          }
          return;
        case _PlayerDeleteAction.restart:
        case _PlayerDeleteAction.cancel:
          return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleteInProgress = false;
        });
      }
    }
  }

  void _showDeleteFailure(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _PlayerDeleteAction {
  restart,
  localOnly,
  serverOnly,
  everywhere,
  cancel,
}

/// This page's video player, as a Cast Session sees it.
///
/// It reaches the player through the page's own provider reads rather than holding the controller,
/// because the player belongs to the page and is thrown away with it. The page unbinds this on
/// dispose, so nothing here is ever called once that is no longer true.
///
/// Both halves of a Cast Session use it. On a phone that is casting, a Handoff reads the latest
/// position through it and releases playback through it. On a Receiver that is being cast to, it
/// is the player the commands from the phone actually drive - the very same operations a person
/// standing at the Receiver performs with its own remote.
class _PlayerCastLocalPlayer implements CastLocalPlayer {
  _PlayerCastLocalPlayer({
    required this.readState,
    required this.readVolume,
    required this.pausePlayback,
    required this.resumePlayback,
    required this.seekPlayback,
    required this.setVolume,
  });

  final PlayerUiState Function() readState;

  /// This installation's player volume. It is not part of the player's own state because it
  /// outlives any one video, but it is part of what a Receiver reports about itself.
  final double Function() readVolume;
  final Future<void> Function() pausePlayback;
  final Future<void> Function() resumePlayback;
  final Future<void> Function(Duration position) seekPlayback;
  final Future<void> Function(double volume) setVolume;

  /// Everything a Cast Session can say about this player at one instant.
  ///
  /// A Receiver is Playback Authority, so this is the whole of what the phone is going to render:
  /// which video, where in it, how long it is, playing or paused, waiting for data, finished, and
  /// how loud. It is read from the player itself rather than from what anybody asked it to do, which
  /// is why a person using the Receiver's own remote and a phone sending a command both end up
  /// described here.
  @override
  CastLocalPlayback? readPlayback() {
    final PlayerUiState state = readState();
    final Duration duration = state.duration;
    return CastLocalPlayback(
      videoId: state.videoId,
      position: state.position,
      isPlaying: state.isPlaying,
      duration: duration,
      // A player that has not finished loading is not showing the video either, so the two read as
      // one thing to the viewer waiting for it.
      isBuffering: state.isLoading || state.isBuffering,
      isCompleted: duration > Duration.zero && state.position >= duration,
      volume: readVolume(),
    );
  }

  @override
  bool get isReady {
    final PlayerUiState state = readState();
    return !state.isLoading && state.errorMessage == null;
  }

  @override
  Future<void> releasePlayback() => pausePlayback();

  @override
  Future<void> setPlaying(bool isPlaying) =>
      isPlaying ? resumePlayback() : pausePlayback();

  @override
  Future<void> seekTo(Duration position) => seekPlayback(position);

  @override
  Future<void> setPlayerVolume(double volume) => setVolume(volume);
}

/// One action under the player: an icon in a tonal circle with a short label
/// beneath, like the action row of a video app.
class _PlayerAction {
  const _PlayerAction({
    this.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
    this.danger = false,
  });

  final Key? key;
  final IconData icon;
  final String label;
  final String? tooltip;
  final bool enabled;
  final bool selected;
  final bool danger;
  final VoidCallback onPressed;
}

/// The player's secondary actions as equal slots across the screen, so none
/// sits half-hidden on the curved edge. Up to five fit at one label size;
/// beyond that the last ones (copy link, delete) move into «Ещё», a sheet
/// with their full names.
class _PlayerActionStrip extends StatelessWidget {
  const _PlayerActionStrip({required this.actions});

  final List<_PlayerAction> actions;

  // Six actions (link and delete included) fit one row; «Ещё» only past that.
  static const int _maxSlots = 6;

  @override
  Widget build(BuildContext context) {
    final bool overflow = actions.length > _maxSlots;
    final List<_PlayerAction> shown =
        overflow ? actions.sublist(0, _maxSlots - 1) : actions;
    final List<_PlayerAction> rest =
        overflow ? actions.sublist(_maxSlots - 1) : const <_PlayerAction>[];
    return Row(
      key: const Key('player-action-strip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final _PlayerAction action in shown)
          Expanded(child: _PlayerActionButton(action: action)),
        if (overflow)
          Expanded(
            child: _PlayerActionButton(
              action: _PlayerAction(
                key: const Key('player-more-actions'),
                icon: Icons.more_horiz_rounded,
                label: 'Ещё',
                tooltip: 'Ещё действия',
                enabled: true,
                onPressed: () => _showMore(context, rest),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showMore(
    BuildContext context,
    List<_PlayerAction> rest,
  ) {
    final LtPalette palette = LtPalette.of(context);
    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final _PlayerAction action in rest)
                ListTile(
                  key: action.key,
                  enabled: action.enabled,
                  leading: Icon(
                    action.icon,
                    color: action.danger ? palette.danger.strong : null,
                  ),
                  title: Text(
                    action.tooltip ?? action.label,
                    style: action.danger
                        ? TextStyle(color: palette.danger.strong)
                        : null,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    action.onPressed();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the video plays from, a small line under the title.
class _SourceLabel extends StatelessWidget {
  const _SourceLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PlayerActionButton extends StatelessWidget {
  const _PlayerActionButton({required this.action});

  final _PlayerAction action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final LtPalette palette = LtPalette.of(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color foreground = action.danger
        ? palette.danger.strong
        : action.selected
            ? (dark ? Colors.white : colors.onPrimary)
            : (dark ? const Color(0xFFC9CEFF) : colors.onSurface);
    final Color background = action.selected
        ? LtColors.primary
        : (dark ? const Color(0xFF1E2446) : colors.primaryContainer);
    return Opacity(
      opacity: action.enabled ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Column(
          children: <Widget>[
            IconButton(
              key: action.key,
              tooltip: action.tooltip ?? action.label,
              onPressed: action.enabled ? action.onPressed : null,
              style: IconButton.styleFrom(
                backgroundColor: background,
                disabledBackgroundColor: background,
                foregroundColor: foreground,
                disabledForegroundColor: foreground,
                minimumSize: const Size(40, 40),
                fixedSize: const Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: Icon(action.icon, size: 21),
            ),
            const SizedBox(height: 2),
            // One size for every label; on a very narrow screen the longest
            // («Просмотрено») scales down rather than being cut.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                action.label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: action.danger
                          ? palette.danger.strong
                          : colors.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A time such as «03:35» in a small tonal pill, the start of a list row.
class _TimeBadge extends StatelessWidget {
  const _TimeBadge({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color fill = highlighted
        ? LtColors.primary
        : (dark ? const Color(0xFF1E2446) : colors.primaryContainer);
    final Color ink = highlighted
        ? Colors.white
        : (dark ? const Color(0xFFAEB7FF) : colors.onPrimaryContainer);
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(LtSizes.radiusS),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: ink,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A chapter in the list under the player; the one playing now stands out.
class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.label,
    required this.time,
    required this.isCurrent,
    required this.isPast,
    required this.onTap,
  });

  final String label;
  final String time;
  final bool isCurrent;
  final bool isPast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      selected: isCurrent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      selectedTileColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E2446)
          : const Color(0xFFDDE2FB),
      leading: _TimeBadge(label: time, highlighted: isCurrent),
      title: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
          color: isCurrent ? colors.onPrimaryContainer : colors.onSurface,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
      ),
      trailing: isCurrent
          ? Icon(Icons.graphic_eq_rounded, color: colors.primary, size: 20)
          : isPast
              ? Icon(
                  Icons.check_rounded,
                  color: colors.onSurfaceVariant,
                  size: 18,
                )
              : null,
      onTap: onTap,
    );
  }
}

/// A dark fade behind fullscreen controls at the top or bottom edge, so white
/// controls read over any picture without a box around them.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top, required this.child});

  final bool top;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const <Color>[Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: child,
    );
  }
}

/// A slim bar under the pinned video, shown once the full controls have
/// scrolled away: play/pause, the time and a coral progress line.
class _MiniPlaybackBar extends StatelessWidget {
  static ButtonStyle _miniDisc(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton.styleFrom(
      fixedSize: const Size.square(40),
      minimumSize: const Size.square(40),
      backgroundColor: dark
          ? const Color(0xFF1E2446)
          : Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: dark
          ? const Color(0xFFC9CEFF)
          : Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }

  const _MiniPlaybackBar({
    required this.isPlaying,
    required this.enabled,
    required this.position,
    required this.duration,
    required this.format,
    required this.onToggle,
    required this.onSeekBy,
    this.chapter,
  });

  final bool isPlaying;
  final bool enabled;
  final Duration position;
  final Duration duration;
  final String? chapter;
  final String Function(Duration) format;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeekBy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double fraction = duration.inMilliseconds <= 0
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble();
    return Material(
      key: const Key('player-mini-bar'),
      color: colors.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LinearProgressIndicator(
            value: fraction,
            minHeight: 3,
            color: LtColors.coral,
            backgroundColor: colors.onSurface.withValues(alpha: 0.12),
            borderRadius: BorderRadius.zero,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: <Widget>[
                // The same solid cobalt play/pause as the full controls.
                IconButton.filled(
                  onPressed: enabled ? onToggle : null,
                  tooltip: isPlaying ? 'Пауза' : 'Воспроизвести',
                  style: IconButton.styleFrom(
                    backgroundColor: LtColors.primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size.square(40),
                    minimumSize: const Size.square(40),
                  ),
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${format(position)} / ${format(duration)}',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      if (chapter != null)
                        Text(
                          chapter!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: enabled
                      ? () => onSeekBy(const Duration(seconds: -10))
                      : null,
                  tooltip: 'Назад на 10 с',
                  style: _miniDisc(context),
                  icon: const Icon(Icons.replay_10_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: enabled
                      ? () => onSeekBy(const Duration(seconds: 10))
                      : null,
                  tooltip: 'Вперёд на 10 с',
                  style: _miniDisc(context),
                  icon: const Icon(Icons.forward_10_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of equal columns, each child centred in its own: the transport
/// circles sit right above the action discs below them.
class _EqualSlots extends StatelessWidget {
  const _EqualSlots({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final Widget child in children)
          Expanded(child: Center(child: child)),
      ],
    );
  }
}
