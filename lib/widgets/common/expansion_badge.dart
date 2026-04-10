import 'package:flutter/material.dart';

import '../../models/expansion.dart';

/// A small coloured pill showing an expansion's abbreviation.
class ExpansionBadge extends StatelessWidget {
  final Expansion expansion;
  final double fontSize;

  const ExpansionBadge({
    super.key,
    required this.expansion,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(expansion.badgeColorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _abbrev(expansion),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _abbrev(Expansion e) {
    switch (e) {
      case Expansion.base:
        return 'BASE';
      case Expansion.baseSecondEdition:
        return 'BASE2';
      case Expansion.intrigue:
        return 'INT';
      case Expansion.intrigueSecondEdition:
        return 'INT2';
      case Expansion.seaside:
        return 'SEA';
      case Expansion.seasideSecondEdition:
        return 'SEA2';
      case Expansion.alchemy:
        return 'ALC';
      case Expansion.prosperity:
        return 'PROS';
      case Expansion.prosperitySecondEdition:
        return 'PROS2';
      case Expansion.cornucopia:
        return 'CORN';
      case Expansion.cornucopiaGuildsSecondEdition:
        return 'C&G2';
      case Expansion.hinterlands:
        return 'HINT';
      case Expansion.hinterlandsSecondEdition:
        return 'HINT2';
      case Expansion.darkAges:
        return 'DARK';
      case Expansion.guilds:
        return 'GLD';
      case Expansion.adventures:
        return 'ADV';
      case Expansion.empires:
        return 'EMP';
      case Expansion.nocturne:
        return 'NOC';
      case Expansion.renaissance:
        return 'REN';
      case Expansion.menagerie:
        return 'MEN';
      case Expansion.allies:
        return 'ALL';
      case Expansion.plunder:
        return 'PLU';
      case Expansion.risingSun:
        return 'RSN';
      case Expansion.promos:
        return 'PRO';
    }
  }
}
