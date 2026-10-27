import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../app_updates/apk_update_controller.dart';
import '../../../core/errors/failure.dart';
import '../../../core/network/network_status.dart';
import '../../../shared/widgets/state_feedback.dart';
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
import 'player_controller.dart';
import 'player_navigation_result.dart';

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

  /// This page's local player, offered to the Cast Session while the page owns one. A Handoff reads
  /// the latest position through it and releases playback through it, without the Cast Controller
  /// ever having to know which screen is showing a video.
  CastPlaybackBinding? _castBinding;
  _PlayerCastLocalPlayer? _castLocalPlayer;

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
    _updatePlaybackSurfaces?.leave();
    WidgetsBinding.instance.removeObserver(this);
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
        appBar: AppBar(title: const Text('Player')),
        body: const Center(child: Text('Invalid video id')),
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
          _startDeleteFlow(
            videoId: videoId,
            controller: controller,
            allowRestart: true,
          ),
        );
      });
    });
    final VideoPlayerController? videoController = controller.videoController;
    final List<VideoTimestamp> timestamps = ref
        .read(extractTimestampsUseCaseProvider)
        .call(widget.videoDescription ?? '');
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

    return Scaffold(
      appBar: AppBar(title: Text(_resolvedTitle(videoId))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (videoController != null && videoController.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: videoController.value.aspectRatio > 0
                        ? videoController.value.aspectRatio
                        : (16 / 9),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        VideoPlayer(videoController),
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: state.errorMessage != null
                                ? null
                                : () => unawaited(controller.togglePlayback()),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        if (state.isBuffering)
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: ColoredBox(
                                color: Color(0x55000000),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: state.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Video stream is unavailable'),
              ),
            if (isOffline) ...<Widget>[
              const SizedBox(height: 8),
              StateFeedbackBanner(
                message: state.sourceKind == PlayableSourceKind.localFile
                    ? 'Offline mode: local playback is available.'
                    : 'Offline mode: remote playback may be unavailable.',
                tone: StateFeedbackTone.warning,
              ),
            ],
            if (state.isRecovering) ...<Widget>[
              const SizedBox(height: 8),
              const StateFeedbackBanner(
                message: 'Playback interrupted. Reconnecting stream...',
                tone: StateFeedbackTone.warning,
              ),
            ],
            const SizedBox(height: 8),
            if (state.errorMessage != null)
              StateFeedbackBanner(
                message: state.errorMessage!,
                tone: StateFeedbackTone.error,
              ),
            if (state.isLoading) ...<Widget>[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 8,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                    ),
                    child: Slider(
                      min: 0,
                      max: maxSeconds,
                      value: positionSeconds,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      onChanged: state.errorMessage != null
                          ? null
                          : (double value) {
                              setState(() {
                                _dragSeconds = value;
                              });
                            },
                      onChangeEnd: state.errorMessage != null
                          ? null
                          : (double value) {
                              setState(() {
                                _dragSeconds = null;
                              });
                              unawaited(
                                controller.seek(
                                  Duration(
                                    milliseconds: (value * 1000).round(),
                                  ),
                                ),
                              );
                            },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _sourceStatusLabel(state.sourceKind),
                  child: Icon(
                    _sourceStatusIcon(state.sourceKind),
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Text(_formatDuration(state.position)),
                const Spacer(),
                Text(_formatDuration(state.duration)),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildSecondaryControlButton(
                    icon: Icons.replay_10,
                    tooltip: 'Back 10s',
                    enabled: state.errorMessage == null,
                    onPressed: () => unawaited(
                      controller.seekRelative(const Duration(seconds: -10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 84,
                    child: FilledButton.icon(
                      onPressed: state.errorMessage != null
                          ? null
                          : () => unawaited(controller.togglePlayback()),
                      icon: Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      label: Text(state.isPlaying ? 'Pause' : 'Play'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSecondaryControlButton(
                    icon: Icons.forward_10,
                    tooltip: 'Forward 10s',
                    enabled: state.errorMessage == null,
                    onPressed: () => unawaited(
                      controller.seekRelative(const Duration(seconds: 10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSecondaryControlButton(
                    icon: Icons.skip_next,
                    tooltip: 'Next chapter',
                    enabled:
                        state.errorMessage == null && timestamps.isNotEmpty,
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
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildSecondaryControlButton(
                  icon: Icons.bookmark_add_outlined,
                  tooltip: 'Add bookmark',
                  enabled: state.errorMessage == null && !_isDeleteInProgress,
                  onPressed: () => unawaited(controller.addManualBookmark()),
                ),
                if (state.sourceKind != PlayableSourceKind.localFile &&
                    !_downloadStartedForCurrentVideo)
                  _buildSecondaryControlButton(
                    icon: Icons.download_outlined,
                    tooltip: remoteActionsDisabled
                        ? 'Available after reconnect'
                        : 'Download',
                    enabled: state.errorMessage == null &&
                        !remoteActionsDisabled &&
                        !_isDeleteInProgress,
                    onPressed: () => unawaited(_downloadCurrentVideo(videoId)),
                  ),
                _buildSecondaryControlButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  enabled: state.errorMessage == null && !_isDeleteInProgress,
                  onPressed: () => unawaited(
                    _startDeleteFlow(
                      videoId: videoId,
                      controller: controller,
                    ),
                  ),
                ),
                _buildSecondaryControlButton(
                  icon: Icons.fullscreen,
                  tooltip: 'Fullscreen',
                  enabled: state.errorMessage == null && !_isDeleteInProgress,
                  onPressed: () => unawaited(_openFullscreen(videoId: videoId)),
                ),
                _buildSecondaryControlButton(
                  icon: Icons.share_outlined,
                  tooltip: 'Share',
                  enabled: state.errorMessage == null && !_isDeleteInProgress,
                  onPressed: () => unawaited(_shareVideo(videoId)),
                ),
              ],
            ),
            if (state.navigationEntries.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              ExpansionTile(
                key: const PageStorageKey<String>('player-navigation'),
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'Navigation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                children: <Widget>[
                  SizedBox(
                    height: math.min(state.navigationEntries.length, 3) * 72.0,
                    child: ListView.builder(
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
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 56,
                            child: Text(
                              _formatDuration(entry.fromPosition),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          title: Text(
                            'Back to ${_formatDuration(entry.fromPosition)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'Jumped to ${_formatDuration(entry.toPosition)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.undo),
                          onTap: state.errorMessage != null
                              ? null
                              : () => unawaited(
                                  controller.seekToNavigationOrigin(entry.id),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (state.bookmarks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Text(
                    'Bookmarks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...state.bookmarks.map(
                (bookmark) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(
                    width: 56,
                    child: Text(
                      _formatDuration(bookmark.position),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  title: Text(
                    bookmark.caption.isEmpty ? 'Bookmark' : bookmark.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: bookmark.isPendingSync
                      ? const Text('Pending sync')
                      : null,
                  trailing: IconButton(
                    onPressed: state.errorMessage != null
                        ? null
                        : () =>
                            unawaited(controller.deleteBookmark(bookmark.id)),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete bookmark',
                  ),
                  onTap: state.errorMessage != null
                      ? null
                      : () => unawaited(controller.seek(bookmark.position)),
                ),
              ),
            ],
            if (timestamps.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              ExpansionTile(
                key: const PageStorageKey<String>('player-timestamps'),
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Row(
                  children: <Widget>[
                    Text(
                      'Timestamps',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: state.errorMessage != null
                          ? null
                          : () => unawaited(
                              _jumpToNearestTimestamp(
                                context: context,
                                controller: controller,
                                currentPosition: state.position,
                                timestamps: timestamps,
                                jumpToNearestTimestampUseCase:
                                    jumpToNearestTimestampUseCase,
                              ),
                            ),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Next'),
                    ),
                  ],
                ),
                children: <Widget>[
                  const SizedBox(height: 6),
                  ...timestamps.map(
                    (VideoTimestamp timestamp) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 56,
                        child: Text(
                          _formatDuration(timestamp.position),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: state.position >= timestamp.position
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                      title: Text(
                        timestamp.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: state.errorMessage != null
                          ? null
                          : () =>
                                unawaited(controller.seek(timestamp.position)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            CastEntryPoint(videoId: videoId),
          ],
        ),
      ),
    );
  }

  Future<void> _openFullscreen({required int videoId}) async {
    setState(() {
      _isFullscreenOpen = true;
    });
    final PlayerNavigationResult? result = await Navigator.of(context).push(
      MaterialPageRoute<PlayerNavigationResult>(
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
    if (result != null) {
      Navigator.of(context).pop(result);
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
            started ? 'Download queued' : 'Unable to queue download',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to queue download')));
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
    return 'Player #$videoId';
  }

  bool _isPlaybackCompleted(PlayerUiState? state) {
    if (state == null || state.duration <= Duration.zero) {
      return false;
    }
    return state.position >= state.duration;
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
      PlayableSourceKind.localFile => Icons.sd_storage_outlined,
      PlayableSourceKind.remoteUrl => Icons.cloud_outlined,
      null => Icons.hourglass_bottom_outlined,
    };
  }

  String _sourceStatusLabel(PlayableSourceKind? sourceKind) {
    return switch (sourceKind) {
      PlayableSourceKind.localFile => 'Local file',
      PlayableSourceKind.remoteUrl => 'Remote stream',
      null => 'Preparing...',
    };
  }

  Widget _buildSecondaryControlButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      icon: Icon(icon, size: 30),
      style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
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
  }

  @override
  void dispose() {
    _lockedOverlayHideTimer?.cancel();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
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
        unawaited(_startDeleteFlow(controller: controller, allowRestart: true));
      });
    });
    final VideoPlayerController? videoController = controller.videoController;
    final List<VideoTimestamp> timestamps = ref
        .read(extractTimestampsUseCaseProvider)
        .call(widget.videoDescription ?? '');
    final JumpToNearestTimestampUseCase jumpToNearestTimestampUseCase =
        ref.read(jumpToNearestTimestampUseCaseProvider);
    final double maxSeconds =
        math.max(state.duration.inMilliseconds / 1000, 1).toDouble();
    final double positionSeconds =
        (_dragSeconds ?? state.position.inMilliseconds / 1000)
            .clamp(0, maxSeconds)
            .toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: GestureDetector(
          key: const Key('fullscreen-player-gesture-area'),
          behavior: HitTestBehavior.opaque,
          onTap: _isScreenLocked
              ? _showLockedOverlayAfterTap
              : () => unawaited(controller.togglePlayback()),
          onDoubleTap: _isScreenLocked
              ? null
              : () {
                  setState(() {
                    _showControls = !_showControls;
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
              if (state.isBuffering)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Color(0x44000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
              if (_isScreenLocked ? _showLockedOverlay : _showControls)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x33000000),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          if (!_isScreenLocked)
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 16,
                              runSpacing: 16,
                              children: <Widget>[
                                _fullscreenActionButton(
                                  icon: Icons.replay_10,
                                  tooltip: 'Back 10s',
                                  onPressed: () => unawaited(
                                    controller.seekRelative(
                                      const Duration(seconds: -10),
                                    ),
                                  ),
                                ),
                                _fullscreenActionButton(
                                  icon: state.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  tooltip: state.isPlaying ? 'Pause' : 'Play',
                                  onPressed: controller.togglePlayback,
                                ),
                                _fullscreenActionButton(
                                  icon: Icons.forward_10,
                                  tooltip: 'Forward 10s',
                                  onPressed: () => unawaited(
                                    controller.seekRelative(
                                      const Duration(seconds: 10),
                                    ),
                                  ),
                                ),
                                _fullscreenActionButton(
                                  icon: Icons.bookmark_add_outlined,
                                  tooltip: 'Add bookmark',
                                  onPressed: _isDeleteInProgress
                                      ? null
                                      : () => unawaited(
                                          controller.addManualBookmark()),
                                ),
                                _fullscreenActionButton(
                                  icon: Icons.skip_next,
                                  tooltip: 'Next section',
                                  onPressed: _isDeleteInProgress
                                      ? null
                                      : () => unawaited(
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
                                _fullscreenActionButton(
                                  icon: Icons.undo,
                                  tooltip: 'Back',
                                  onPressed: _isDeleteInProgress ||
                                          state.navigationEntries.isEmpty
                                      ? null
                                      : () => unawaited(
                                            controller.seekToNavigationOrigin(
                                              state.navigationEntries.last.id,
                                            ),
                                          ),
                                ),
                                _fullscreenActionButton(
                                  icon: Icons.stop_screen_share_outlined,
                                  tooltip: 'Pause and minimize',
                                  onPressed: _isDeleteInProgress
                                      ? null
                                      : () => unawaited(
                                            _pauseAndMinimize(controller),
                                          ),
                                ),
                                _fullscreenActionButton(
                                  icon: Icons.picture_in_picture_alt_outlined,
                                  tooltip: 'Minimize',
                                  onPressed: _isDeleteInProgress
                                      ? null
                                      : () => unawaited(_minimizeApp()),
                                ),
                                _fullscreenActionButton(
                                  icon: Icons.fullscreen_exit,
                                  tooltip: 'Exit fullscreen',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                ),
                              ],
                            ),
                          if (!_isScreenLocked) const SizedBox(height: 14),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              disabledActiveTrackColor: Colors.white,
                              disabledInactiveTrackColor: Colors.white24,
                              disabledThumbColor: Colors.white,
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
                                            milliseconds: (value * 1000)
                                                .round(),
                                          ),
                                        ),
                                      );
                                    },
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              Text(
                                _formatDuration(state.position),
                                style: const TextStyle(color: Colors.white),
                              ),
                              const Spacer(),
                              Text(
                                _formatDuration(state.duration),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isScreenLocked)
                const Positioned.fill(
                  child: AbsorbPointer(
                    child: SizedBox.expand(),
                  ),
                ),
              if (_isScreenLocked ? _showLockedOverlay : _showControls)
                SafeArea(
                  minimum: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: _fullscreenActionButton(
                      icon: _isScreenLocked
                          ? Icons.lock_open
                          : Icons.lock_outline,
                      tooltip:
                          _isScreenLocked ? 'Unlock screen' : 'Lock screen',
                      onPressed: _toggleScreenLock,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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

  Future<void> _pauseAndMinimize(PlayerController controller) async {
    await controller.pause();
    await _minimizeApp();
  }

  void _toggleScreenLock() {
    final bool wasLocked = _isScreenLocked;
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

  Widget _fullscreenActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(minimumSize: const Size(88, 88)),
      icon: Icon(icon, size: 44),
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
