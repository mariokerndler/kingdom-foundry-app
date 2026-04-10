import 'package:flutter/material.dart';

import '../models/strategy_archetype.dart';

/// Canonical archetype colour and icon helpers.
/// Single source of truth — consumed by [ArchetypeCard] and [ResultsScreen]
/// so both widgets stay in sync automatically.
abstract class ArchetypeUtils {
  static Color color(ArchetypeKind kind) {
    switch (kind) {
      case ArchetypeKind.engineBuilding:
        return const Color(0xFF42A5F5);
      case ArchetypeKind.bigMoney:
        return const Color(0xFFFFD54F);
      case ArchetypeKind.aggressiveControl:
        return const Color(0xFFEF5350);
      case ArchetypeKind.trashToVictory:
        return const Color(0xFFAB47BC);
      case ArchetypeKind.altVictory:
        return const Color(0xFF66BB6A);
      case ArchetypeKind.extraTurns:
        return const Color(0xFF5C6BC0);
      case ArchetypeKind.mirrorMatch:
        return const Color(0xFF26C6DA);
    }
  }

  static IconData icon(ArchetypeKind kind) {
    switch (kind) {
      case ArchetypeKind.engineBuilding:
        return Icons.hub_rounded;
      case ArchetypeKind.bigMoney:
        return Icons.monetization_on_outlined;
      case ArchetypeKind.aggressiveControl:
        return Icons.local_fire_department_rounded;
      case ArchetypeKind.trashToVictory:
        return Icons.delete_sweep_rounded;
      case ArchetypeKind.altVictory:
        return Icons.emoji_events_rounded;
      case ArchetypeKind.extraTurns:
        return Icons.update_rounded;
      case ArchetypeKind.mirrorMatch:
        return Icons.compare_arrows_rounded;
    }
  }
}
