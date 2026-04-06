/// Every official Dominion expansion.
enum Expansion {
  base,
  baseSecondEdition,
  intrigue,
  intrigueSecondEdition,
  seaside,
  seasideSecondEdition,
  alchemy,
  prosperity,
  prosperitySecondEdition,
  cornucopia,
  hinterlands,
  hinterlandsSecondEdition,
  darkAges,
  guilds,
  adventures,
  empires,
  nocturne,
  renaissance,
  menagerie,
  allies,
  plunder,
  risingSun,
  promos,
}

extension ExpansionExtension on Expansion {
  String get displayName {
    switch (this) {
      case Expansion.base:                    return 'Base';
      case Expansion.baseSecondEdition:       return 'Base (2nd Ed.)';
      case Expansion.intrigue:                return 'Intrigue';
      case Expansion.intrigueSecondEdition:   return 'Intrigue (2nd Ed.)';
      case Expansion.seaside:                 return 'Seaside';
      case Expansion.seasideSecondEdition:    return 'Seaside (2nd Ed.)';
      case Expansion.alchemy:                 return 'Alchemy';
      case Expansion.prosperity:              return 'Prosperity';
      case Expansion.prosperitySecondEdition: return 'Prosperity (2nd Ed.)';
      case Expansion.cornucopia:              return 'Cornucopia';
      case Expansion.hinterlands:             return 'Hinterlands';
      case Expansion.hinterlandsSecondEdition:return 'Hinterlands (2nd Ed.)';
      case Expansion.darkAges:                return 'Dark Ages';
      case Expansion.guilds:                  return 'Guilds';
      case Expansion.adventures:              return 'Adventures';
      case Expansion.empires:                 return 'Empires';
      case Expansion.nocturne:                return 'Nocturne';
      case Expansion.renaissance:             return 'Renaissance';
      case Expansion.menagerie:               return 'Menagerie';
      case Expansion.allies:                  return 'Allies';
      case Expansion.plunder:                 return 'Plunder';
      case Expansion.risingSun:               return 'Rising Sun';
      case Expansion.promos:                  return 'Promos';
    }
  }

  /// Icon/badge color used on cards in the UI.
  int get badgeColorValue {
    switch (this) {
      case Expansion.base:
      case Expansion.baseSecondEdition:       return 0xFF8B4513; // Brown
      case Expansion.intrigue:
      case Expansion.intrigueSecondEdition:   return 0xFF9B1B30; // Crimson
      case Expansion.seaside:
      case Expansion.seasideSecondEdition:    return 0xFF0077B6; // Ocean Blue
      case Expansion.alchemy:                 return 0xFF6A0DAD; // Purple
      case Expansion.prosperity:
      case Expansion.prosperitySecondEdition: return 0xFFFFD700; // Gold
      case Expansion.cornucopia:              return 0xFFE67E22; // Orange
      case Expansion.hinterlands:
      case Expansion.hinterlandsSecondEdition:return 0xFF8B6914; // Tan
      case Expansion.darkAges:               return 0xFF2C2C2C; // Dark Grey
      case Expansion.guilds:                  return 0xFF6B4C11; // Bronze
      case Expansion.adventures:             return 0xFF2E7D32; // Forest Green
      case Expansion.empires:                return 0xFF880000; // Dark Red
      case Expansion.nocturne:               return 0xFF1A1A2E; // Midnight
      case Expansion.renaissance:            return 0xFF4A148C; // Deep Purple
      case Expansion.menagerie:              return 0xFF1B5E20; // Dark Green
      case Expansion.allies:                 return 0xFF006064; // Teal
      case Expansion.plunder:               return 0xFF37474F; // Steel
      case Expansion.risingSun:             return 0xFFB71C1C; // Red
      case Expansion.promos:               return 0xFF546E7A; // Blue Grey
    }
  }
}
