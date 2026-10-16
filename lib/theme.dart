import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic colours resolved from the active [ThemeData].
///
/// The palette constants below are light-mode values. Widgets must not read
/// them directly, because a direct read ignores the theme and stays light in
/// dark mode. Use `Theme.of(context).colors` instead.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceElevated,
    required this.scaffoldBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.appBarBg,
    required this.flashBg,
    required this.accent,
    required this.accentText,
    required this.errorBg,
    required this.errorFg,
    required this.errorBorder,
    required this.successBg,
    required this.successFg,
    required this.successBorder,
    required this.warningBg,
    required this.warningFg,
    required this.warningBorder,
    required this.neutralBg,
    required this.neutralFg,
  });

  final Color surface;
  final Color surfaceElevated;
  final Color scaffoldBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color appBarBg;
  final Color flashBg;

  /// Interactive accent: progress rings, radio selections, icons.
  final Color accent;

  /// Accent used for text and labels, which needs more contrast than [accent].
  final Color accentText;

  final Color errorBg;
  final Color errorFg;
  final Color errorBorder;
  final Color successBg;
  final Color successFg;
  final Color successBorder;
  final Color warningBg;
  final Color warningFg;
  final Color warningBorder;
  final Color neutralBg;
  final Color neutralFg;

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceElevated,
    Color? scaffoldBg,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? appBarBg,
    Color? flashBg,
    Color? accent,
    Color? accentText,
    Color? errorBg,
    Color? errorFg,
    Color? errorBorder,
    Color? successBg,
    Color? successFg,
    Color? successBorder,
    Color? warningBg,
    Color? warningFg,
    Color? warningBorder,
    Color? neutralBg,
    Color? neutralFg,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      appBarBg: appBarBg ?? this.appBarBg,
      flashBg: flashBg ?? this.flashBg,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      errorBg: errorBg ?? this.errorBg,
      errorFg: errorFg ?? this.errorFg,
      errorBorder: errorBorder ?? this.errorBorder,
      successBg: successBg ?? this.successBg,
      successFg: successFg ?? this.successFg,
      successBorder: successBorder ?? this.successBorder,
      warningBg: warningBg ?? this.warningBg,
      warningFg: warningFg ?? this.warningFg,
      warningBorder: warningBorder ?? this.warningBorder,
      neutralBg: neutralBg ?? this.neutralBg,
      neutralFg: neutralFg ?? this.neutralFg,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      appBarBg: Color.lerp(appBarBg, other.appBarBg, t)!,
      flashBg: Color.lerp(flashBg, other.flashBg, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      errorFg: Color.lerp(errorFg, other.errorFg, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      neutralBg: Color.lerp(neutralBg, other.neutralBg, t)!,
      neutralFg: Color.lerp(neutralFg, other.neutralFg, t)!,
    );
  }
}

/// Convenience accessor so widgets read `context.colors` instead of
/// `Theme.of(context).extension<AppColors>()!`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Mirrors the web portal's palette in `src/index.css` and Tailwind's emerald
/// and stone scales, so the app and the desktop portal read as one product.
///
/// The constants here are the light-mode values. Prefer [AppColors] so that a
/// widget follows light/dark automatically.
class AppTheme {
  AppTheme._();

  static const emerald950 = Color(0xFF022C22);
  static const emerald900 = Color(0xFF064E3B);
  static const emerald800 = Color(0xFF065F46);
  static const emerald700 = Color(0xFF047857);
  static const emerald600 = Color(0xFF059669);
  static const emerald50 = Color(0xFFF0FDF4);

  static const stone50 = Color(0xFFFAFAF9);
  static const stone100 = Color(0xFFF5F5F4);
  static const stone200 = Color(0xFFE7E5E4);
  static const stone300 = Color(0xFFD6D3D1);
  static const stone400 = Color(0xFFA8A29E);
  static const stone500 = Color(0xFF78716C);
  static const stone600 = Color(0xFF57534E);
  static const stone700 = Color(0xFF44403C);
  static const stone800 = Color(0xFF292524);
  static const stone900 = Color(0xFF1C1917);

  static const amber600 = Color(0xFFD97706);
  static const amber50 = Color(0xFFFFFBEB);
  static const red600 = Color(0xFFDC2626);
  static const red50 = Color(0xFFFEF2F2);

  /// Poppins for headings and Inter for body, matching the web app's font stack.
  static const headingFont = 'Poppins';
  static const bodyFont = 'Inter';

  /// Light-mode slots. The hex values match the original palette exactly so the
  /// light theme renders identically to before.
  static const lightColors = AppColors(
    surface: Colors.white,
    surfaceElevated: Colors.white,
    scaffoldBg: stone50,
    border: stone200,
    textPrimary: stone900,
    textSecondary: stone600,
    textMuted: stone500,
    appBarBg: emerald900,
    flashBg: stone800,
    accent: emerald700,
    accentText: emerald800,
    errorBg: Color(0xFFFEF2F2),
    errorFg: Color(0xFF991B1B),
    errorBorder: Color(0xFFFECACA),
    successBg: Color(0xFFD1FAE5),
    successFg: Color(0xFF047857),
    successBorder: Color(0xFFA7F3D0),
    warningBg: Color(0xFFFEF3C7),
    warningFg: Color(0xFF92400E),
    warningBorder: Color(0xFFFDE68A),
    neutralBg: Color(0xFFF5F5F4),
    neutralFg: Color(0xFF57534E),
  );

  /// Dark-mode slots derived from the same stone/emerald scales, inverted around
  /// `stone800` so text stays the brightest element on every surface.
  static const darkColors = AppColors(
    surface: Color(0xFF1C1917),
    surfaceElevated: Color(0xFF292524),
    scaffoldBg: Color(0xFF0C0A09),
    border: Color(0xFF44403C),
    textPrimary: Color(0xFFFAFAF9),
    textSecondary: Color(0xFFD6D3D1),
    textMuted: Color(0xFFA8A29E),
    appBarBg: Color(0xFF022C22),
    flashBg: Color(0xFF44403C),
    accent: Color(0xFF10B981),
    accentText: Color(0xFF6EE7B7),
    // Tinted fills with lightened foregrounds, so the badge and banner text
    // keeps its contrast against the dark surface behind it.
    errorBg: Color(0xFF450A0A),
    errorFg: Color(0xFFFCA5A5),
    errorBorder: Color(0xFF7F1D1D),
    successBg: Color(0xFF022C22),
    successFg: Color(0xFF6EE7B7),
    successBorder: Color(0xFF065F46),
    warningBg: Color(0xFF451A03),
    warningFg: Color(0xFFFCD34D),
    warningBorder: Color(0xFF78350F),
    neutralBg: Color(0xFF292524),
    neutralFg: Color(0xFFD6D3D1),
  );

  static ThemeData build({Brightness brightness = Brightness.light}) {
    final dark = brightness == Brightness.dark;
    final colors = dark ? darkColors : lightColors;

    // Primary stays emerald700 in both themes so filled buttons keep their
    // identity; only the small text/border surfaces move with the theme. The
    // scheme itself must follow the theme's brightness: a hardcoded light
    // scheme leaves `colorScheme.surface`/`onSurface` light in dark mode, and
    // Material 3 falls back to those for widget internals (dropdown menus use
    // `canvasColor`, which derives from `colorScheme.surface`), leaving the
    // register dropdown popups as light text on white.
    final scheme = dark
        ? ColorScheme.dark(
            primary: emerald700,
            onPrimary: Colors.white,
            secondary: emerald600,
            onSecondary: Colors.white,
            surface: colors.surface,
            onSurface: colors.textPrimary,
            surfaceDim: colors.scaffoldBg,
            surfaceBright: colors.surfaceElevated,
            surfaceContainerLowest: colors.scaffoldBg,
            surfaceContainerLow: colors.surface,
            surfaceContainer: colors.surfaceElevated,
            surfaceContainerHigh: colors.flashBg,
            surfaceContainerHighest: colors.border,
            onSurfaceVariant: colors.textSecondary,
            error: red600,
            onError: Colors.white,
            outline: colors.border,
          )
        : const ColorScheme.light(
            primary: emerald700,
            onPrimary: Colors.white,
            secondary: emerald600,
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: stone900,
            error: red600,
            onError: Colors.white,
            outline: stone300,
          );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.scaffoldBg,
      fontFamily: bodyFont,
    );

    return base.copyWith(
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: headingFont,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.light,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: emerald600, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: red600),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: red600, width: 1.5),
        ),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: colors.textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald700,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: dark ? const Color(0xFF064E3B) : emerald50,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? (dark ? const Color(0xFF6EE7B7) : emerald800)
                : colors.textMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? (dark ? const Color(0xFF34D399) : emerald700)
                : colors.textMuted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.flashBg,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
    );
  }

  static ThemeData get dark => build(brightness: Brightness.dark);
}
