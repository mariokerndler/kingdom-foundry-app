import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  static const statAttack = Color(0xFFBE123C);
  static const statTrasher = Color(0xFF7C3AED);
  static const statDuration = Color(0xFFB45309);
  static const statAltVP = Color(0xFF15803D);
  static const landscapeAccent = Color(0xFF1D4ED8);

  static const errorRed = Color(0xFFB42318);
  static const successGreen = Color(0xFF15803D);

  static const debtBadgeFill = Color(0xFF334155);
  static const debtBadgeBorder = Color(0xFF64748B);
  static const debtBadgeText = Color(0xFFCBD5E1);
  static const debtBadgeFillDark = Color(0xFF37474F);
  static const debtBadgeBorderDark = Color(0xFF78909C);
  static const debtBadgeTextDark = Color(0xFFB0BEC5);
}

abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

abstract class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

TextTheme _buildTextTheme(TextTheme base) =>
    GoogleFonts.dmSansTextTheme(base).copyWith(
      titleLarge: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
      labelSmall: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
    );

ThemeData buildLightTheme() {
  const cs = ColorScheme.light(
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF1F5F9),
    primary: Color(0xFF8A6700),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF8A6700),
    onSecondary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF475569),
    outline: Color(0xFF94A3B8),
    outlineVariant: Color(0xFFE2E8F0),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
  );

  return _buildTheme(
    colorScheme: cs,
    scaffoldBackground: const Color(0xFFF8F9FB),
    textTheme: _buildTextTheme(ThemeData.light().textTheme),
  );
}

ThemeData buildDarkTheme() {
  const cs = ColorScheme.dark(
    surface: Color(0xFF161B22),
    surfaceContainer: Color(0xFF1C2333),
    primary: Color(0xFFE4BC52),
    onPrimary: Color(0xFF1F1700),
    secondary: Color(0xFFE4BC52),
    onSecondary: Color(0xFF1F1700),
    onSurface: Color(0xFFE6EDF3),
    onSurfaceVariant: Color(0xFF7D8590),
    outline: Color(0xFF4D5566),
    outlineVariant: Color(0xFF30363D),
    error: Color(0xFFF87171),
    onError: Color(0xFF1A0000),
  );

  return _buildTheme(
    colorScheme: cs,
    scaffoldBackground: const Color(0xFF0D1117),
    textTheme: _buildTextTheme(ThemeData.dark().textTheme),
  );
}

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color scaffoldBackground,
  required TextTheme textTheme,
}) {
  final isDark = colorScheme.brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorColor: colorScheme.primary,
      dividerColor: colorScheme.outlineVariant,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelLarge,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outlineVariant),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? colorScheme.primary
              : Colors.transparent),
      checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
      side: BorderSide(color: colorScheme.outline, width: 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13),
      secondaryLabelStyle: TextStyle(color: colorScheme.onPrimary, fontSize: 13),
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      prefixIconColor: colorScheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: colorScheme.onSurface,
      iconColor: colorScheme.onSurfaceVariant,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        textStyle: WidgetStateProperty.all(textTheme.labelLarge),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 4,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.surface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
  );
}
