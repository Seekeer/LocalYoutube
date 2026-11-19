import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The LocalTube mark from the website: a coral rounded square with a white
/// play triangle and a sun-yellow offset behind it.
class LtLogoMark extends StatelessWidget {
  const LtLogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.3;
    return SizedBox(
      width: size + size * 0.12,
      height: size + size * 0.12,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: size * 0.12,
            top: size * 0.12,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: LtColors.sun,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: LtColors.coral,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: size * 0.72,
            ),
          ),
        ],
      ),
    );
  }
}

/// «LocalTube» with its mark, for the top bar of the main screens.
class LtBrandTitle extends StatelessWidget {
  const LtBrandTitle({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const LtLogoMark(size: 30),
        const SizedBox(width: 10),
        Text(
          'LocalTube',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(width: 8),
          Text(subtitle!, style: text.titleMedium),
        ],
      ],
    );
  }
}

/// A small uppercase-free heading above a group of content.
class LtSectionHeader extends StatelessWidget {
  const LtSectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(0, 20, 0, 10),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A rounded square with an icon in a content tone, as on the website's
/// section tiles.
class LtToneIcon extends StatelessWidget {
  const LtToneIcon({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 44,
  });

  final IconData icon;
  final LtTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.soft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: tone.strong, size: size * 0.55),
    );
  }
}

/// A white card with a heading, for a group of controls or a list on a
/// screen with several groups.
class LtSectionCard extends StatelessWidget {
  const LtSectionCard({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 12),
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 20, color: colors.onSurfaceVariant),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Bottom padding for a scrolling screen: above the gesture handle, with room
/// for a floating button when there is one.
EdgeInsets ltListPadding(
  BuildContext context, {
  double top = 8,
  double horizontal = 0,
  double extraBottom = 16,
}) {
  final double bottom = MediaQuery.viewPaddingOf(context).bottom;
  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom + extraBottom);
}

/// Asks before something that cannot be undone. Returns true on «yes».
Future<bool> ltConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Отмена',
  bool destructive = true,
  Key? confirmKey,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ColorScheme colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            key: confirmKey,
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
