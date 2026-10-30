import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../transcript/presentation/transcript_panel.dart';
import '../../player/domain/player_models.dart';
import '../../sync/domain/sync_models.dart';
import '../domain/cast_session_models.dart';
import 'cast_controller.dart';

/// Remote Control Mode: the whole of what the phone is while the Receiver is playing.
///
/// It owns no video player, which is the point of it. What it shows instead is the Receiver's
/// confirmed state - where playback is, how long the video is, playing, paused, buffering or
/// finished - and the controls that act on it: play and pause, seek, the Receiver's own player
/// volume, the video's timestamps, and the way back to watching here.
///
/// Everything it renders comes from [CastUiState.confirmedState] and nothing else. A slider being
/// dragged moves under the finger because a control that did not would be unusable, but letting go
/// of it sends a command and hands the value straight back to the Receiver: nothing here is applied
/// optimistically, so a command the Receiver never applied never shows up as having happened. The
/// phone is allowed to lag by the reporting interval instead.
///
/// A Receiver inside its one-minute reconnect window is said so and nothing more: the mode stays,
/// the last confirmed state stays on screen, and the way back to watching here stays offered, so a
/// viewer who would rather not wait the minute out simply takes playback back.
///
/// Downloads, deletion and local navigation remain on the ordinary player surface. Transcript
/// selections can explicitly create bookmarks for the confirmed Receiver video; transcript seeks
/// are sent to the Receiver like the other playback controls.
class RemoteControlModeView extends ConsumerStatefulWidget {
  const RemoteControlModeView({
    super.key,
    this.timestamps = const <VideoTimestamp>[],
  });

  static const String title = 'Playing on another device';

  /// Shown while the session exists but the API has not named the Receiver.
  static const String unknownReceiverName = 'Unnamed Receiver';

  /// The way back: playback stops on the Receiver and continues here. It is also the way out of
  /// waiting for a Receiver that has dropped off, which is why it is never disabled.
  static const String returnHandoffLabel = 'Watch on this phone';

  /// Shown while a participant is inside its one-minute reconnect window.
  static const String reconnectingLabel = 'Reconnecting to the Receiver';

  static const String timestampsTitle = 'Timestamps';

  /// What the Receiver says it is doing, in the order a viewer cares about it.
  static const String waitingLabel = 'Waiting for the Receiver';
  static const String bufferingLabel = 'Buffering';
  static const String finishedLabel = 'Finished';
  static const String playingLabel = 'Playing';
  static const String pausedLabel = 'Paused';

  static const Key receiverNameKey = Key('remote-control-receiver-name');
  static const Key connectionStatusKey = Key('remote-control-connection-status');
  static const Key playbackStatusKey = Key('remote-control-playback-status');
  static const Key reconnectingKey = Key('remote-control-reconnecting');
  static const Key positionKey = Key('remote-control-position');
  static const Key durationKey = Key('remote-control-duration');
  static const Key seekSliderKey = Key('remote-control-seek');
  static const Key playPauseButtonKey = Key('remote-control-play-pause');
  static const Key volumeSliderKey = Key('remote-control-volume');
  static const Key returnHandoffButtonKey =
      Key('remote-control-return-handoff');

  /// The video's timestamps, as the screen that knows the description read them.
  ///
  /// Selecting one is an absolute seek on the Receiver and nothing else, so chapter-like navigation
  /// keeps working exactly as it does locally.
  final List<VideoTimestamp> timestamps;

  /// The key of the row for the timestamp at [position], so a test can tap one particular chapter.
  static Key timestampKey(Duration position) =>
      Key('remote-control-timestamp-${position.inMilliseconds}');

  /// How the connection to the API reads to a person. The Receiver is reachable only through it,
  /// so this is what tells someone whether the remote still works.
  static String connectionLabel(SyncConnectionState state) {
    switch (state) {
      case SyncConnectionState.disconnected:
        return 'Disconnected';
      case SyncConnectionState.connecting:
        return 'Connecting';
      case SyncConnectionState.connected:
        return 'Connected';
      case SyncConnectionState.reconnecting:
        return 'Reconnecting';
    }
  }

  /// What the Receiver is doing, as it last confirmed it. Buffering comes first because
  /// a Receiver that is waiting for data is not showing the video whatever else is true of it.
  static String playbackLabel(CastPlaybackState? confirmed) {
    if (confirmed == null) {
      return waitingLabel;
    }
    if (confirmed.isBuffering) {
      return bufferingLabel;
    }
    if (confirmed.isCompleted) {
      return finishedLabel;
    }
    return confirmed.isPlaying ? playingLabel : pausedLabel;
  }

  @override
  ConsumerState<RemoteControlModeView> createState() =>
      _RemoteControlModeViewState();
}

class _RemoteControlModeViewState extends ConsumerState<RemoteControlModeView> {
  /// Where a finger is on the seek bar, while it is on it. It is not a guess about the Receiver:
  /// letting go clears it and the bar goes back to showing the confirmed position, whether or not
  /// the seek that was sent has landed yet.
  double? _dragSeconds;

  /// The same, for the Receiver's player volume.
  double? _dragVolume;

  @override
  Widget build(BuildContext context) {
    final CastUiState state = ref.watch(castControllerProvider);
    final CastController controller = ref.read(castControllerProvider.notifier);
    final CastPlaybackState? confirmed = state.confirmedState;

    final String receiverName = (state.castReceiverName ?? '').trim();
    final String name = receiverName.isEmpty
        ? RemoteControlModeView.unknownReceiverName
        : receiverName;

    final Duration position = confirmed?.position ?? Duration.zero;
    final Duration duration = confirmed?.duration ?? Duration.zero;
    final double maxSeconds =
        math.max(duration.inMilliseconds / 1000, 1).toDouble();
    final double positionSeconds =
        (_dragSeconds ?? position.inMilliseconds / 1000)
            .clamp(0, maxSeconds)
            .toDouble();
    final double volume =
        (_dragVolume ?? confirmed?.volume ?? 1.0).clamp(0.0, 1.0).toDouble();

    // Until the Receiver has confirmed a state there is nothing to act on, and nothing to act on it
    // with: a control that sent a command into a session that has no confirmed playback would be
    // asking the Receiver to change something neither device can describe.
    final bool canControl = confirmed != null;
    final bool isPlaying = confirmed?.isPlaying ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.cast_connected),
            const SizedBox(width: 8),
            Text(
              RemoteControlModeView.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListTile(
          key: RemoteControlModeView.receiverNameKey,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tv),
          title: Text(name),
          subtitle: Text(
            RemoteControlModeView.connectionLabel(state.connectionState),
            key: RemoteControlModeView.connectionStatusKey,
          ),
        ),
        Text(
          RemoteControlModeView.playbackLabel(confirmed),
          key: RemoteControlModeView.playbackStatusKey,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        // A participant is inside its minute. Nothing here is taken away for it: what the Receiver
        // last confirmed is still the truth about the video, the controls still read it, and the way
        // back to watching here is still offered - which is how a viewer stops waiting rather than
        // sitting out the minute.
        if (state.isSessionReconnecting) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            RemoteControlModeView.reconnectingLabel,
            key: RemoteControlModeView.reconnectingKey,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            key: RemoteControlModeView.seekSliderKey,
            min: 0,
            max: maxSeconds,
            value: positionSeconds,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            onChanged: canControl
                ? (double value) {
                    setState(() {
                      _dragSeconds = value;
                    });
                  }
                : null,
            onChangeEnd: canControl
                ? (double value) {
                    setState(() {
                      _dragSeconds = null;
                    });
                    unawaited(
                      controller.seekReceiver(
                        Duration(milliseconds: (value * 1000).round()),
                      ),
                    );
                  }
                : null,
          ),
        ),
        Row(
          children: <Widget>[
            Text(
              _formatDuration(position),
              key: RemoteControlModeView.positionKey,
            ),
            const Spacer(),
            Text(
              _formatDuration(duration),
              key: RemoteControlModeView.durationKey,
            ),
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
                enabled: canControl,
                onPressed: () => unawaited(
                  controller.seekReceiver(
                    _shifted(
                      position: position,
                      duration: duration,
                      by: const Duration(seconds: -10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 84,
                child: FilledButton.icon(
                  key: RemoteControlModeView.playPauseButtonKey,
                  onPressed: canControl
                      ? () =>
                          unawaited(controller.setReceiverPlaying(!isPlaying))
                      : null,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(isPlaying ? 'Pause' : 'Play'),
                ),
              ),
              const SizedBox(width: 8),
              _buildSecondaryControlButton(
                icon: Icons.forward_10,
                tooltip: 'Forward 10s',
                enabled: canControl,
                onPressed: () => unawaited(
                  controller.seekReceiver(
                    _shifted(
                      position: position,
                      duration: duration,
                      by: const Duration(seconds: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Icon(Icons.volume_down),
            Expanded(
              child: Slider(
                key: RemoteControlModeView.volumeSliderKey,
                min: 0,
                max: 1,
                value: volume,
                onChanged: canControl
                    ? (double value) {
                        setState(() {
                          _dragVolume = value;
                        });
                      }
                    : null,
                onChangeEnd: canControl
                    ? (double value) {
                        setState(() {
                          _dragVolume = null;
                        });
                        unawaited(controller.setReceiverVolume(value));
                      }
                    : null,
              ),
            ),
            const Icon(Icons.volume_up),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            key: RemoteControlModeView.returnHandoffButtonKey,
            onPressed: () => unawaited(controller.returnHandoff()),
            icon: const Icon(Icons.phone_android),
            label: const Text(RemoteControlModeView.returnHandoffLabel),
          ),
        ),
        if (confirmed != null)
          TranscriptPanel(
            videoId: confirmed.videoId,
            showCaptionsControl: false,
            onSeek: controller.seekReceiver,
            onBookmark: (position, caption) =>
                ref.read(bookmarksRepositoryProvider).addBookmark(
                      videoId: confirmed.videoId,
                      positionSeconds: position,
                      caption: caption,
                    ),
          ),
        if (widget.timestamps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            RemoteControlModeView.timestampsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          ...widget.timestamps.map(
            (VideoTimestamp timestamp) => ListTile(
              key: RemoteControlModeView.timestampKey(timestamp.position),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 56,
                child: Text(
                  _formatDuration(timestamp.position),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: position >= timestamp.position
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
              // A timestamp is a position in the video, so selecting one is an absolute seek on the
              // Receiver: the phone works out which timestamp it means and sends where that is.
              onTap: canControl
                  ? () => unawaited(controller.seekReceiver(timestamp.position))
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  /// [position] moved by [by], kept inside the video. A Receiver command is absolute, so what the
  /// Receiver is told is where to be rather than how far to jump.
  static Duration _shifted({
    required Duration position,
    required Duration duration,
    required Duration by,
  }) {
    final Duration target = position + by;
    if (target.isNegative) {
      return Duration.zero;
    }
    if (duration > Duration.zero && target > duration) {
      return duration;
    }
    return target;
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
