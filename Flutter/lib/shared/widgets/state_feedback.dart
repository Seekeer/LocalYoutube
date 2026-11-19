import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

enum StateFeedbackTone { info, warning, error }

/// A one-line notice over a screen's content: offline, loaded from cache,
/// an error that left the old data in place.
class StateFeedbackBanner extends StatelessWidget {
  const StateFeedbackBanner({
    super.key,
    required this.message,
    this.tone = StateFeedbackTone.info,
    this.leadingIcon,
  });

  final String message;
  final StateFeedbackTone tone;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final LtTone colors = _toneOf(context, tone);
    final IconData icon = leadingIcon ?? _defaultIcon(tone);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: colors.strong, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: dark
                          ? Theme.of(context).colorScheme.onSurface
                          : Color.lerp(colors.strong, LtColors.ink, 0.45),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a screen shows instead of an empty list: an icon, what happened and,
/// when something can be done about it, a button.
class StateFeedbackPlaceholder extends StatelessWidget {
  const StateFeedbackPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final LtPalette palette = LtPalette.of(context);
    final bool canAct = actionLabel != null &&
        actionLabel!.trim().isNotEmpty &&
        onAction != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.cobalt.soft,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, size: 36, color: palette.cobalt.strong),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (canAct) ...<Widget>[
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

LtTone _toneOf(BuildContext context, StateFeedbackTone tone) {
  final LtPalette palette = LtPalette.of(context);
  switch (tone) {
    case StateFeedbackTone.info:
      return palette.cobalt;
    case StateFeedbackTone.warning:
      return palette.sun;
    case StateFeedbackTone.error:
      return palette.danger;
  }
}

IconData _defaultIcon(StateFeedbackTone tone) {
  switch (tone) {
    case StateFeedbackTone.info:
      return Icons.info_outline_rounded;
    case StateFeedbackTone.warning:
      return Icons.wifi_off_rounded;
    case StateFeedbackTone.error:
      return Icons.error_outline_rounded;
  }
}
