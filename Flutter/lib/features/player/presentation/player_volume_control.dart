import 'package:flutter/material.dart';

import '../domain/player_volume.dart';

/// The player's volume: a mute button and a slider, as on a desktop player.
///
/// It drives the installation's [PlayerVolume] directly. Every open player listens to that, so the
/// video follows the slider without this widget knowing which player it is under, and the next video
/// (or the next launch) starts where it was left.
///
/// The slider shows what is heard: it sits at zero while muted, and moving it unmutes.
class PlayerVolumeControl extends StatelessWidget {
  const PlayerVolumeControl({
    super.key,
    required this.volume,
    this.enabled = true,
    this.color,
    this.sliderWidth = 140,
    this.sliderPadding,
    this.trackColor,
  });

  /// The slider's colour when it differs from the icon's.
  final Color? trackColor;

  /// The slider's own padding, to line its track up with something else.
  final EdgeInsets? sliderPadding;

  static const Key muteButtonKey = Key('player-volume-mute');
  static const Key sliderKey = Key('player-volume-slider');

  final PlayerVolume volume;
  final bool enabled;

  /// The icon and slider colour, for controls drawn over the video; the theme's when null.
  final Color? color;
  final double sliderWidth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: volume,
      builder: (BuildContext context, Widget? _) {
        final double heard = volume.value;
        final ThemeData theme = Theme.of(context);
        final Color? tint = trackColor ?? color;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: muteButtonKey,
              onPressed: enabled ? volume.toggleMuted : null,
              tooltip: volume.isSilent ? 'Включить звук' : 'Без звука',
              color: color,
              icon: Icon(_icon(heard)),
            ),
            SizedBox(
              width: sliderWidth,
              child: SliderTheme(
                data: tint == null
                    ? theme.sliderTheme
                    : theme.sliderTheme.copyWith(
                        activeTrackColor: tint,
                        thumbColor: tint,
                        inactiveTrackColor: tint.withValues(alpha: 0.3),
                      ),
                child: Slider(
                  key: sliderKey,
                  padding: sliderPadding,
                  min: PlayerVolume.minimum,
                  max: PlayerVolume.maximum,
                  value: heard,
                  semanticFormatterCallback: (double value) =>
                      'Громкость ${(value * 100).round()}%',
                  onChanged: enabled ? volume.setValue : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static IconData _icon(double heard) {
    if (heard <= PlayerVolume.minimum) {
      return Icons.volume_off;
    }
    if (heard < 0.5) {
      return Icons.volume_down;
    }
    return Icons.volume_up;
  }
}

/// A rounded track whose played part is as thick as the rest. The stock
/// shape draws it 2 dp thicker, which makes a quiet volume line look heavy.
class EvenSliderTrackShape extends RoundedRectSliderTrackShape {
  const EvenSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
  }
}
