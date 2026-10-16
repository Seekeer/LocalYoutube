import 'package:flutter/material.dart';

enum StateFeedbackTone { info, warning, error }

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
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _ToneColors toneColors = _resolveToneColors(colors, tone);
    final IconData icon = leadingIcon ?? _defaultIcon(tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: toneColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: toneColors.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: toneColors.foreground, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: toneColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final bool canAct = actionLabel != null &&
        actionLabel!.trim().isNotEmpty &&
        onAction != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 42, color: colors.outline),
          const SizedBox(height: 10),
          Text(
            title,
            style: textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style:
                textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (canAct) ...<Widget>[
            const SizedBox(height: 14),
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

class _ToneColors {
  const _ToneColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

_ToneColors _resolveToneColors(ColorScheme colors, StateFeedbackTone tone) {
  switch (tone) {
    case StateFeedbackTone.info:
      return _ToneColors(
        background: colors.secondaryContainer,
        foreground: colors.onSecondaryContainer,
        border: colors.secondary.withValues(alpha: 0.4),
      );
    case StateFeedbackTone.warning:
      return _ToneColors(
        background: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
        border: colors.tertiary.withValues(alpha: 0.45),
      );
    case StateFeedbackTone.error:
      return _ToneColors(
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
        border: colors.error.withValues(alpha: 0.45),
      );
  }
}

IconData _defaultIcon(StateFeedbackTone tone) {
  switch (tone) {
    case StateFeedbackTone.info:
      return Icons.info_outline;
    case StateFeedbackTone.warning:
      return Icons.wifi_off_rounded;
    case StateFeedbackTone.error:
      return Icons.error_outline;
  }
}
