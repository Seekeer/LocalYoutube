import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The video with its controls under it, sized so both fit in [availableHeight].
///
/// This is what the web player does with `max-height: min(720px, 60vh)` on its video, without
/// guessing how tall the controls are: the controls are laid out first at the full width, and the
/// video gets the height left over, never more than [maxVideoHeight]. The controls come first: in
/// a short window the video shrinks so they stay on screen, down to [minVideoHeight] (none by
/// default); only a window shorter than the controls themselves scrolls. The video keeps its
/// own aspect ratio inside that height (give it an [AspectRatio]) and is centred across the width.
///
/// The result is as tall as the video and the controls together, so it can sit in a scrolling
/// page above anything else the page shows.
class PlayerStageLayout extends MultiChildRenderObjectWidget {
  PlayerStageLayout({
    super.key,
    required this.availableHeight,
    required Widget video,
    required Widget controls,
    this.minVideoHeight = 0,
    this.maxVideoHeight = 720,
  })  : assert(minVideoHeight <= maxVideoHeight),
        super(children: <Widget>[video, controls]);

  final double availableHeight;
  final double minVideoHeight;
  final double maxVideoHeight;

  @override
  RenderPlayerStageLayout createRenderObject(BuildContext context) {
    return RenderPlayerStageLayout(
      availableHeight: availableHeight,
      minVideoHeight: minVideoHeight,
      maxVideoHeight: maxVideoHeight,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPlayerStageLayout renderObject,
  ) {
    renderObject
      ..availableHeight = availableHeight
      ..minVideoHeight = minVideoHeight
      ..maxVideoHeight = maxVideoHeight;
  }
}

/// Where [RenderPlayerStageLayout] put one of its children.
class PlayerStageParentData extends ContainerBoxParentData<RenderBox> {}

/// Lays out [PlayerStageLayout]: the first child is the video, the second the controls.
class RenderPlayerStageLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, PlayerStageParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, PlayerStageParentData> {
  RenderPlayerStageLayout({
    required double availableHeight,
    required double minVideoHeight,
    required double maxVideoHeight,
  })  : _availableHeight = availableHeight,
        _minVideoHeight = minVideoHeight,
        _maxVideoHeight = maxVideoHeight;

  double get availableHeight => _availableHeight;
  double _availableHeight;
  set availableHeight(double value) {
    if (value == _availableHeight) {
      return;
    }
    _availableHeight = value;
    markNeedsLayout();
  }

  double get minVideoHeight => _minVideoHeight;
  double _minVideoHeight;
  set minVideoHeight(double value) {
    if (value == _minVideoHeight) {
      return;
    }
    _minVideoHeight = value;
    markNeedsLayout();
  }

  double get maxVideoHeight => _maxVideoHeight;
  double _maxVideoHeight;
  set maxVideoHeight(double value) {
    if (value == _maxVideoHeight) {
      return;
    }
    _maxVideoHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! PlayerStageParentData) {
      child.parentData = PlayerStageParentData();
    }
  }

  /// The height the video may take once the controls have [controlsHeight].
  double _videoHeightLimit(double controlsHeight) {
    final double left = availableHeight.isFinite
        ? availableHeight - controlsHeight
        : maxVideoHeight;
    return left.clamp(minVideoHeight, maxVideoHeight).toDouble();
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final double width = constraints.maxWidth;
    final RenderBox? video = firstChild;
    final RenderBox? controls = video == null ? null : childAfter(video);
    final double controlsHeight = controls == null
        ? 0
        : controls.getDryLayout(BoxConstraints.tightFor(width: width)).height;
    final double videoHeight = video == null
        ? 0
        : video
            .getDryLayout(
              BoxConstraints(
                maxWidth: width,
                maxHeight: _videoHeightLimit(controlsHeight),
              ),
            )
            .height;
    return constraints.constrain(Size(width, videoHeight + controlsHeight));
  }

  @override
  void performLayout() {
    assert(
      constraints.hasBoundedWidth,
      'PlayerStageLayout needs a bounded width to centre the video in.',
    );
    final double width = constraints.maxWidth;
    final RenderBox? video = firstChild;
    final RenderBox? controls = video == null ? null : childAfter(video);

    double controlsHeight = 0;
    if (controls != null) {
      controls.layout(
        BoxConstraints.tightFor(width: width),
        parentUsesSize: true,
      );
      controlsHeight = controls.size.height;
    }

    double videoHeight = 0;
    if (video != null) {
      video.layout(
        BoxConstraints(
          maxWidth: width,
          maxHeight: _videoHeightLimit(controlsHeight),
        ),
        parentUsesSize: true,
      );
      videoHeight = video.size.height;
      (video.parentData! as PlayerStageParentData).offset = Offset(
        math.max(0.0, (width - video.size.width) / 2),
        0,
      );
    }
    if (controls != null) {
      (controls.parentData! as PlayerStageParentData).offset = Offset(
        0,
        videoHeight,
      );
    }
    size = constraints.constrain(Size(width, videoHeight + controlsHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
