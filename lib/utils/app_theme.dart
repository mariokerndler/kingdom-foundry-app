import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Retained constants (no Material 3 colorScheme slot) ──────────────────────

abstract class AppColors {
  // Archetype accent strips — used on kingdom card tiles and chips
  static const statAttack = Color(0xFFBE123C); // crimson rose
  static const statTrasher = Color(0xFF7C3AED); // indigo-violet
  static const statDuration = Color(0xFFB45309); // amber-brown
  static const statAltVP = Color(0xFF15803D); // forest green
  static const landscapeAccent = Color(0xFF1D4ED8); // cobalt blue

  // Semantic singletons used in SnackBar / ScaffoldMessenger directly
  static const errorRed = Color(0xFFDC2626);
  static const successGreen = Color(0xFF15803D); // same hue as statAltVP

  // Debt badge — intentionally fixed "iron" styling regardless of mode
  static const debtBadgeFill = Color(0xFF334155);
  static const debtBadgeBorder = Color(0xFF64748B);
  static const debtBadgeText = Color(0xFFCBD5E1);
  static const debtBadgeFillDark = Color(0xFF37474F);
  static const debtBadgeBorderDark = Color(0xFF78909C);
  static const debtBadgeTextDark = Color(0xFFB0BEC5);
}

// ── Shared text theme ─────────────────────────────────────────────────────────

TextTheme _buildTextTheme(TextTheme base) =>
    GoogleFonts.dmSansTextTheme(base).copyWith(
      titleLarge: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium:
          GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      labelSmall: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500),
    );

// ── Light theme ───────────────────────────────────────────────────────────────

ThemeData buildLightTheme() {
  const cs = ColorScheme.light(
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF1F5F9),
    primary: Color(0xFFC49A0A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(
        0xFFC49A0A), // mirrors primary — no distinct secondary hue in this design
    onSecondary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF475569),
    outline: Color(0xFF94A3B8),
    outlineVariant: Color(0xFFE2E8F0),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
  );

  return _buildTheme(
    colorScheme: cs,
    scaffoldBackground: const Color(0xFFF8F9FB),
    textTheme: _buildTextTheme(ThemeData.light().textTheme),
  );
}

// ── Dark theme ────────────────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  const cs = ColorScheme.dark(
    surface: Color(0xFF161B22),
    surfaceContainer: Color(0xFF1C2333),
    primary: Color(0xFFD4A520),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(
        0xFFD4A520), // mirrors primary — no distinct secondary hue in this design
    onSecondary: Color(0xFFFFFFFF),
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

// ── Shared component builder ──────────────────────────────────────────────────

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
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorColor: colorScheme.primary,
      dividerColor: colorScheme.outlineVariant,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.white
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
      checkColor: WidgetStateProperty.all(Colors.white),
      side: BorderSide(color: colorScheme.outline, width: 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      prefixIconColor: colorScheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
  );
}
