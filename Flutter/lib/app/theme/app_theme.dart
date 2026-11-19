import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// LocalTube's design tokens, shared with the website: cobalt for actions and
/// the interface, coral for children's content, mint for local files and
/// audio, sun for what is new.
///
/// The app is used mostly on a 6.8" 20:9 phone (Realme 15 Pro, 427×933 dp)
/// with curved side edges, a punch-hole camera and gesture navigation, so the
/// theme keeps a 16 dp side gutter, 48 dp touch targets and draws edge to edge.
abstract final class LtColors {
  static const Color ink = Color(0xFF1A1D33);
  static const Color inkSoft = Color(0xFF3A3F5C);
  static const Color muted = Color(0xFF555A75);
  static const Color subtle = Color(0xFF8A8FA8);
  static const Color line = Color(0xFFE3E5EE);
  static const Color lineStrong = Color(0xFFCFD3E1);
  static const Color bg = Color(0xFFF3F4F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color tonal = Color(0xFFECEEF5);

  static const Color primary = Color(0xFF3346D3);
  static const Color primaryStrong = Color(0xFF2534A8);
  static const Color primarySoft = Color(0xFFE6E9FC);
  static const Color coral = Color(0xFFE0603B);
  static const Color coralStrong = Color(0xFFC2492A);
  static const Color coralSoft = Color(0xFFFFEEE8);
  /// Dark enough for 4.5:1 as text on the page background.
  static const Color mint = Color(0xFF177560);
  static const Color mintSoft = Color(0xFFE3F4EE);
  static const Color sun = Color(0xFFF2B33D);
  static const Color sunStrong = Color(0xFF9A6200);
  static const Color sunSoft = Color(0xFFFFF4DC);
  static const Color danger = Color(0xFFC62828);
  static const Color dangerSoft = Color(0xFFFDECEC);

  /// The dark stage behind video, and the dark theme's background.
  static const Color stage = Color(0xFF10121F);
}

/// Corner radii and spacing used across screens.
abstract final class LtSizes {
  static const double gutter = 16;
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 18;
  static const double radiusXL = 24;
}

/// An accent for a kind of content: a strong colour for icons and a soft one
/// for the shape behind them. It follows the light or dark theme.
@immutable
class LtTone {
  const LtTone({required this.strong, required this.soft});

  final Color strong;
  final Color soft;
}

/// The extra colours Material's [ColorScheme] has no slot for.
@immutable
class LtPalette extends ThemeExtension<LtPalette> {
  const LtPalette({
    required this.cobalt,
    required this.coral,
    required this.mint,
    required this.sun,
    required this.danger,
    required this.stage,
    required this.subtle,
  });

  final LtTone cobalt;
  final LtTone coral;
  final LtTone mint;
  final LtTone sun;
  final LtTone danger;
  final Color stage;
  final Color subtle;

  static const LtPalette light = LtPalette(
    cobalt: LtTone(strong: LtColors.primary, soft: LtColors.primarySoft),
    coral: LtTone(strong: LtColors.coralStrong, soft: LtColors.coralSoft),
    mint: LtTone(strong: LtColors.mint, soft: LtColors.mintSoft),
    sun: LtTone(strong: LtColors.sunStrong, soft: LtColors.sunSoft),
    danger: LtTone(strong: LtColors.danger, soft: LtColors.dangerSoft),
    stage: LtColors.stage,
    subtle: LtColors.subtle,
  );

  static const LtPalette dark = LtPalette(
    cobalt: LtTone(strong: Color(0xFFAEB7FF), soft: Color(0xFF242B5E)),
    coral: LtTone(strong: Color(0xFFFFA285), soft: Color(0xFF4A2318)),
    mint: LtTone(strong: Color(0xFF74D8BA), soft: Color(0xFF123F34)),
    sun: LtTone(strong: Color(0xFFFFCC66), soft: Color(0xFF433313)),
    danger: LtTone(strong: Color(0xFFFF8A80), soft: Color(0xFF4A1C1C)),
    stage: Color(0xFF000000),
    subtle: Color(0xFF7E84A0),
  );

  static LtPalette of(BuildContext context) =>
      Theme.of(context).extension<LtPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  LtPalette copyWith() => this;

  @override
  LtPalette lerp(ThemeExtension<LtPalette>? other, double t) =>
      t < 0.5 ? this : (other as LtPalette? ?? this);
}

const ColorScheme _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: LtColors.primary,
  onPrimary: Colors.white,
  primaryContainer: LtColors.primarySoft,
  onPrimaryContainer: Color(0xFF141C66),
  secondary: LtColors.coralStrong,
  onSecondary: Colors.white,
  secondaryContainer: LtColors.coralSoft,
  onSecondaryContainer: Color(0xFF6B2310),
  tertiary: LtColors.mint,
  onTertiary: Colors.white,
  tertiaryContainer: LtColors.mintSoft,
  onTertiaryContainer: Color(0xFF0B4636),
  error: LtColors.danger,
  onError: Colors.white,
  errorContainer: LtColors.dangerSoft,
  onErrorContainer: Color(0xFF7A1414),
  surface: LtColors.bg,
  onSurface: LtColors.ink,
  onSurfaceVariant: LtColors.muted,
  surfaceDim: Color(0xFFE2E4EC),
  surfaceBright: Colors.white,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Colors.white,
  surfaceContainer: Color(0xFFEEF0F6),
  surfaceContainerHigh: LtColors.tonal,
  surfaceContainerHighest: Color(0xFFE4E7F0),
  outline: LtColors.lineStrong,
  outlineVariant: LtColors.line,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: LtColors.ink,
  onInverseSurface: Color(0xFFF3F4F9),
  inversePrimary: Color(0xFFAEB7F0),
  surfaceTint: Colors.transparent,
);

const ColorScheme _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFAEB7FF),
  onPrimary: Color(0xFF141C66),
  primaryContainer: Color(0xFF2B3690),
  onPrimaryContainer: Color(0xFFE0E4FF),
  secondary: Color(0xFFFFA285),
  onSecondary: Color(0xFF5A1C09),
  secondaryContainer: Color(0xFF5E2614),
  onSecondaryContainer: Color(0xFFFFDBCF),
  tertiary: Color(0xFF74D8BA),
  onTertiary: Color(0xFF00382A),
  tertiaryContainer: Color(0xFF0F5A48),
  onTertiaryContainer: Color(0xFFBFF1E0),
  error: Color(0xFFFF8A80),
  onError: Color(0xFF5F0B0B),
  errorContainer: Color(0xFF5C1D1D),
  onErrorContainer: Color(0xFFFFDAD6),
  // AMOLED: a true black background costs no power and makes the cards float.
  surface: Color(0xFF000000),
  onSurface: Color(0xFFE7E9F3),
  onSurfaceVariant: Color(0xFFA9AEC6),
  surfaceDim: Color(0xFF000000),
  surfaceBright: Color(0xFF2B2F4A),
  surfaceContainerLowest: Color(0xFF07080E),
  surfaceContainerLow: Color(0xFF14172A),
  surfaceContainer: Color(0xFF1A1D2E),
  surfaceContainerHigh: Color(0xFF22263A),
  surfaceContainerHighest: Color(0xFF2A2E45),
  outline: Color(0xFF4A4F6E),
  outlineVariant: Color(0xFF2C3150),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFFE7E9F3),
  onInverseSurface: Color(0xFF1A1D33),
  inversePrimary: LtColors.primary,
  surfaceTint: Colors.transparent,
);

ThemeData buildLightTheme() => _build(_lightScheme, LtPalette.light);

ThemeData buildDarkTheme() => _build(_darkScheme, LtPalette.dark);

ThemeData _build(ColorScheme scheme, LtPalette palette) {
  final bool dark = scheme.brightness == Brightness.dark;
  final ThemeData base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final TextTheme text = _textTheme(base.textTheme, scheme);
  final RoundedRectangleBorder radiusM = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(LtSizes.radiusM),
  );
  final Color cardColor = scheme.surfaceContainerLow;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    textTheme: text,
    extensions: <ThemeExtension<dynamic>>[palette],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
      systemOverlayStyle: overlayStyleFor(scheme.brightness),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusL),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    // In the dark theme the main buttons stay cobalt with white text, as on
    // the light one: a large lavender slab glares at night.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? LtColors.primary : null,
        foregroundColor: dark ? Colors.white : null,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: radiusM,
        textStyle: text.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 48),
        elevation: 0,
        backgroundColor: dark ? LtColors.primary : scheme.primary,
        foregroundColor: dark ? Colors.white : scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: radiusM,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        shape: radiusM,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: radiusM,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: dark ? LtColors.primary : scheme.primary,
      foregroundColor: dark ? Colors.white : scheme.onPrimary,
      // Flat, like the rest of the system: the solid cobalt carries it.
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 1,
      highlightElevation: 1,
      extendedTextStyle: text.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusL),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? scheme.surfaceContainerHigh : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: text.bodyMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: text.bodyLarge?.copyWith(color: palette.subtle),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cardColor,
      selectedColor: scheme.primary,
      secondarySelectedColor: scheme.primary,
      disabledColor: scheme.surfaceContainerHigh,
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      showCheckmark: false,
      checkmarkColor: scheme.onPrimary,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: LtSizes.gutter),
      minVerticalPadding: 10,
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      leadingAndTrailingTextStyle: text.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: scheme.onSurfaceVariant,
      collapsedIconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      collapsedTextColor: scheme.onSurface,
      tilePadding: const EdgeInsets.symmetric(horizontal: LtSizes.gutter),
    ),
    // The off state must read as a control, not as a blank: a visible
    // outline and thumb (3:1 against the card).
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : (dark ? const Color(0xFF8A8FB0) : const Color(0xFF8A90A8)),
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Colors.white
            : (dark ? const Color(0xFF9AA0BC) : const Color(0xFF6B7190)),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? LtColors.primary
            : (dark ? const Color(0xFF2A2F48) : const Color(0xFFE4E7F0)),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 9,
        elevation: 0,
        pressedElevation: 0,
      ),
      trackShape: const RoundedRectSliderTrackShape(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: 0.15),
      circularTrackColor: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
      ),
      elevation: 2,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? scheme.surfaceContainerHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusXL),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? scheme.surfaceContainerHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LtSizes.radiusXL),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? scheme.surfaceContainerHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LtSizes.radiusM),
      ),
      textStyle: text.bodyLarge,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(
          dark ? scheme.surfaceContainerHigh : Colors.white,
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LtSizes.radiusM),
          ),
        ),
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: palette.coral.strong,
      textColor: Colors.white,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(LtSizes.radiusS),
      ),
      textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      waitDuration: const Duration(milliseconds: 400),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: LtColors.primary,
        selectedForegroundColor: Colors.white,
        foregroundColor: scheme.onSurface,
        backgroundColor: cardColor,
        side: BorderSide(color: scheme.outline),
        textStyle: text.labelLarge,
        minimumSize: const Size(48, 48),
        // The drawn height is 40 dp plus density: +8 dp makes it 48.
        visualDensity: const VisualDensity(vertical: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
  final TextTheme t = base.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  return t.copyWith(
    headlineMedium: t.headlineMedium?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.15,
    ),
    headlineSmall: t.headlineSmall?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.2,
    ),
    titleLarge: t.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.25,
    ),
    titleMedium: t.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.3,
    ),
    titleSmall: t.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    bodyLarge: t.bodyLarge?.copyWith(fontSize: 16, height: 1.45, letterSpacing: 0.1),
    bodyMedium: t.bodyMedium?.copyWith(fontSize: 14, height: 1.4, letterSpacing: 0.1),
    bodySmall: t.bodySmall?.copyWith(
      fontSize: 12.5,
      height: 1.35,
      letterSpacing: 0.1,
      color: scheme.onSurfaceVariant,
    ),
    labelLarge: t.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: t.labelMedium?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    labelSmall: t.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    ),
  );
}

/// Transparent system bars with icons that read on this theme: the app draws
/// under the status bar and the gesture handle.
SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        dark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
