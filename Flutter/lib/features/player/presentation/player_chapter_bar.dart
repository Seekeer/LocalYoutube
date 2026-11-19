import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../domain/player_models.dart';
import '../domain/video_chapters.dart';

/// The chapters of a video as the server imported them (YouTube Chapters or
/// the description's timestamps). Null when they cannot be had — offline, an
/// older server — and the player falls back to parsing the description.
final videoChaptersProvider =
    FutureProvider.autoDispose.family<List<VideoTimestamp>?, int>(
        (Ref ref, int videoId) async {
  try {
    final Object? data = (await ref.read(dioProvider).get<dynamic>(
              '/files/$videoId',
            ))
        .data;
    return data is Map ? chaptersFromServer(data['chapters']) : null;
  } catch (_) {
    return null;
  }
});

/// Where a [Slider]'s track starts inside the slider: the whole padded width
/// when the slider has a padding, otherwise half of its thumb or overlay.
double sliderTrackInset(SliderThemeData theme, {EdgeInsets? padding}) {
  if (padding != null) {
    return 0;
  }
  final double thumb = (theme.thumbShape ?? const RoundSliderThumbShape())
      .getPreferredSize(true, false)
      .width;
  final double overlay =
      (theme.overlayShape ?? const RoundSliderOverlayShape())
          .getPreferredSize(true, false)
          .width;
  return math.max(thumb, overlay) / 2;
}

/// A chapter bar over a timeline slider, in the slider's width and inset to
/// its track, so each chapter boundary sits over its seek position.
class ChapterTimeline extends StatelessWidget {
  const ChapterTimeline({
    super.key,
    required this.chapterBar,
    required this.slider,
    this.sliderPadding,
    this.merged = false,
  });

  final Widget chapterBar;
  final Widget slider;

  /// The slider's own `padding`, if it has one.
  final EdgeInsets? sliderPadding;

  /// Whether the chapter segments are the slider's track: one timeline, the
  /// slider's thumb riding on the segments, instead of a chapter strip above
  /// a separate seek bar. Only for a video that has chapters; without them the
  /// bar is empty and the slider keeps its own track.
  final bool merged;

  /// The height the slider takes in a merged timeline.
  static const double _mergedSliderHeight = 40;

  /// The chapter bar's segment row, which the slider's thumb is centred on.
  static const double _segmentsHeight = 16;

  @override
  Widget build(BuildContext context) {
    final double inset = sliderTrackInset(
      SliderTheme.of(context),
      padding: sliderPadding,
    );
    final EdgeInsets padding = EdgeInsets.only(
      left: (sliderPadding?.left ?? 0) + inset,
      right: (sliderPadding?.right ?? 0) + inset,
    );
    if (!merged) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(padding: padding, child: chapterBar),
          slider,
        ],
      );
    }
    // The bar's segments sit on the slider's centre line; the slider, drawn
    // without a track, lies on top and takes the drags and taps.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Padding(
          padding: padding.copyWith(
            bottom: (_mergedSliderHeight - _segmentsHeight) / 2,
          ),
          child: chapterBar,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _mergedSliderHeight,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              disabledActiveTrackColor: Colors.transparent,
              disabledInactiveTrackColor: Colors.transparent,
            ),
            child: slider,
          ),
        ),
      ],
    );
  }
}

/// YouTube-style chapter bar above the player's timeline: one segment per
/// chapter with gaps at the boundaries. Hovering a segment or dragging the
/// timeline shows the chapter's title; tapping a segment seeks to its start.
class PlayerChapterBar extends StatefulWidget {
  const PlayerChapterBar({
    super.key,
    required this.chapters,
    required this.duration,
    required this.position,
    required this.onSeek,
    this.isSeeking = false,
    this.enabled = true,
    this.trackColor,
    this.fillColor,
    this.textColor,
    this.compact = false,
  });

  final List<VideoTimestamp> chapters;
  final Duration duration;

  /// The playing position, or where the timeline is being dragged to.
  final Duration position;

  /// The timeline is being dragged: the title of the chapter under it is shown.
  final bool isSeeking;
  final bool enabled;
  final ValueChanged<Duration> onSeek;
  final Color? trackColor;
  final Color? fillColor;
  final Color? textColor;

  /// Fullscreen has little height to give: the bar takes only the segments'
  /// height, and the title floats above them while hovering or seeking.
  final bool compact;

  @override
  State<PlayerChapterBar> createState() => _PlayerChapterBarState();
}

class _PlayerChapterBarState extends State<PlayerChapterBar> {
  int _hovered = -1;

  @override
  Widget build(BuildContext context) {
    final List<ChapterSegment> segments =
        buildChapterSegments(widget.chapters, widget.duration);
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final Color track =
        widget.trackColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.18);
    final Color fill = widget.fillColor ?? theme.colorScheme.primary;
    final TextStyle textStyle = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(color: widget.textColor);

    final int current = chapterSegmentAt(segments, widget.position);
    final int shown = _hovered >= 0 && _hovered < segments.length
        ? _hovered
        : (widget.isSeeking ? current : -1);
    final int titled = shown >= 0 ? shown : current;
    final ChapterSegment? label = titled >= 0 ? segments[titled] : null;

    final Widget? title = label == null ||
            label.title.isEmpty ||
            (widget.compact && shown < 0)
        ? null
        : Text(
            shown >= 0
                ? '${_format(label.start)} · ${label.title}'
                : label.title,
            key: const ValueKey<String>('player-chapter-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: shown >= 0
                ? textStyle.copyWith(fontWeight: FontWeight.w600)
                : textStyle,
          );
    final Widget track16 = SizedBox(
      height: 16,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < segments.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              flex: _flex(segments[i]),
              child: _segment(segments[i], i, i == current, track, fill),
            ),
          ],
        ],
      ),
    );

    if (widget.compact) {
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          track16,
          if (title != null)
            Positioned(left: 0, right: 0, bottom: 16, child: IgnorePointer(child: title)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(height: 18, child: title),
        track16,
      ],
    );
  }

  Widget _segment(
    ChapterSegment segment,
    int index,
    bool isCurrent,
    Color track,
    Color fill,
  ) {
    final bool hovered = index == _hovered;
    final double progress = widget.position <= segment.start
        ? 0
        : widget.position >= segment.end
            ? 1
            : (widget.position - segment.start).inMilliseconds /
                segment.length.inMilliseconds;
    final String title = segment.title.isEmpty ? 'Начало' : segment.title;

    return Semantics(
      button: true,
      selected: isCurrent,
      label: 'Перейти к главе ${_format(segment.start)} $title',
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = index),
        onExit: (_) => setState(() {
          if (_hovered == index) {
            _hovered = -1;
          }
        }),
        child: GestureDetector(
          key: ValueKey<String>('player-chapter-segment-$index'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? () => widget.onSeek(segment.start) : null,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: hovered ? 10 : 6,
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(1),
              ),
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0, 1).toDouble(),
                heightFactor: 1,
                child: ColoredBox(color: fill),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded flex is an int: chapter lengths in tenths of a second keep the
  /// proportions without overflowing for long videos.
  static int _flex(ChapterSegment segment) =>
      (segment.length.inMilliseconds ~/ 100).clamp(1, 1 << 30);

  static String _format(Duration value) {
    final int total = value.inSeconds;
    final int h = total ~/ 3600;
    final int m = (total ~/ 60) % 60;
    final String s = (total % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}
