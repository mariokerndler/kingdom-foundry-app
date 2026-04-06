# Dominion Setup Assistant

A Flutter app that automates kingdom setup for the [Dominion](https://www.riograndegames.com/games/dominion/) deck-building board game. Pick your expansions, set optional rules, and get a balanced 10-card kingdom instantly — complete with a heuristic strategy analysis telling you which playstyles the kingdom supports.

---

## Features

- **Expansion picker** — select any combination of your owned Dominion sets (all 23 official expansions supported)
- **Rule modifiers** — exclude Attacks, Durations, Potion-cost or Debt-cost cards; guarantee a +Buy, trashing, or Village card appears
- **Max cost cap** — filter out cards above a configurable coin cost
- **Ban list** — permanently exclude individual cards from the pool
- **Heuristic Strategy Engine** — detects up to four strategic archetypes in the generated kingdom (Engine Building, Big Money, Aggressive/Control, Trash-to-Victory, Alt-Victory, Mirror Match) with strength scores and play tips
- **Setup notes** — automatically surfaces relevant reminders (add Platinum/Colony for Prosperity, set out Potions for Alchemy, etc.)
- **Persistent config** — owned expansions, rules, and ban list survive app restarts via `shared_preferences`
- **Web + mobile** — runs on Flutter Web, Android, and iOS

---

## Screenshots

> *(Add screenshots here once available)*

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.3.0
- Dart ≥ 3.3.0

### Run locally

```bash
git clone https://github.com/<your-username>/dominion-setup.git
cd dominion-setup
flutter pub get
flutter run
```

To run in Chrome:

```bash
flutter run -d chrome
```

### Build for web

```bash
flutter build web --release
```

The output lands in `build/web/` and can be served from any static host.

---

## Project Structure

```
lib/
├── main.dart                        # Entry point; SharedPreferences init
├── models/
│   ├── dominion_card.dart           # Core card data model
│   ├── card_type.dart               # CardType enum (Action, Attack, Duration …)
│   ├── card_tag.dart                # CardTag enum — 39 semantic tags for heuristics
│   ├── expansion.dart               # Expansion enum — all 23 sets with display names
│   ├── setup_rules.dart             # Immutable rules/filter config
│   ├── setup_result.dart            # Output of the generation pipeline
│   └── strategy_archetype.dart      # Archetype data class
├── controllers/
│   ├── setup_engine.dart            # 4-step kingdom generation pipeline
│   ├── heuristic_engine.dart        # Tag-based strategy analysis
│   └── setup_exception.dart         # Typed failure reasons
├── services/
│   ├── card_data_service.dart       # JSON asset loader with lazy cache
│   └── config_persistence_service.dart  # SharedPreferences load/save
├── providers/
│   ├── card_data_providers.dart     # Riverpod providers for card data
│   ├── config_provider.dart         # ConfigState + ConfigNotifier
│   └── generation_provider.dart     # Kingdom generation trigger + state
├── screens/
│   ├── configuration_screen.dart    # Tabbed config (Expansions / Rules / Ban)
│   └── results_screen.dart          # Kingdom grid + archetype cards
├── widgets/
│   ├── common/                      # SectionHeader, ExpansionBadge
│   ├── cards/                       # KingdomCardWidget, ArchetypeCard
│   └── screens/                     # ExpansionPickerTab, RulesTab, CardBanListTab
└── utils/
    └── app_theme.dart               # AppColors + Material 3 dark theme
assets/
└── data/
    └── cards.json                   # Card database (Base 2E, Intrigue 2E, Seaside 2E)
```

---

## Architecture

State management uses **Riverpod** (`StateNotifierProvider` / `FutureProvider`). All state is immutable with `copyWith` patterns.

### Generation pipeline (`SetupEngine`)

1. **Expansion filter** — keep only cards from owned expansions
2. **Manual exclusions** — remove user-banned cards (`isDisabled`)
3. **Rule modifiers** — apply active filters (no attacks, max cost, etc.)
4. **Weighted selection** — pick 10 cards with expansion-variety enforcement; retry up to 20× to satisfy requirements (village, +buy, trashing)

### Heuristic engine (`HeuristicEngine`)

Builds a `_KingdomProfile` by summing weighted tag scores across all 10 cards, then runs six independent scorers against threshold values. Archetypes are returned sorted by strength (0.0 – 1.0).

---

## Card Data

Card data lives in [`assets/data/cards.json`](assets/data/cards.json). Currently includes:

| Expansion | Cards |
|-----------|-------|
| Base (2nd Ed.) | 26 |
| Intrigue (2nd Ed.) | 26 |
| Seaside (2nd Ed.) | 15 |

Contributions adding additional expansions are welcome — see the existing JSON format for the schema.

### Card schema

```json
{
  "id": "village",
  "name": "Village",
  "expansion": "baseSecondEdition",
  "types": ["action"],
  "tags": ["plusAction", "plusTwoActions", "village"],
  "cost": 3,
  "text": "+1 Card. +2 Actions."
}
```

Optional fields: `debtCost` (int), `potionCost` (bool, default false).

---

## Dependencies

| Package | Purpose |
|---------|---------|
| [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) ^2.5.1 | State management |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) ^2.2.3 | Config persistence |

---

## Contributing

1. Fork the repo and create a feature branch
2. Run `flutter analyze` — no issues allowed
3. For new card data, validate your JSON with `node -e "JSON.parse(require('fs').readFileSync('assets/data/cards.json','utf8'))"` before committing
4. Open a pull request

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

> *Dominion is a registered trademark of Rio Grande Games. This project is an unofficial companion tool and is not affiliated with or endorsed by Rio Grande Games.*
