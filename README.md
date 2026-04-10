# Kingdom Foundry

Kingdom Foundry is a Flutter app for generating balanced 10-card kingdoms for Dominion-style play. You can choose the expansions you own, apply setup constraints, ban specific cards, import shared kingdoms, and review strategy hints for the final board.

## Current Status

As of April 11, 2026, the app is functional and actively developed.

- The main generation flow is implemented and working.
- The configuration UI, results UI, import flow, and kingdom history are all present.
- Card data currently includes 755 cards across 16 expansions.
- `flutter test` passes.
- `flutter analyze` reports no issues.

## Implemented Features

- Expansion selection for owned sets.
- Rule filters for attacks, cursers, durations, potion-cost cards, debt-cost cards, and travellers.
- Requirement rules for `+Buy`, trashing, village, draw, attack/reaction pairing, attack caps, max cost, and minimum expansion variety.
- Landscape support for Events, Projects, Landmarks, Ways, Allies, Traits, and Prophecies.
- Split-pile handling so linked piles are selected together but count as one kingdom slot.
- Setup notes for special cases such as Liaison/Ally, Omen/Prophecy, Loot, Travellers, and other expansion-specific extras.
- Heuristic archetype analysis for generated or imported kingdoms.
- Clipboard import for shared kingdom lists.
- Local history for the last 10 generated kingdoms.
- Persistent preferences using `shared_preferences`.
- Flutter targets for Web, Android, iOS, and Windows.

## Card Coverage

The current card database lives in [`assets/data/cards.json`](/Users/mario/Documents/Programming/Flutter/dominion-setup-app/assets/data/cards.json).

| Expansion | Cards |
| --- | ---: |
| Adventures | 58 |
| Alchemy | 12 |
| Allies | 72 |
| Base (2nd Ed.) | 26 |
| Cornucopia & Guilds (2nd Ed.) | 32 |
| Dark Ages | 47 |
| Empires | 71 |
| Hinterlands (2nd Ed.) | 26 |
| Intrigue (2nd Ed.) | 26 |
| Menagerie | 71 |
| Nocturne | 77 |
| Plunder | 85 |
| Prosperity (2nd Ed.) | 25 |
| Renaissance | 50 |
| Rising Sun | 50 |
| Seaside (2nd Ed.) | 27 |

Total: 755 cards.

## Quality Checks

The current automated checks in this branch cover:

- Kingdom generation rules and failure cases.
- Heuristic archetype scoring.
- Clipboard import parsing.
- Landscape and expansion-specific behaviors such as Allies, Plunder, and Rising Sun.

Run locally with:

```bash
flutter test
flutter analyze
```

## Getting Started

### Prerequisites

- Flutter SDK 3.3.0 or newer
- Dart 3.3.0 or newer

### Run locally

```bash
flutter pub get
flutter run
```

To run in Chrome:

```bash
flutter run -d chrome
```

## Project Structure

```text
lib/
├── controllers/   # Kingdom generation, heuristics, typed failures
├── models/        # Card, rules, setup result, enums
├── providers/     # Riverpod state and async loading
├── screens/       # Main configuration and results screens
├── services/      # Card loading, persistence, history
├── utils/         # Theme and archetype helpers
└── widgets/       # Reusable UI for cards, tabs, sheets, and sections
assets/data/
└── cards.json     # Card database
test/
└── ...            # Engine, parser, and widget tests
```

## Notes

- Public app name: `Kingdom Foundry`
- Flutter package name: `kingdom_foundry`
- Main card model: `KingdomCard`

This is an unofficial companion project and is not affiliated with or endorsed by the publisher of Dominion.
