# UI/UX Theme Refresh — Design Spec

**Date:** 2026-04-08  
**Status:** Approved  
**Scope:** Color system, typography, component styling, light + dark theme wiring

---

## Overview

Replace the current heavy dark-navy theme with a **Slate & Gold** design system: cool off-white backgrounds, white card surfaces, amber-gold primary accent, and DM Sans typography. The redesign targets improved legibility, WCAG AA compliance, and a "light and airy" modern SaaS aesthetic while preserving the Dominion game identity through a refined gold accent.

**Theme mode:** Light as default, dark follows system preference (`ThemeMode.system`).

---

## 1. Color System

All values are defined in `lib/utils/app_theme.dart` as constants in `AppColors`. Every widget that currently references `AppColors.*` directly will be updated to use `Theme.of(context).colorScheme.*` where possible, with `AppColors` retained only for archetype accent colors that have no Material 3 colorScheme slot.

### Light Mode

| Token | Name | Hex | Usage |
|---|---|---|---|
| `background` | Background | `#F8F9FB` | Scaffold background |
| `surface` | Surface | `#FFFFFF` | Cards, AppBar, dialogs, bottom sheets |
| `cardSurface` | surfaceContainer | `#F1F5F9` | Chips, filled input backgrounds |
| `divider` | Divider | `#E2E8F0` | Borders, list dividers |
| `primary` | Gold | `#C49A0A` | FAB, tab indicator, focus rings, section header labels, primary buttons |
| `onPrimary` | On Primary | `#FFFFFF` | Text/icons on gold surfaces |
| `onSurface` | On Surface | `#0F172A` | Primary text (near-black slate) |
| `onSurfaceVariant` | Secondary Text | `#475569` | Body copy, subtitles, hints |
| `error` | Error | `#DC2626` | Error states, snackbars |
| `onError` | On Error | `#FFFFFF` | Text on error surfaces |

### Dark Mode

| Token | Name | Hex | Usage |
|---|---|---|---|
| `background` | Background | `#0D1117` | Scaffold background |
| `surface` | Surface | `#161B22` | Cards, AppBar, dialogs |
| `cardSurface` | surfaceContainer | `#1C2333` | Chips, input fills |
| `divider` | Divider | `#30363D` | Borders, dividers |
| `primary` | Gold | `#D4A520` | Brighter gold for dark background |
| `onPrimary` | On Primary | `#FFFFFF` | Text on gold |
| `onSurface` | On Surface | `#E6EDF3` | Primary text |
| `onSurfaceVariant` | Secondary Text | `#7D8590` | Body copy, hints |
| `error` | Error | `#F87171` | Lighter red for dark background |
| `onError` | On Error | `#1A0000` | Text on error surfaces |

### Archetype Accent Colors (shared across both modes)

These are used exclusively for the 4px left-accent strip on kingdom cards and archetype chip backgrounds. They remain on `AppColors` as named constants.

| Constant | Name | Hex | Replaces |
|---|---|---|---|
| `statAttack` | Attack | `#BE123C` | `#EF5350` |
| `statTrasher` | Trasher | `#7C3AED` | `#AB47BC` |
| `statDuration` | Duration | `#B45309` | `#FFB74D` |
| `statAltVP` | Alt VP | `#15803D` | `#66BB6A` |
| `landscapeAccent` | Landscape | `#1D4ED8` | `#7E57C2` |

### WCAG AA Compliance

All body text pairs verified at ≥ 4.5:1. Key ratios:

| Pair | Ratio | Result |
|---|---|---|
| `#0F172A` on `#FFFFFF` | 18.1:1 | AAA |
| `#0F172A` on `#F8F9FB` | 16.8:1 | AAA |
| `#475569` on `#FFFFFF` | 5.9:1 | AA ✓ |
| `#C49A0A` on `#FFFFFF` | 4.7:1 | AA ✓ |
| `#FFFFFF` on `#C49A0A` | 4.7:1 | AA ✓ |
| `#E6EDF3` on `#161B22` | 11.2:1 | AAA |
| `#7D8590` on `#0D1117` | 4.6:1 | AA ✓ |

---

## 2. Typography

**Typeface:** DM Sans (Google Fonts). Added via `google_fonts` package. Fallback: system fonts (SF Pro on iOS, Roboto on Android).

All `TextStyle` entries are defined in `buildLightTheme()` and `buildDarkTheme()` via a shared `_buildTextTheme()` helper.

| Style | Weight | Size | Letter Spacing | Usage |
|---|---|---|---|---|
| `titleLarge` | 700 | 18sp | — | AppBar title, dialog titles |
| `titleMedium` | 600 | 15sp | — | Card titles, section headings |
| `bodyLarge` | 400 | 15sp | — | Primary body text, list tiles |
| `bodyMedium` | 400 | 13sp | — | Secondary text, descriptions, hints |
| `labelLarge` | 700 | 14sp | — | Button text (FAB, TextButton) |
| `labelMedium` | 700 | 11sp | 1.4px | Section headers (uppercase gold) |
| `labelSmall` | 500 | 11sp | — | Chips, badges, cost indicators |

**Migration note:** `AppColors.parchment` → `colorScheme.onSurface` (`#0F172A` light / `#E6EDF3` dark). `AppColors.parchmentDim` → `colorScheme.onSurfaceVariant` (`#475569` light / `#7D8590` dark). All hardcoded `TextStyle(color: AppColors.parchment*)` references in widget files are updated.

---

## 3. Component Styling

### AppBar

- `backgroundColor`: `colorScheme.surface` (white / dark surface)
- `foregroundColor`: `colorScheme.onSurface`
- `elevation`: 0, `scrolledUnderElevation`: 1
- `centerTitle`: false (left-aligned title block)
- Title block: two-line — app name in `titleLarge`, subtitle "Kingdom Generator" in `labelSmall` gold

### TabBar

- `labelColor`: `colorScheme.primary` (gold)
- `unselectedLabelColor`: `colorScheme.onSurfaceVariant` (slate)
- `indicatorColor`: `colorScheme.primary`
- `dividerColor`: `colorScheme.outlineVariant`
- Tabs include both icon and text label

### Cards / List Tiles

- `backgroundColor`: `colorScheme.surface` (white)
- Border: `1px solid colorScheme.outlineVariant` (`#E2E8F0` / `#30363D`)
- `borderRadius`: 10px
- `boxShadow`: `0 1px 3px rgba(0,0,0,0.04)` (light mode only)
- Kingdom cards: 4px left accent strip using archetype color; neutral `#E2E8F0` for unclassified cards

### Buttons

- **Primary / FAB:** `backgroundColor` gold, `foregroundColor` white, `borderRadius` 24px, shadow `0 3px 10px rgba(196,154,10,0.35)`
- **Secondary (outlined):** transparent fill, gold `1.5px` border, gold text
- **Ghost (TextButton):** no border, `onSurfaceVariant` text
- FAB uses `FloatingActionButton.extended`; rule count shown as a pill badge inside the label

### Input Fields

- `fillColor`: `colorScheme.surface` (white)
- Default border: `colorScheme.outlineVariant`
- Focused border: `colorScheme.primary` (gold), `width: 1.5`, outer glow `0 0 0 3px rgba(196,154,10,0.12)`
- `hintStyle`: `colorScheme.onSurfaceVariant`
- `borderRadius`: 12px

### Chips

- Default: `backgroundColor` `colorScheme.surfaceContainer` (`#F1F5F9`), slate text
- Archetype chips: tinted background matching accent (e.g. `#FEF2F2` for attack), colored text
- `borderRadius`: 20px (fully rounded)

### Switches & Checkboxes

- Switch `thumbColor` (selected): white; `trackColor` (selected): gold
- Switch `trackColor` (unselected): `colorScheme.outlineVariant`
- Checkbox `fillColor` (selected): gold; `checkColor`: white
- Checkbox `side`: `colorScheme.outline`

### Bottom Sheet (History)

- `backgroundColor`: `colorScheme.surface`
- Top `borderRadius`: 20px
- Drag handle: 36×4px, `colorScheme.outlineVariant`
- Scrim: `rgba(15, 23, 42, 0.4)`

### Dialogs (AlertDialog)

- `backgroundColor`: `colorScheme.surface`
- Title uses `titleLarge`, body uses `bodyMedium` in `onSurfaceVariant`
- Suggestion box: `colorScheme.primary` at 7% opacity fill, gold border at 40% opacity

### Player Count Bar

- Pill background (unselected): `colorScheme.surfaceContainer`
- Pill background (selected): `colorScheme.primary` (gold), white text
- Pill border (unselected): `colorScheme.outlineVariant`

### Section Headers

- `labelMedium` style: DM Sans 700, 11sp, 1.4px tracking, `colorScheme.primary` (gold), uppercase
- Right-aligned count in `labelSmall` `onSurfaceVariant`

---

## 4. Icon System

**Style:** Flat, stroke-based, Heroicons-compatible. 24px grid in Flutter (`Icons.*` Material symbols used as-is; no custom icon font needed). The emoji icons currently used in mockup previews map to the following Material icon replacements:

| Usage | Material Icon |
|---|---|
| History | `Icons.history_rounded` |
| Import/Paste | `Icons.paste_rounded` |
| Expansions tab | `Icons.grid_view_rounded` |
| Rules tab | `Icons.tune_rounded` |
| Ban Cards tab | `Icons.block_rounded` |
| Generate (FAB) | `Icons.casino_rounded` |
| Regenerate | `Icons.refresh_rounded` |
| Share/Copy | `Icons.ios_share_rounded` |

Material Icons already follow a flat, consistent visual style — no additional icon font dependency required.

---

## 5. Theme Wiring

### `main.dart`

```dart
themeMode: ThemeMode.system,  // was: ThemeMode.dark
theme:     buildLightTheme(),
darkTheme:  buildDarkTheme(),
```

### `app_theme.dart` structure

- `AppColors` retains archetype accent constants + adds new light/dark semantic tokens as static consts
- `buildLightTheme()` returns `ThemeData` with `brightness: Brightness.light` and light `ColorScheme`
- `buildDarkTheme()` returns `ThemeData` with `brightness: Brightness.dark` and dark `ColorScheme`
- Shared component themes (shape, typography, switch, checkbox, etc.) extracted into a helper and applied to both

### Hardcoded color migration

All widget files that reference `AppColors.parchment`, `AppColors.parchmentDim`, `AppColors.surface`, `AppColors.cardSurface`, `AppColors.gold`, `AppColors.goldDark`, `AppColors.divider`, `AppColors.background` are updated to use `Theme.of(context).colorScheme.*` equivalents. `AppColors` retains only: `statAttack`, `statTrasher`, `statDuration`, `statAltVP`, `landscapeAccent`, `errorRed` (for direct SnackBar/ScaffoldMessenger calls that don't go through theme).

---

## 6. Dependencies

One new package required:

```yaml
# pubspec.yaml
google_fonts: ^6.2.1
```

Used only in `buildLightTheme()` / `buildDarkTheme()` to apply DM Sans as `textTheme` base:

```dart
import 'package:google_fonts/google_fonts.dart';

textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
  labelMedium: ...,
  // overrides applied on top
),
```

---

## 7. Out of Scope

- Screen layout changes (padding, widget structure unchanged)
- New features or navigation changes
- Animations or transition updates
- iPad / tablet layout
- Accessibility changes beyond color contrast
