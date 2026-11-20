import 'setup_result.dart';
import 'table_setup_choice.dart';

List<String> tableChecklist(SetupResult result, int players) {
  players = players.clamp(2, 6);
  final victory = players == 2 ? 8 : 12;
  final provinces = players <= 4 ? victory : players * 3;
  const landmarksWithStartingVp = {
    'arena',
    'basilica',
    'baths',
    'battlefield',
    'colonnade',
    'labyrinth'
  };
  return [
    if (result.sheltersChoice == TableSetupChoice.include)
      'Starting decks for $players players: give each player 7 Coppers, one Hovel, one Necropolis and one Overgrown Estate instead of the 3 starting Estates. Apply any Heirloom changes listed below.'
    else
      'Starting decks for $players players: give each player 7 Coppers and 3 Estates, with any Heirloom${result.sheltersChoice == TableSetupChoice.undecided ? ' or Shelter' : ''} changes listed below.',
    'Base Supply: $victory Estates, $victory Duchies, $provinces Provinces and ${(players - 1) * 10} Curses. Use the remaining Coppers and all Silvers and Golds.',
    if (players > 4)
      'Use the additional Treasure cards from a second set of base cards.',
    if (result.platinumColonyChoice == TableSetupChoice.include)
      'Platinum and Colony: add all 12 Platinums and $victory Colonies alongside Gold and Province, outside the ten Kingdom slots. An empty Colony pile also ends the game at the end of the turn.'
    else if (result.platinumColonyChoice == TableSetupChoice.exclude)
      'Platinum and Colony: not used.',
    if (result.sheltersChoice == TableSetupChoice.include)
      'Shelters replace starting Estates only. The Estate Supply still contains $victory Estates; Shelters are not Supply piles.'
    else if (result.sheltersChoice == TableSetupChoice.exclude)
      'Shelters: not used.',
    for (final landmark in result.landscapeCards
        .where((card) => landmarksWithStartingVp.contains(card.id)))
      '${landmark.name}: put ${players * 6} VP on this Landmark before play.',
    'Kingdom Supply: use 10 cards for a standard pile and $victory for a standard Victory pile. Follow the special instructions for mixed and other special piles.',
    if (result.kingdomSlotIds.contains('joust') ||
        result.setupChoices.containsValue('joust'))
      'Joust: set aside ${players == 2 ? 'one copy' : 'two copies'} of each Reward outside the Supply.',
    if (result.landscapeCards.any((card) => card.isProphecy))
      'Place ${const [
        5,
        8,
        10,
        12,
        13
      ][players - 2]} Sun tokens on the Prophecy.',
    for (final note in result.setupNotes)
      if (!(result.platinumColonyChoice != TableSetupChoice.undecided &&
              note.startsWith('Prosperity cards present:')) &&
          !(result.sheltersChoice != TableSetupChoice.undecided &&
              note.startsWith('Dark Ages present:')))
        note,
  ];
}
