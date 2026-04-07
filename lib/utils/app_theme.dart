import 'package:flutter/material.dart';

abstract class AppColors {
  static const background   = Color(0xFF0F0F1A);
  static const surface      = Color(0xFF1A1A2E);
  static const cardSurface  = Color(0xFF16213E);
  static const divider      = Color(0xFF2A2A45);
  static const gold         = Color(0xFFFFD700);
  static const goldDark     = Color(0xFFB8860B);
  static const parchment    = Color(0xFFF0E6D3);
  static const parchmentDim = Color(0xFF8A7A6A);
  static const errorRed     = Color(0xFFCF3C3C);
  static const successGreen = Color(0xFF4CAF50);

  // Stat strip / archetype accent colours — single source of truth.
  static const statAttack   = Color(0xFFEF5350);
  static const statTrasher  = Color(0xFFAB47BC);
  static const statDuration = Color(0xFFFFB74D);
  static const statAltVP    = Color(0xFF66BB6A);

  // Landscape card left-accent strip.
  static const landscapeAccent = Color(0xFF7E57C2);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3:  true,
    brightness:    Brightness.dark,
    colorScheme:   const ColorScheme.dark(
      surface:          AppColors.surface,
      primary:          AppColors.gold,
      onPrimary:        Colors.black,
      secondary:        AppColors.goldDark,
      onSecondary:      Colors.black,
      error:            AppColors.errorRed,
      onSurface:        AppColors.parchment,
      surfaceContainer: AppColors.cardSurface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.surface,
      foregroundColor:  AppColors.parchment,
      centerTitle:      true,
      elevation:        0,
      scrolledUnderElevation: 2,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor:        AppColors.gold,
      unselectedLabelColor: AppColors.parchmentDim,
      indicatorColor:    AppColors.gold,
      dividerColor:      AppColors.divider,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.parchmentDim),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.goldDark.withValues(alpha: 0.5)
              : AppColors.divider),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.gold
              : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: const BorderSide(color: AppColors.parchmentDim, width: 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor:       AppColors.cardSurface,
      selectedColor:         AppColors.goldDark,
      labelStyle:            const TextStyle(color: AppColors.parchment, fontSize: 13),
      secondaryLabelStyle:   const TextStyle(color: Colors.black, fontSize: 13),
      side:                  const BorderSide(color: AppColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:          true,
      fillColor:       AppColors.cardSurface,
      hintStyle:       const TextStyle(color: AppColors.parchmentDim),
      prefixIconColor: AppColors.parchmentDim,
      border:          OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dividerTheme: const DividerThemeData(
      color:     AppColors.divider,
      thickness: 1,
      space:     1,
    ),
    listTileTheme: const ListTileThemeData(
      tileColor:      Colors.transparent,
      textColor:      AppColors.parchment,
      iconColor:      AppColors.parchmentDim,
      // Increased from vertical: 2 to meet touch target requirements.
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    textTheme: const TextTheme(
      titleLarge:  TextStyle(color: AppColors.parchment,    fontWeight: FontWeight.w700, fontSize: 17),
      titleMedium: TextStyle(color: AppColors.parchment,    fontWeight: FontWeight.w600, fontSize: 15),
      bodyLarge:   TextStyle(color: AppColors.parchment,    fontSize: 15),
      bodyMedium:  TextStyle(color: AppColors.parchmentDim, fontSize: 13),
      // Section-header label: gold, uppercase, tracked — used via textTheme.labelMedium.
      labelMedium: TextStyle(
        color:         AppColors.gold,
        fontSize:      11,
        fontWeight:    FontWeight.w700,
        letterSpacing: 1.4,
      ),
      labelSmall:  TextStyle(color: AppColors.parchmentDim, fontSize: 11),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.gold,
      foregroundColor: Colors.black,
      elevation:       4,
    ),
  );
}
