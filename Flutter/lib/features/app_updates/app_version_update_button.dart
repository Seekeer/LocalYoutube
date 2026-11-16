import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_updates.dart';

/// Double button of the main menu's top row, as in ReadHub: the installed
/// version (with a Preview mark) and "Проверить обновления" side by side in
/// one outlined block. The check reports its result in a snack bar; a newer
/// version offers Settings, where it is downloaded and installed.
///
/// Hidden until the installed version is known, and for builds without one.
class AppVersionUpdateButton extends ConsumerStatefulWidget {
  const AppVersionUpdateButton({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  ConsumerState<AppVersionUpdateButton> createState() =>
      _AppVersionUpdateButtonState();
}

class _AppVersionUpdateButtonState extends ConsumerState<AppVersionUpdateButton>
    with SingleTickerProviderStateMixin {
  static const String _checkLabel = 'Проверить обновления';
  static const String _checkingLabel = 'Проверка обновлений…';

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    ref.listenManual<AppUpdateState>(
      appUpdateControllerProvider,
      (_, AppUpdateState state) {
        if (state.status == UpdateStatus.checking) {
          if (!_spin.isAnimating) _spin.repeat();
        } else {
          _spin.reset();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    await ref.read(appUpdateControllerProvider.notifier).check();
    if (!mounted) return;
    final AppUpdateState state = ref.read(appUpdateControllerProvider);
    final AvailableUpdate? available = state.available;
    final String? message = available != null
        ? 'Доступна версия ${available.versionName}'
        : appUpdateStatusMessage(state.status, state.installed);
    if (message == null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      action: available == null
          ? null
          : SnackBarAction(
              label: 'Настройки', onPressed: widget.onOpenSettings),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final AppUpdateState state = ref.watch(appUpdateControllerProvider);
    final InstalledApp? installed = state.installed;
    final bool checking = state.status == UpdateStatus.checking;
    if (installed == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final BorderSide border = BorderSide(color: colors.outline);
    final BorderRadius radius = BorderRadius.circular(8);
    final bool preview = installed.channel == 'preview' ||
        installed.channel == 'windows-preview';
    final String version =
        'Версия ${installed.versionName} (${installed.versionCode})';
    final String checkLabel = checking ? _checkingLabel : _checkLabel;

    final VoidCallback? onCheck = checking ? null : _check;
    final TextStyle labelStyle = (theme.textTheme.labelLarge ??
            const TextStyle())
        .copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w500);
    final String shortVersion = _shortVersion(installed.versionName);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    // Measured the way Text renders: inherited style, then bold text if the
    // system asks for it.
    TextStyle measured(TextStyle style) {
      final TextStyle effective =
          DefaultTextStyle.of(context).style.merge(style);
      return MediaQuery.boldTextOf(context)
          ? effective.merge(const TextStyle(fontWeight: FontWeight.bold))
          : effective;
    }

    // Space the version and the mark need at the current text size.
    final double versionWidth = _versionPadding * 2 +
        _textWidth(shortVersion, measured(labelStyle), textScaler);
    final double markWidth = _markGap +
        _PreviewMark.padding * 2 +
        _textWidth(
            _PreviewMark.label, measured(_PreviewMark.textStyle), textScaler);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Beside the bar's actions on a narrow phone (or with enlarged text)
        // the Preview mark goes first, then the version; the check keeps its
        // full size, and when even it does not fit, Settings still has it.
        final double width = constraints.maxWidth;
        if (width < _checkOnlyWidth) return const SizedBox.shrink();
        final bool showVersion = width >= _checkOnlyWidth + 1 + versionWidth;
        final bool showMark = preview &&
            showVersion &&
            width >= _checkOnlyWidth + 1 + versionWidth + markWidth;
        return Container(
          key: const Key('app-version-update-button'),
          constraints: const BoxConstraints(minHeight: 40),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.fromBorderSide(border),
            borderRadius: radius,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: DefaultTextStyle.merge(
              style: labelStyle,
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // "Версия" stays for screen readers and the tooltip; the
                    // visible part is compact so it fits beside the actions.
                    if (showVersion) ...<Widget>[
                      Flexible(
                        child: Tooltip(
                          message: installed.channel == null
                              ? version
                              : '$version · ${installed.channelLabel}',
                          child: Semantics(
                            label: preview ? '$version, Preview' : version,
                            excludeSemantics: true,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: _versionPadding),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      shortVersion,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (showMark) ...<Widget>[
                                    const SizedBox(width: _markGap),
                                    _PreviewMark(colors: colors),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(width: 1, color: colors.outline),
                    ],
                    Tooltip(
                      message: checkLabel,
                      child: Semantics(
                        container: true,
                        button: true,
                        enabled: !checking,
                        label: checkLabel,
                        onTap: onCheck,
                        excludeSemantics: true,
                        child: InkWell(
                          key: const Key('app-update-check-button'),
                          onTap: onCheck,
                          child: SizedBox(
                            width: 40,
                            child: Center(
                              child: RotationTransition(
                                turns: _spin,
                                child: Icon(
                                  Icons.refresh,
                                  size: 18,
                                  color: checking
                                      ? colors.onSurfaceVariant
                                          .withValues(alpha: 0.6)
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The check with the block's border; the version and the mark add their
  /// measured widths and a 1px divider.
  static const double _checkOnlyWidth = 42;
  static const double _versionPadding = 8;
  static const double _markGap = 6;

  static double _textWidth(String text, TextStyle style, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    // Rounding up keeps the last glyph out of an ellipsis.
    return width.ceilToDouble();
  }

  /// Android Preview names carry a build suffix ("1.1.749-debug.1"); the mark
  /// already says Preview, so the bar shows the version itself.
  static String _shortVersion(String name) {
    final int cut = name.indexOf(RegExp('[-+]'));
    return cut > 0 ? name.substring(0, cut) : name;
  }
}

class _PreviewMark extends StatelessWidget {
  const _PreviewMark({required this.colors});

  final ColorScheme colors;

  static const String label = 'Preview';
  static const double padding = 6;
  static const TextStyle textStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: padding, vertical: 1),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textStyle.copyWith(color: colors.onTertiaryContainer),
      ),
    );
  }
}
