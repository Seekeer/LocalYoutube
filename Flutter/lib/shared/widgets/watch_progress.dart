import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// From this far on a video counts as watched in lists.
const double watchedThreshold = 0.95;

/// The state line every video list shows the same way: «Просмотрено» for a
/// video watched to the end, «Осталось 32 мин» for one in progress, null for
/// one not started (or whose length is unknown).
String? watchProgressLabel(double? fraction, Duration? duration) {
  if (fraction == null || fraction <= 0) {
    return null;
  }
  if (fraction >= watchedThreshold) {
    return 'Просмотрено';
  }
  if (duration == null || duration <= Duration.zero) {
    return null;
  }
  final int minutes =
      ((duration.inSeconds * (1 - fraction)) / 60).ceil().clamp(1, 1 << 20);
  if (minutes >= 60) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return rest == 0 ? 'Осталось $hours ч' : 'Осталось $hours ч $rest мин';
  }
  return 'Осталось $minutes мин';
}

/// Neutral for watched, coral for in progress — the colours of the cover's
/// bar. Mint is kept for «on this phone».
Color watchProgressColor(BuildContext context, double? fraction) {
  final LtPalette palette = LtPalette.of(context);
  return (fraction ?? 0) >= watchedThreshold
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : palette.coral.strong;
}
