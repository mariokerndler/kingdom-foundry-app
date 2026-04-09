# Theme Refresh — Slate & Gold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dark-navy theme with a Slate & Gold design system — light default, system dark mode, DM Sans typography, and WCAG-AA-compliant contrast throughout.

**Architecture:** All theme values live in `lib/utils/app_theme.dart` (split into `buildLightTheme()` / `buildDarkTheme()`). Widget files replace hardcoded `AppColors.*` references with `Theme.of(context).colorScheme.*`. `AppColors` retains only archetype accents, error/success singletons, and the debt-badge iron constants.

**Tech Stack:** Flutter (Material 3), Riverpod, `google_fonts: ^6.2.1`

---

## File Map

| File | Action | Why |
|---|---|---|
| `pubspec.yaml` | Modify | Add google_fonts dependency |
| `lib/main.dart` | Modify | ThemeMode.system + new theme builders |
| `lib/utils/app_theme.dart` | Rewrite | New AppColors, buildLightTheme, buildDarkTheme, _buildTextTheme |
| `lib/widgets/common/player_count_bar.dart` | Modify | 4 AppColors refs → colorScheme |
| `lib/widgets/common/history_sheet.dart` | Modify | 15 AppColors refs → colorScheme |
| `lib/widgets/screens/expansion_picker.dart` | Modify | 26 AppColors refs → colorScheme |
| `lib/widgets/screens/rules_section.dart` | Modify | 49 AppColors refs → colorScheme |
| `lib/widgets/screens/card_ban_list.dart` | Modify | 17 AppColors refs → colorScheme |
| `lib/widgets/cards/archetype_card.dart` | Modify | 7 AppColors refs → colorScheme |
| `lib/widgets/cards/kingdom_card_widget.dart` | Modify | 27 refs + debt badge constants + split pile text migration |
| `lib/screens/results_screen.dart` | Modify | 27 AppColors refs → colorScheme |
| `lib/screens/configuration_screen.dart` | Modify | 21 AppColors refs → colorScheme |

---

## Task 1: Add google_fonts and wire ThemeMode.system

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add google_fonts to pubspec.yaml**

In `pubspec.yaml`, under `dependencies:`, add after `shared_preferences`:

```yaml
  # Typography
  google_fonts: ^6.2.1
```

- [ ] **Step 2: Fetch the package**

```bash
cd /Users/mario/Documents/Programming/Flutter/dominion-setup-app
flutter pub get
```

Expected: resolves without error, `pubspec.lock` updates.

- [ ] **Step 3: Update main.dart**

Replace the `DominionApp.build` method:

```dart
@override
Widget build(BuildContext context) {
  return MaterialApp(
    title:                      'Dominion Setup',
    debugShowCheckedModeBanner: false,
    theme:                      buildLightTheme(),
    darkTheme:                  buildDarkTheme(),
    themeMode:                  ThemeMode.system,
    home:                       const ConfigurationScreen(),
  );
}
```

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/main.dart
```

Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "feat: add google_fonts, wire ThemeMode.system"
```

---

## Task 2: Rewrite app_theme.dart

**Files:**
- Rewrite: `lib/utils/app_theme.dart`

- [ ] **Step 1: Write the new app_theme.dart**

Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Retained constants (no Material 3 colorScheme slot) ──────────────────────

abstract class AppColors {
  // Archetype accent strips — used on kingdom card tiles and chips
  static const statAttack      = Color(0xFFBE123C); // crimson rose
  static const statTrasher     = Color(0xFF7C3AED); // indigo-violet
  static const statDuration    = Color(0xFFB45309); // amber-brown
  static const statAltVP       = Color(0xFF15803D); // forest green
  static const landscapeAccent = Color(0xFF1D4ED8); // cobalt blue

  // Semantic singletons used in SnackBar / ScaffoldMessenger directly
  static const errorRed    = Color(0xFFDC2626);
  static const successGreen = Color(0xFF15803D); // same hue as statAltVP

  // Debt badge — intentionally fixed "iron" styling regardless of mode
  static const debtBadgeFill       = Color(0xFF334155);
  static const debtBadgeBorder     = Color(0xFF64748B);
  static const debtBadgeText       = Color(0xFFCBD5E1);
  static const debtBadgeFillDark   = Color(0xFF37474F);
  static const debtBadgeBorderDark = Color(0xFF78909C);
  static const debtBadgeTextDark   = Color(0xFFB0BEC5);
}

// ── Shared text theme ─────────────────────────────────────────────────────────

TextTheme _buildTextTheme(TextTheme base) =>
    GoogleFonts.dmSansTextTheme(base).copyWith(
      titleLarge:  GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge:   GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium:  GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400),
      labelLarge:  GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4,
      ),
      labelSmall: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500),
    );

// ── Light theme ───────────────────────────────────────────────────────────────

ThemeData buildLightTheme() {
  const cs = ColorScheme.light(
    surface:          Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF1F5F9),
    primary:          Color(0xFFC49A0A),
    onPrimary:        Color(0xFFFFFFFF),
    secondary:        Color(0xFFC49A0A),
    onSecondary:      Color(0xFFFFFFFF),
    onSurface:        Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF475569),
    outline:          Color(0xFF94A3B8),
    outlineVariant:   Color(0xFFE2E8F0),
    error:            Color(0xFFDC2626),
    onError:          Color(0xFFFFFFFF),
  );

  return _buildTheme(
    colorScheme:        cs,
    scaffoldBackground: const Color(0xFFF8F9FB),
    textTheme:          _buildTextTheme(ThemeData.light().textTheme),
  );
}

// ── Dark theme ────────────────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  const cs = ColorScheme.dark(
    surface:          Color(0xFF161B22),
    surfaceContainer: Color(0xFF1C2333),
    primary:          Color(0xFFD4A520),
    onPrimary:        Color(0xFFFFFFFF),
    secondary:        Color(0xFFD4A520),
    onSecondary:      Color(0xFFFFFFFF),
    onSurface:        Color(0xFFE6EDF3),
    onSurfaceVariant: Color(0xFF7D8590),
    outline:          Color(0xFF4D5566),
    outlineVariant:   Color(0xFF30363D),
    error:            Color(0xFFF87171),
    onError:          Color(0xFF1A0000),
  );

  return _buildTheme(
    colorScheme:        cs,
    scaffoldBackground: const Color(0xFF0D1117),
    textTheme:          _buildTextTheme(ThemeData.dark().textTheme),
  );
}

// ── Shared component builder ──────────────────────────────────────────────────

ThemeData _buildTheme({
  required ColorScheme colorScheme,
  required Color       scaffoldBackground,
  required TextTheme   textTheme,
}) {
  final isDark = colorScheme.brightness == Brightness.dark;

  return ThemeData(
    useMaterial3:            true,
    colorScheme:             colorScheme,
    scaffoldBackgroundColor: scaffoldBackground,
    textTheme:               textTheme,

    appBarTheme: AppBarTheme(
      backgroundColor:        colorScheme.surface,
      foregroundColor:        colorScheme.onSurface,
      centerTitle:            false,
      elevation:              0,
      scrolledUnderElevation: 1,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor:            colorScheme.primary,
      unselectedLabelColor:  colorScheme.onSurfaceVariant,
      indicatorColor:        colorScheme.primary,
      dividerColor:          colorScheme.outlineVariant,
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
      backgroundColor:     colorScheme.surfaceContainer,
      selectedColor:       colorScheme.primary,
      labelStyle:          TextStyle(color: colorScheme.onSurface, fontSize: 13),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
      side:                BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: colorScheme.surface,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      prefixIconColor: colorScheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:   BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    dividerTheme: DividerThemeData(
      color:     colorScheme.outlineVariant,
      thickness: 1,
      space:     1,
    ),

    listTileTheme: ListTileThemeData(
      tileColor:      Colors.transparent,
      textColor:      colorScheme.onSurface,
      iconColor:      colorScheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation:       4,
    ),

    cardTheme: CardThemeData(
      color:        colorScheme.surface,
      elevation:    isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side:         BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
  );
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/utils/app_theme.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/utils/app_theme.dart
git commit -m "feat: rewrite app_theme with Slate & Gold light/dark themes"
```

---

## Task 3: Migrate player_count_bar.dart

**Files:**
- Modify: `lib/widgets/common/player_count_bar.dart`

- [ ] **Step 1: Replace AppColors refs in the build method**

Replace the entire `build` method body (the `Container` and its contents):

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final count    = ref.watch(configProvider).playerCount;
  final notifier = ref.read(configProvider.notifier);
  final cs       = Theme.of(context).colorScheme;

  return Semantics(
    label: 'Player count: $count players',
    child: Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Text('Players', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 12),
          ...List.generate(5, (i) {
            final n        = i + 2;
            final selected = n == count;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: '$n players',
                child: Semantics(
                  label:    '$n players',
                  selected: selected,
                  button:   true,
                  excludeSemantics: true,
                  child: Material(
                    color:        Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        notifier.setPlayerCount(n);
                      },
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:  selected ? cs.primary : cs.surfaceContainer,
                          border: Border.all(
                            color: selected ? cs.primary : cs.outlineVariant,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$n',
                          style: TextStyle(
                            color:      selected ? cs.onPrimary : cs.onSurfaceVariant,
                            fontSize:   13,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Remove unused AppColors import if no longer needed**

Check the import at the top — if `AppColors` is no longer used, remove:
```dart
import '../../utils/app_theme.dart';
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/widgets/common/player_count_bar.dart
```

Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/common/player_count_bar.dart
git commit -m "feat: migrate player_count_bar to colorScheme"
```

---

## Task 4: Migrate history_sheet.dart

**Files:**
- Modify: `lib/widgets/common/history_sheet.dart`

- [ ] **Step 1: Update _HistorySheet.build — container decoration and header**

In `_HistorySheet.build`, replace the `DraggableScrollableSheet`'s inner `Container` decoration and header section. The key changes:

```dart
// Container decoration — was: AppColors.surface, goldDark top border, AppColors.divider handle
decoration: BoxDecoration(
  color:        Theme.of(ctx).colorScheme.surface,
  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
  border: Border(
    top: BorderSide(color: Theme.of(ctx).colorScheme.primary, width: 2),
  ),
),
```

Drag handle (inside Container's Column):
```dart
Container(
  margin: const EdgeInsets.only(top: 10),
  width: 40, height: 4,
  decoration: BoxDecoration(
    color:        Theme.of(ctx).colorScheme.outlineVariant,
    borderRadius: BorderRadius.circular(2),
  ),
),
```

Header icon and close button:
```dart
const Icon(Icons.history_rounded, size: 18),   // color from foregroundColor theme
// ...
IconButton(
  icon: Icon(Icons.close_rounded,
      color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
  tooltip: 'Close',
  onPressed: () => Navigator.pop(context),
),
```

Clear button — `AppColors.errorRed` is an explicit color choice for destructive action, keep it:
```dart
child: Text(
  'Clear',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: AppColors.errorRed,
  ),
),
```

- [ ] **Step 2: Update _HistoryTile — index bubble and text colors**

Replace the index bubble container:
```dart
Container(
  width: 28, height: 28,
  decoration: BoxDecoration(
    shape:  BoxShape.circle,
    color:  Theme.of(context).colorScheme.surfaceContainer,
    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
  ),
  alignment: Alignment.center,
  child: Text(
    '${index + 1}',
    style: TextStyle(
      color:      Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize:   11,
      fontWeight: FontWeight.w600,
    ),
  ),
),
```

Card names text:
```dart
Text(
  result.kingdomCards.map((c) => c.name).join(', '),
  style: TextStyle(
    color:  Theme.of(context).colorScheme.onSurface,
    fontSize: 13,
    height:   1.4,
  ),
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
),
```

Age/archetype text:
```dart
Flexible(
  child: Text(
    primary != null ? '${primary.headline} · $age' : age,
    style: TextStyle(
      color:    Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 11,
    ),
    textAlign: TextAlign.end,
    overflow:  TextOverflow.ellipsis,
    maxLines:  1,
  ),
),
```

Chevron icon:
```dart
Icon(Icons.chevron_right_rounded,
    color: Theme.of(context).colorScheme.outlineVariant, size: 18),
```

- [ ] **Step 3: Update _EmptyHistory**

```dart
@override
Widget build(BuildContext context) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.history_rounded, size: 48,
          color: Theme.of(context).colorScheme.outlineVariant),
      const SizedBox(height: 16),
      Text(
        'No kingdoms generated yet.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 4),
      Text(
        'Generate your first kingdom to see it here.',
        style: TextStyle(
            color:    Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12),
      ),
    ],
  ),
);
```

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/widgets/common/history_sheet.dart
```

Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/common/history_sheet.dart
git commit -m "feat: migrate history_sheet to colorScheme"
```

---

## Task 5: Migrate expansion_picker.dart

**Files:**
- Modify: `lib/widgets/screens/expansion_picker.dart`

- [ ] **Step 1: Remove inline TextField border overrides in the search bar**

The `InputDecorationTheme` in `app_theme.dart` already provides the correct borders. Remove the redundant inline `border`, `enabledBorder`, and `focusedBorder` from the `TextField`'s `InputDecoration`. Also remove `fillColor` and `hintStyle` overrides — the theme provides them. Replace the search `TextField` decoration:

```dart
TextField(
  controller: _searchCtrl,
  onChanged:  (v) => setState(() => _query = v.toLowerCase()),
  decoration: InputDecoration(
    hintText:  'Search expansions…',
    prefixIcon: const Icon(Icons.search_rounded, size: 20),
    suffixIcon: _query.isNotEmpty
        ? IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
          )
        : null,
  ),
),
```

- [ ] **Step 2: Update _GroupHeader — remove hardcoded AppColors.gold**

`_GroupHeader` uses `const TextStyle(color: AppColors.gold, ...)` which can't use Theme. Change `_GroupHeader.build` to resolve colors from context:

```dart
@override
Widget build(BuildContext context) {
  final primary = Theme.of(context).colorScheme.primary;
  return Padding(
    padding: const EdgeInsets.fromLTRB(2, 4, 0, 8),
    child: Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color:         primary,
            fontSize:      10,
            fontWeight:    FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color:        primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color:      primary,
              fontSize:   10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Update _ExpansionPickerTab — stats bar TextButton colors**

```dart
TextButton(
  onPressed: () {
    HapticFeedback.selectionClick();
    allOwned ? notifier.clearExpansions() : notifier.selectAllExpansions(available);
  },
  child: Text(
    allOwned ? 'Clear all' : 'Select all',
    style: TextStyle(
      color:    allOwned
          ? AppColors.errorRed  // keep — destructive action
          : Theme.of(context).colorScheme.primary,
      fontSize: 13,
    ),
  ),
),
```

- [ ] **Step 4: Update _ExpansionTile — background, border, dot, text colors**

Replace the `AnimatedContainer` decoration and all text/icon colors:

```dart
@override
Widget build(BuildContext context) {
  final badgeColor = Color(expansion.badgeColorValue);
  final cs         = Theme.of(context).colorScheme;

  return Semantics(
    label:  '${expansion.displayName}, '
            '${stats.kingdom} kingdom cards'
            '${stats.landscape > 0 ? ", ${stats.landscape} landscape cards" : ""}. '
            '${selected ? "Selected" : "Not selected"}. Tap to toggle.',
    button: true,
    child:  AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color:        selected
            ? badgeColor.withValues(alpha: 0.10)
            : cs.surfaceContainer,
        border:       Border.all(
          color: selected ? badgeColor : cs.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? badgeColor
                        : cs.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expansion.displayName,
                        style: TextStyle(
                          color:      selected ? cs.onSurface : cs.onSurfaceVariant,
                          fontSize:   14,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _CountPill(
                            icon:  Icons.grid_view_rounded,
                            label: '${stats.kingdom} kingdom',
                            color: selected
                                ? cs.onSurfaceVariant
                                : cs.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                          if (stats.landscape > 0) ...[
                            const SizedBox(width: 8),
                            _CountPill(
                              icon:  Icons.map_outlined,
                              label: '${stats.landscape} landscape',
                              color: selected
                                  ? cs.primary.withValues(alpha: 0.85)
                                  : cs.primary.withValues(alpha: 0.45),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color:        selected ? badgeColor : Colors.transparent,
                    border:       Border.all(
                      color: selected ? badgeColor : cs.outlineVariant,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Update _KingdomCountChip and _EmptySearch**

`_KingdomCountChip` — `AppColors.successGreen` and `AppColors.errorRed` are explicit semantic colors; keep them:

```dart
final enough = count! >= 10;
final color  = enough ? AppColors.successGreen : AppColors.errorRed;
// rest unchanged
```

`_EmptySearch`:
```dart
Icon(Icons.search_off_rounded, size: 40,
    color: Theme.of(context).colorScheme.onSurfaceVariant),
// ...
Text(
  'No expansions match "$query"',
  textAlign: TextAlign.center,
  style: TextStyle(
      color:    Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 14),
),
```

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/widgets/screens/expansion_picker.dart
```

Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/screens/expansion_picker.dart
git commit -m "feat: migrate expansion_picker to colorScheme"
```

---

## Task 6: Migrate rules_section.dart

**Files:**
- Modify: `lib/widgets/screens/rules_section.dart`

- [ ] **Step 1: Update _RuleTile**

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    margin:   const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    decoration: BoxDecoration(
      color:        value
          ? cs.primary.withValues(alpha: 0.08)
          : cs.surfaceContainer,
      border:       Border.all(
        color: value ? cs.primary : cs.outlineVariant,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: SwitchListTile(
      secondary: Icon(icon,
          size: 20, color: value ? cs.primary : cs.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          color:      value ? cs.onSurface : cs.onSurfaceVariant,
          fontWeight: value ? FontWeight.w500 : FontWeight.w400,
          fontSize:   14,
        ),
      ),
      subtitle: Text(
        detail,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      ),
      value:     value,
      onChanged: onChange,
      dense:     true,
    ),
  );
}
```

- [ ] **Step 2: Update _MaxCostRow and _MaxAttacksRow**

Both have identical patterns. For `_MaxCostRow`:

```dart
@override
Widget build(BuildContext context) {
  final cs     = Theme.of(context).colorScheme;
  final active = currentMax != null;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color:        active ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
        border:       Border.all(color: active ? cs.primary : cs.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            secondary: Icon(Icons.paid_outlined,
                size: 20, color: active ? cs.primary : cs.onSurfaceVariant),
            title: Text(
              active ? 'Max cost: \$$currentMax' : 'Enable max cost',
              style: TextStyle(
                color:      active ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                fontSize:   14,
              ),
            ),
            subtitle: Text(
              'Exclude cards that cost more than this.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            value:     active,
            onChanged: (v) => onChange(v ? 6 : null),
            dense:     true,
          ),
          if (active) ...[
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor:    cs.primary,
                inactiveTrackColor:  cs.outlineVariant,
                thumbColor:          cs.primary,
                overlayColor:        cs.primary.withValues(alpha: 0.12),
                valueIndicatorColor: cs.surfaceContainer,
                valueIndicatorTextStyle: TextStyle(color: cs.onSurface),
              ),
              child: Slider(
                min: 2, max: 8, divisions: 6,
                value:    currentMax!.toDouble(),
                label:    '\$$currentMax',
                onChanged: (v) => onChange(v.round()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [2, 3, 4, 5, 6, 7, 8]
                    .map((c) => Text('\$$c',
                        style: TextStyle(
                          fontSize: 11,
                          color: currentMax == c ? cs.primary : cs.onSurfaceVariant,
                        )))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

Apply the same pattern to `_MaxAttacksRow` — identical structure, just change the icon to `Icons.shield_outlined`, label to `'Enable attack limit'` / `'Max attacks: $currentMax'`, subtitle, min/max values (1–5, divisions: 4), and `onChange(v ? 2 : null)`.

- [ ] **Step 3: Update _LandscapeCountTile**

```dart
@override
Widget build(BuildContext context) {
  final cs         = Theme.of(context).colorScheme;
  final nonDefault = value != _default;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    margin:   const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    decoration: BoxDecoration(
      color:        nonDefault ? cs.primary.withValues(alpha: 0.08) : cs.surfaceContainer,
      border:       Border.all(color: nonDefault ? cs.primary : cs.outlineVariant),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20,
              color: nonDefault ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:      nonDefault ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: nonDefault ? FontWeight.w500 : FontWeight.w400,
                fontSize:   14,
              ),
            ),
          ),
          _Stepper(value: value, min: 0, max: max, onChange: onChange),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Update _Stepper and _StepBtn**

In `_Stepper`, the zero-value color uses `AppColors.errorRed` (keep — semantic warning) and `AppColors.parchment`:

```dart
child: Text(
  '$value',
  textAlign: TextAlign.center,
  style: TextStyle(
    color:      value == 0
        ? AppColors.errorRed  // keep — signals invalid zero count
        : Theme.of(context).colorScheme.onSurface,
    fontWeight: FontWeight.w600,
    fontSize:   15,
  ),
),
```

In `_StepBtn`:

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return SizedBox(
    width: 32, height: 32,
    child: Material(
      color:        enabled ? cs.surfaceContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap:        enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(6),
        child: Icon(
          icon,
          size:  16,
          color: enabled ? cs.onSurface : cs.outlineVariant,
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Update _ActiveRulesSummary**

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVE RULES',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: descriptions
              .map((d) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color:        cs.primary.withValues(alpha: 0.10),
                      border:       Border.all(color: cs.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      d,
                      style: TextStyle(
                          color: cs.primary, fontSize: 12),
                    ),
                  ))
              .toList(),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 6: Update the Reset all TextButton in RulesTab**

```dart
TextButton(
  onPressed: notifier.resetRules,
  child: const Text(
    'Reset all',
    style: TextStyle(color: AppColors.errorRed, fontSize: 13),  // keep — destructive
  ),
),
```

- [ ] **Step 7: Verify**

```bash
flutter analyze lib/widgets/screens/rules_section.dart
```

Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add lib/widgets/screens/rules_section.dart
git commit -m "feat: migrate rules_section to colorScheme"
```

---

## Task 7: Migrate card_ban_list.dart

**Files:**
- Modify: `lib/widgets/screens/card_ban_list.dart`

- [ ] **Step 1: Update _SearchBar TextField**

Remove the hardcoded `color: AppColors.parchment` from `style` — the `InputDecorationTheme` provides text color. Keep only:

```dart
TextField(
  controller: controller,
  decoration: const InputDecoration(
    hintText:   'Search cards...',
    prefixIcon: Icon(Icons.search_rounded),
  ),
),
```

- [ ] **Step 2: Update _ExpansionHeader**

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
    child: Row(
      children: [
        ExpansionBadge(expansion: expansion, fontSize: 11),
        const SizedBox(width: 10),
        Text(
          expansion.displayName,
          style: TextStyle(
              color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          '$count cards',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Update _CardRow**

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Semantics(
    label:  '${card.name}, ${isDisabled ? "banned" : "available"}',
    hint:   'Double tap to ${isDisabled ? "enable" : "ban"}',
    button: true,
    excludeSemantics: true,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity:  isDisabled ? 0.45 : 1.0,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:        cs.surfaceContainer,
            border:       Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _CostBadge(cost: card.cost),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: TextStyle(
                        color:      isDisabled ? cs.onSurfaceVariant : cs.onSurface,
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                        decoration: isDisabled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      card.typeString,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Checkbox(value: !isDisabled, onChanged: (_) => onToggle()),
            ],
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 4: Update _CostBadge (ban list local one)**

The ban list has its own simpler `_CostBadge` (takes `int cost`, not a string). Update to use theme:

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: cs.primary,
    ),
    alignment: Alignment.center,
    child: Text(
      '$cost',
      style: TextStyle(
        color:      cs.onPrimary,
        fontSize:   13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
```

- [ ] **Step 5: Update empty and error states**

`_EmptyState`:
```dart
Icon(Icons.library_books_outlined, size: 48,
    color: Theme.of(context).colorScheme.onSurfaceVariant),
// ...
Text('No expansions selected.',
    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
Text('Go to the Expansions tab to pick your sets.',
    style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
```

`_NoResults`:
```dart
Icon(Icons.search_off_rounded, size: 40,
    color: Theme.of(context).colorScheme.onSurfaceVariant),
// Text already uses Theme.of(context).textTheme.bodyMedium — no change needed
```

`_ErrorState` retry button — `AppColors.gold` → colorScheme.primary:
```dart
style: TextButton.styleFrom(
    foregroundColor: Theme.of(context).colorScheme.primary),
```

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/widgets/screens/card_ban_list.dart
```

Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/screens/card_ban_list.dart
git commit -m "feat: migrate card_ban_list to colorScheme"
```

---

## Task 8: Migrate archetype_card.dart

**Files:**
- Modify: `lib/widgets/cards/archetype_card.dart`

- [ ] **Step 1: Update _ArchetypeCardState.build**

Add `final cs = Theme.of(context).colorScheme;` at the top of `build`, then replace:

```dart
// Container decoration
decoration: BoxDecoration(
  color:        cs.surfaceContainer,
  borderRadius: BorderRadius.circular(12),
  border:       Border.all(
    color: widget.isPrimary ? color : cs.outlineVariant,
    width: widget.isPrimary ? 1.5 : 1,
  ),
),
```

Headline text (was `AppColors.parchment`):
```dart
Text(
  widget.archetype.headline,
  style: Theme.of(context).textTheme.titleLarge?.copyWith(
    color:    cs.onSurface,
    fontSize: widget.isPrimary ? 17 : 15,
  ),
),
```

Strength bar background (was `AppColors.divider`):
```dart
Container(height: 3, color: cs.outlineVariant),
```

Description text (was `AppColors.parchmentDim`):
```dart
Text(
  widget.archetype.description,
  style: TextStyle(
    color:    cs.onSurfaceVariant,
    fontSize: 13,
    height:   1.55,
  ),
),
```

Tips expand icon (was `AppColors.gold`):
```dart
AnimatedRotation(
  turns:    _tipsExpanded ? 0.5 : 0,
  duration: const Duration(milliseconds: 200),
  child: Icon(
    Icons.expand_more_rounded,
    color: cs.primary,
    size:  16,
  ),
),
```

- [ ] **Step 2: Update _TipRow**

```dart
@override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20, height: 20,
          margin: const EdgeInsets.only(top: 1, right: 10),
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color:    Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
              height:   1.45,
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Verify**

```bash
flutter analyze lib/widgets/cards/archetype_card.dart
```

Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/cards/archetype_card.dart
git commit -m "feat: migrate archetype_card to colorScheme"
```

---

## Task 9: Migrate kingdom_card_widget.dart

**Files:**
- Modify: `lib/widgets/cards/kingdom_card_widget.dart`

This file has three distinct concerns: the card tile, the debt badge, and the split pile partner display.

- [ ] **Step 1: Update KingdomCardWidget.build — accent strip and split pile label**

The `_accentColor` method returns archetype colors from `AppColors.*` constants — **no change needed there**.

In the `build` method, the split pile partner label uses `AppColors.gold`:

```dart
// Split pile partner label — replace AppColors.gold with colorScheme.primary
if (isSplit) ...[
  const SizedBox(height: 4),
  Row(
    children: [
      Icon(Icons.layers_rounded,
          size: 10, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          '+ ${splitPartner!.name}',
          style: TextStyle(
            color:      Theme.of(context).colorScheme.primary,
            fontSize:   10,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),
],
```

- [ ] **Step 2: Update _CostBadge — debt vs. coin, using new AppColors constants**

Replace the entire `_CostBadge.build`:

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs     = Theme.of(context).colorScheme;

  if (_isDebt) {
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      height:      26,
      padding:     const EdgeInsets.symmetric(horizontal: 6),
      decoration:  BoxDecoration(
        color:        isDark ? AppColors.debtBadgeFillDark   : AppColors.debtBadgeFill,
        borderRadius: BorderRadius.circular(5),
        border:       Border.all(
          color: isDark ? AppColors.debtBadgeBorderDark : AppColors.debtBadgeBorder,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        cost,
        style: TextStyle(
          color:      isDark ? AppColors.debtBadgeTextDark : AppColors.debtBadgeText,
          fontSize:   11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // Standard coin badge
  return Container(
    constraints: const BoxConstraints(minWidth: 26),
    height:      26,
    padding:     const EdgeInsets.symmetric(horizontal: 6),
    decoration:  BoxDecoration(
      shape:  BoxShape.circle,
      color:  cs.primary,
      border: Border.all(color: cs.primary.withValues(alpha: 0.7)),
    ),
    alignment: Alignment.center,
    child: Text(
      cost,
      style: TextStyle(
        color:      cs.onPrimary,
        fontSize:   11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
```

- [ ] **Step 3: Update _DetailCostBadge — same debt/coin pattern at larger size**

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs     = Theme.of(context).colorScheme;

  if (_isDebt) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      height:      40,
      padding:     const EdgeInsets.symmetric(horizontal: 8),
      decoration:  BoxDecoration(
        color:        isDark ? AppColors.debtBadgeFillDark   : AppColors.debtBadgeFill,
        borderRadius: BorderRadius.circular(7),
        border:       Border.all(
          color: isDark ? AppColors.debtBadgeBorderDark : AppColors.debtBadgeBorder,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        costString,
        style: TextStyle(
          color:      isDark ? AppColors.debtBadgeTextDark : AppColors.debtBadgeText,
          fontSize:   14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  return Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      shape:  BoxShape.circle,
      color:  cs.primary,
      border: Border.all(color: cs.primary.withValues(alpha: 0.7), width: 1.5),
    ),
    alignment: Alignment.center,
    child: Text(
      costString,
      style: TextStyle(
        color:      cs.onPrimary,
        fontSize:   14,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
```

- [ ] **Step 4: Update _SplitPartnerCard — migrate parchment/parchmentDim**

```dart
// partner card text (was AppColors.parchment)
Text(
  partner.text,
  style: TextStyle(
    color:    Theme.of(context).colorScheme.onSurface,
    fontSize: 13,
    height:   1.5,
  ),
),
```

The split pile section header in `_CardDetailSheet` uses `AppColors.gold` for "SPLIT PILE" label:
```dart
Text(
  'SPLIT PILE',
  style: Theme.of(context).textTheme.labelMedium,
  // labelMedium is already gold in both themes via _buildTextTheme
),
```

The subtitle "Both halves share one supply pile." uses `AppColors.parchmentDim`:
```dart
Text(
  'Both halves share one supply pile.',
  style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
),
```

In `_SplitPartnerCard`, the partner name uses `color: accent` (already correct — archetype color). The layers icon:
```dart
const Icon(Icons.layers_rounded, size: 13, color: AppColors.gold),
// → 
Icon(Icons.layers_rounded, size: 13,
    color: Theme.of(context).colorScheme.primary),
```

- [ ] **Step 5: Update remaining AppColors refs in _CardDetailSheet traveller chain**

In the traveller chain section of `_CardDetailSheet`, there are additional hardcoded color refs. Replace:

```dart
// Traveller chain label (was AppColors.gold)
Text(
  'TRAVELLER CHAIN',
  style: Theme.of(context).textTheme.labelMedium,
),

// Chain step card background (was AppColors.cardSurface / AppColors.divider)
color:  Theme.of(context).colorScheme.surfaceContainer,
border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),

// Chain step card name (was AppColors.parchment)
color: Theme.of(context).colorScheme.onSurface,

// Chain step card type / cost (was AppColors.parchmentDim)
color: Theme.of(context).colorScheme.onSurfaceVariant,
```

The `AppColors.gold` cost coin in the detail header is already handled by `_DetailCostBadge` in Step 3.

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/widgets/cards/kingdom_card_widget.dart
```

Expected: No issues found.

- [ ] **Step 7: Commit**

```bash
git add lib/widgets/cards/kingdom_card_widget.dart
git commit -m "feat: migrate kingdom_card_widget — debt badge, split pile, colorScheme"
```

---

## Task 10: Migrate results_screen.dart

**Files:**
- Modify: `lib/screens/results_screen.dart`

- [ ] **Step 1: Update SnackBar — AppColors.errorRed stays**

```dart
// Keep AppColors.errorRed — SnackBar backgroundColor is a direct Color, not theme-resolved
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content:         Text('Select at least one expansion first.'),
    backgroundColor: AppColors.errorRed,
    behavior:        SnackBarBehavior.floating,
  ),
);
```

- [ ] **Step 2: Update _ResultsAppBar subtitle (AppColors.gold)**

```dart
Text('Kingdom Generator',
    style: TextStyle(
      color:    Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
      fontSize: 11,
    )),
```

- [ ] **Step 3: Update copy icon and CircularProgressIndicator**

```dart
// Copy icon
Icon(Icons.copy_rounded,
    color: Theme.of(context).colorScheme.onSurfaceVariant)

// CircularProgressIndicator
valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary)

// Regenerate icon
Icon(Icons.casino_rounded,
    color: Theme.of(context).colorScheme.primary)
```

- [ ] **Step 4: Update landscape card container and kingdom card containers**

Find the landscape card section and kingdom card row section. Replace:

```dart
// Landscape card container (was AppColors.cardSurface / divider)
color:  Theme.of(context).colorScheme.surfaceContainer,
border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),

// Landscape accent strip stays: AppColors.landscapeAccent (kept constant)

// Kingdom card text colors
color: Theme.of(context).colorScheme.onSurface      // was AppColors.parchment
color: Theme.of(context).colorScheme.onSurfaceVariant  // was AppColors.parchmentDim

// Kingdom card cost/gold elements
color: Theme.of(context).colorScheme.primary         // was AppColors.gold / goldDark
```

- [ ] **Step 5: Update archetype stat strip section**

The four stat strip colors (`AppColors.statAttack`, `statTrasher`, `statDuration`, `statAltVP`) are `AppColors` constants that stay — no change needed.

Active/inactive indicator colors for the stat legend:
```dart
// was: active ? color : AppColors.divider
color: active ? color : Theme.of(context).colorScheme.outlineVariant

// was: active ? color : AppColors.parchmentDim
color: active ? color : Theme.of(context).colorScheme.onSurfaceVariant
```

- [ ] **Step 6: Update remaining AppColors.gold refs in the regenerating overlay and stat-strip section**

Regenerating overlay card:
```dart
// was AppColors.cardSurface / AppColors.divider
color:  Theme.of(context).colorScheme.surfaceContainer,
border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
```

Gold landscape accent label (AppColors.gold → primary):
```dart
color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
```

- [ ] **Step 7: Verify**

```bash
flutter analyze lib/screens/results_screen.dart
```

Expected: No issues found.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/results_screen.dart
git commit -m "feat: migrate results_screen to colorScheme"
```

---

## Task 11: Migrate configuration_screen.dart

**Files:**
- Modify: `lib/screens/configuration_screen.dart`

- [ ] **Step 1: Update _AppTitle**

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize:       MainAxisSize.min,
    children: [
      Text('Dominion Setup',
          style: TextStyle(
            color:      cs.onSurface,
            fontSize:   18,
            fontWeight: FontWeight.w700,
          )),
      Text('Kingdom Generator',
          style: TextStyle(
            color:    cs.primary.withValues(alpha: 0.8),
            fontSize: 11,
          )),
    ],
  );
}
```

- [ ] **Step 2: Update _GenerateFab**

```dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return FloatingActionButton.extended(
    onPressed:       isLoading ? null : onGenerate,
    backgroundColor: isLoading
        ? cs.primary.withValues(alpha: 0.6)
        : cs.primary,
    label: isLoading
        ? Row(
            children: [
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:  AlwaysStoppedAnimation(cs.onPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Text('Generating...',
                  style: TextStyle(
                      color:      cs.onPrimary,
                      fontWeight: FontWeight.w700)),
            ],
          )
        : Row(
            children: [
              const Icon(Icons.casino_rounded, size: 20),
              const SizedBox(width: 8),
              const Text('Generate Kingdom',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              if (activeRuleCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:        Colors.black.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$activeRuleCount rule${activeRuleCount == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: cs.onPrimary),
                  ),
                ),
              ],
            ],
          ),
  );
}
```

- [ ] **Step 3: Update _ImportDialog**

```dart
// AlertDialog backgroundColor
backgroundColor: Theme.of(context).colorScheme.surface,

// Title icon
Icon(Icons.paste_rounded,
    color: Theme.of(context).colorScheme.primary, size: 20)

// Title text
Text('Import Kingdom',
    style: TextStyle(
      color:      Theme.of(context).colorScheme.onSurface,
      fontSize:   17,
      fontWeight: FontWeight.w700,
    )),

// Description text
Text(
  'Paste a kingdom list shared from another player\'s device.',
  style: TextStyle(
      color:    Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 13),
),

// TextField style — remove inline color, theme handles it
style: const TextStyle(fontSize: 12, height: 1.6),

// Cancel button
TextButton(
  onPressed: () => Navigator.pop(context),
  child: Text('Cancel',
      style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
),

// Import button — active: primary gold, inactive: outlineVariant
TextButton(
  onPressed: isValid ? () => Navigator.pop(context, _ctrl.text) : null,
  child: Text(
    'Import Kingdom',
    style: TextStyle(
      color:      isValid
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outlineVariant,
      fontWeight: FontWeight.w700,
    ),
  ),
),
```

- [ ] **Step 4: Update _SetupErrorDialog**

```dart
// backgroundColor
backgroundColor: Theme.of(context).colorScheme.surface,

// Title
Text(title,
    style: TextStyle(
      color:      Theme.of(context).colorScheme.onSurface,
      fontSize:   16,
      fontWeight: FontWeight.w700,
    )),

// Body message
Text(message,
    style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13, height: 1.5)),

// Suggestion box
Container(
  decoration: BoxDecoration(
    color:        Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
    border:       Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
    borderRadius: BorderRadius.circular(8),
  ),
  // ...
  Icon(Icons.lightbulb_outline_rounded,
      color: Theme.of(context).colorScheme.primary, size: 15),
  Text(suggestion,
      style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12, height: 1.5)),
),

// OK button
TextButton(
  onPressed: () => Navigator.pop(context),
  child: Text('OK',
      style: TextStyle(
          color: Theme.of(context).colorScheme.primary)),
),
```

- [ ] **Step 5: Keep SnackBar errorRed**

```dart
// AppColors.errorRed stays for direct SnackBar backgroundColor
backgroundColor: AppColors.errorRed,
```

- [ ] **Step 6: Verify**

```bash
flutter analyze lib/screens/configuration_screen.dart
```

Expected: No issues found.

- [ ] **Step 7: Full analyze pass**

```bash
flutter analyze
```

Expected: No issues found across all files.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/configuration_screen.dart
git commit -m "feat: migrate configuration_screen to colorScheme"
```

---

## Task 12: Final verification

- [ ] **Step 1: Full analyze**

```bash
flutter analyze
```

Expected: No issues found.

- [ ] **Step 2: Build check (iOS)**

```bash
flutter build ios --no-codesign
```

Expected: Build succeeds with no errors.

- [ ] **Step 3: Visual verification checklist**

Run the app (`flutter run`) and confirm:

- [ ] Light mode: background is cool off-white, cards are white, gold FAB, gold tab indicator
- [ ] Dark mode (toggle device): background `#0D1117`, cards `#161B22`, brighter gold
- [ ] Configuration screen: player count pills, expansion tiles, rules switches all themed
- [ ] Results screen: archetype accent strips (crimson/indigo/amber/green), cost badges gold coin
- [ ] Debt cost card: shows dark iron badge (not gold coin)
- [ ] Split pile card: shows layers icon + partner name in gold below main card
- [ ] History sheet: white surface, gold top border, correct text hierarchy
- [ ] Dialogs: white surface, gold primary button, slate secondary text

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete Slate & Gold theme refresh

- Light mode default (ThemeMode.system), dark follows device preference
- DM Sans typography via google_fonts
- WCAG AA compliant contrast throughout
- Debt cost badge with iron/charcoal styling
- Split pile partner label uses colorScheme.primary"
```
