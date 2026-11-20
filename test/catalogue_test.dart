import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/controllers/heuristic_engine.dart';
import 'package:kingdom_foundry/controllers/setup_engine.dart';
import 'package:kingdom_foundry/models/card_metadata.dart';
import 'package:kingdom_foundry/models/card_tag.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/share_payload.dart';
import 'package:kingdom_foundry/models/setup_rules.dart';
import 'package:kingdom_foundry/models/share_codebook.dart';
import 'package:kingdom_foundry/models/strategy_archetype.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/services/translation_service.dart';

void main() {
  final cards =
      (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  test(
      'reviewed capabilities distinguish cycling, draw, defense and own-deck trashing',
      () {
    final parsed = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    expect(parsed['market']!.capabilities.draw, DrawCapability.cycling);
    expect(parsed['market']!.metadata.engineSupport, EngineSupportLevel.low);
    expect(parsed['laboratory']!.providesDraw, isTrue);
    expect(parsed['library']!.capabilities.draw, DrawCapability.conditional);
    expect(parsed['village']!.providesExtraActions, isTrue);
    expect(parsed['throneRoom']!.providesExtraActions, isFalse);
    expect(
        parsed['chapel']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(parsed['bandit']!.trashesOwnCards, isFalse);
    expect(parsed['moat']!.capabilities.defensiveReaction, isTrue);
    for (final id in [
      'diplomat',
      'caravan_guard',
      'pirate',
      'watchtower',
      'guardian'
    ]) {
      expect(parsed[id]!.capabilities.defensiveReaction, isFalse, reason: id);
    }
    expect(parsed['guardian']!.isReaction, isFalse);
    expect(parsed['ferryman']!.capabilities.dependencies,
        contains(SetupDependency.ferrymanPile));
    expect(parsed['ferryman']!.metadata.setupWeight, SetupWeight.medium);

    final kingdom = [
      'market',
      'village',
      'merchant',
      'harbinger',
      'cellar',
      'poacher',
      'festival',
      'bandit',
      'mine',
      'artisan'
    ].map((id) => parsed[id]!).toList();
    expect(
        SetupEngine()
            .poolConflict(kingdom, const SetupRules(requireDraw: true))
            ?.message,
        contains('No permitted Draw pile'));
    expect(HeuristicEngine().analyze(kingdom).map((a) => a.kind),
        isNot(contains(ArchetypeKind.engineBuilding)));
  });

  test('Ferryman has its printed cost', () {
    expect(cards.singleWhere((card) => card['id'] == 'ferryman')['cost'], 5);
  });

  test('retired first-edition requirements use reviewed direct capabilities',
      () {
    final retired = cards
        .map(KingdomCard.fromJson)
        .where((card) =>
            card.firstEditionOnly &&
            card.isKingdomCard &&
            card.expansion != Expansion.baseSecondEdition)
        .toList();
    expect(retired, hasLength(40));
    expect(
        retired.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'scout',
          'tribute',
          'ghost_ship',
          'counting_house',
          'horse_traders',
          'embassy',
          'oracle'
        ]));
    expect(
        retired
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(['tribute', 'farming_village']));
    expect(retired.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['loan', 'trade_route', 'doctor', 'taxman']));
    final byId = {for (final card in retired) card.id: card};
    expect(byId['doctor']!.capabilities.trashing, TrashingThroughput.multiple);
    for (final id in ['secret_chamber', 'horse_traders']) {
      expect(byId[id]!.capabilities.defensiveReaction, isFalse);
    }
    for (final id in [
      'great_hall',
      'pearl_diver',
      'farming_village',
      'tournament',
      'secret_chamber'
    ]) {
      expect(byId[id]!.providesDraw, isFalse, reason: id);
    }
    final filler = [
      'coppersmith',
      'great_hall',
      'saboteur',
      'ambassador',
      'embargo',
      'explorer',
      'navigator',
      'pearl_diver',
      'pirate_ship'
    ].map((id) => byId[id]!).toList();
    for (final id in ['counting_house', 'horse_traders']) {
      expect(
          SetupEngine().poolConflict(
              [...filler, byId[id]!], const SetupRules(requireDraw: true)),
          isNull,
          reason: id);
    }
    expect(
        SetupEngine().poolConflict([...filler, byId['secret_chamber']!],
            const SetupRules(requireDraw: true))?.message,
        contains('Draw'));
  });

  test('retired cards retain current timing and Prize errata in both languages',
      () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final byId = {for (final card in catalogue) card.id: card};
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        byId.keys.toSet());
    expect(byId['princess']!.text,
        '+1 Buy. This turn, cards cost \$2 less, but not less than \$0.');
    expect(german.lookup('princess')!.text, contains('In diesem Zug'));
    expect(german.lookup('princess')!.text, isNot(contains('im Spiel')));
    expect(byId['trade_route']!.text,
        contains('Trash a card from your hand, then get'));
    expect(german.lookup('trade_route')!.text,
        contains('Entsorge eine Handkarte. Danach'));
    expect(byId['taxman']!.text, contains('If you do, each other player'));
    expect(byId['taxman']!.text, contains('and you gain a Treasure'));
    expect(german.lookup('taxman')!.text,
        contains('Wenn du das tust, legt jeder Mitspieler'));
    expect(german.lookup('taxman')!.text,
        contains('und du nimmst eine Geldkarte'));
    expect(byId['embargo']!.text, contains('Trash this. If you did'));
    for (final id in ['goons', 'royal_seal', 'talisman']) {
      expect(byId[id]!.text.toLowerCase(), contains('in play'), reason: id);
    }
    final prizes =
        catalogue.where((card) => card.types.contains(CardType.prize));
    expect(prizes, hasLength(5));
    expect(prizes.every((card) => card.isAuxiliary && card.cost == 0), isTrue);
    expect(byId['followers']!.capabilities.draw, DrawCapability.net);
    expect(byId['trusty_steed']!.capabilities.draw, DrawCapability.conditional);
    expect(byId['trusty_steed']!.text,
        contains('put your deck into your discard pile'));
  });

  test('German covers retired Intrigue and Seaside with printed names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    const names = {
      'coppersmith': 'Kupferschmied',
      'great_hall': 'Große Halle',
      'saboteur': 'Saboteur',
      'scout': 'Späher',
      'secret_chamber': 'Geheimkammer',
      'tribute': 'Tribut',
      'ambassador': 'Botschafter',
      'embargo': 'Embargo',
      'explorer': 'Entdecker',
      'ghost_ship': 'Geisterschiff',
      'navigator': 'Navigator',
      'pearl_diver': 'Perlentaucher',
      'pirate_ship': 'Piratenschiff',
      'sea_hag': 'Seehexe',
    };
    final retired = catalogue.where((card) =>
        card.firstEditionOnly &&
        [Expansion.intrigueSecondEdition, Expansion.seasideSecondEdition]
            .contains(card.expansion));
    expect(retired.map((card) => card.id), unorderedEquals(names.keys));
    for (final entry in names.entries) {
      expect(german.lookup(entry.key)?.isComplete, isTrue, reason: entry.key);
      expect(german.lookup(entry.key)!.name, entry.value, reason: entry.key);
    }
    for (final expansion in [
      Expansion.intrigueSecondEdition,
      Expansion.seasideSecondEdition
    ]) {
      expect(
          catalogue.where((card) =>
              card.expansion == expansion &&
              german.lookup(card.id)?.isComplete != true),
          isEmpty);
    }
    final imported = resolveSetupText(
        catalogue,
        'Kupferschmied\nGroße Halle\nSpäher\nGeheimkammer\nTribut\n'
        'Botschafter\nEntdecker\nGeisterschiff\nPerlentaucher\nPiratenschiff',
        packs: [german]);
    expect(
        imported.kingdom.map((card) => card.id),
        unorderedEquals([
          'coppersmith',
          'great_hall',
          'scout',
          'secret_chamber',
          'tribute',
          'ambassador',
          'explorer',
          'ghost_ship',
          'pearl_diver',
          'pirate_ship',
        ]));
    expect(german.lookup('tribute')!.text,
        contains('unterschiedlichen aufgedeckten Kartennamen'));
    expect(german.lookup('embargo')!.text,
        contains('Entsorge diese Karte. Wenn du das getan hast'));
    expect(german.lookup('secret_chamber')!.text,
        contains('Ziehe dann 2 Karten und lege danach 2 Handkarten'));
    expect(german.lookup('pirate_ship')!.text,
        contains('mindestens ein Mitspieler eine Geldkarte entsorgt'));
    expect(
        german.lookup('ghost_ship')!.text, contains('mindestens 4 Handkarten'));
    expect(german.lookup('sea_hag')!.text,
        contains('danach einen Fluch oben auf seinen Nachziehstapel'));
  });

  test('German covers retired Prosperity and Hinterlands with printed names',
      () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    const names = {
      'contraband': 'Schmuggelware',
      'counting_house': 'Leihhaus',
      'goons': 'Halsabschneider',
      'loan': 'Lohn',
      'mountebank': 'Quacksalber',
      'royal_seal': 'Königliches Siegel',
      'talisman': 'Talisman',
      'trade_route': 'Handelsroute',
      'venture': 'Abenteuer',
      'cache': 'Schatztruhe',
      'duchess': 'Herzogin',
      'embassy': 'Botschaft',
      'ill_gotten_gains': 'Blutzoll',
      'mandarin': 'Mandarin',
      'noble_brigand': 'Edler Räuber',
      'nomad_camp': 'Nomadencamp',
      'oracle': 'Orakel',
      'silk_road': 'Seidenstraße',
    };
    final retired = catalogue.where((card) =>
        card.firstEditionOnly &&
        [Expansion.prosperitySecondEdition, Expansion.hinterlandsSecondEdition]
            .contains(card.expansion));
    expect(retired.map((card) => card.id), unorderedEquals(names.keys));
    for (final entry in names.entries) {
      expect(german.lookup(entry.key)?.isComplete, isTrue, reason: entry.key);
      expect(german.lookup(entry.key)!.name, entry.value, reason: entry.key);
    }
    for (final expansion in [
      Expansion.prosperitySecondEdition,
      Expansion.hinterlandsSecondEdition
    ]) {
      expect(
          catalogue.where((card) =>
              card.expansion == expansion &&
              german.lookup(card.id)?.isComplete != true),
          isEmpty);
    }
    final imported = resolveSetupText(
        catalogue,
        'Leihhaus\nLohn\nHalsabschneider\nAbenteuer\nHandelsroute\n'
        'Herzogin\nEdler Räuber\nNomadencamp\nBlutzoll\nSeidenstraße',
        packs: [german]);
    expect(
        imported.kingdom.map((card) => card.id),
        unorderedEquals([
          'counting_house',
          'loan',
          'goons',
          'venture',
          'trade_route',
          'duchess',
          'noble_brigand',
          'nomad_camp',
          'ill_gotten_gains',
          'silk_road',
        ]));
    expect(german.lookup('noble_brigand')!.text,
        contains('ausspielst oder kaufst'));
    expect(german.lookup('noble_brigand')!.text,
        contains('keine Geldkarte aufgedeckt'));
    expect(german.lookup('oracle')!.text,
        contains('in einer von ihm gewählten Reihenfolge'));
    expect(
        german.lookup('goons')!.text, contains('Solange diese Karte im Spiel'));
    expect(german.lookup('duchess')!.text,
        contains('In Spielen mit dem Herzogin-Stapel'));
    expect(
        german.lookup('venture')!.text, contains('Karten ab und spiele dann'));
    expect(german.lookup('trade_route')!.text,
        contains('zum ersten Mal eine Karte'));
  });

  test('German covers the entire catalogue including both Cornucopia editions',
      () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(
        german.cards.keys, unorderedEquals(catalogue.map((card) => card.id)));
    expect(
        catalogue.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final cornucopia = catalogue
        .where(
            (card) => card.expansion == Expansion.cornucopiaGuildsSecondEdition)
        .toList();
    expect(cornucopia, hasLength(45));
    const printedNames = {
      'advisor': 'Berater',
      'candlestick_maker': 'Leuchtenmacher',
      'carnival': 'Karneval',
      'farmhands': 'Landarbeiterinnen',
      'farrier': 'Hufschmied',
      'ferryman': 'Fährmann',
      'footpad': 'Straßenräuber',
      'infirmary': 'Krankenhaus',
      'joust': 'Ritterkampf',
      'shop': 'Geschäft',
      'coronet': 'Adelskrone',
      'courser': 'Rennpferd',
      'demesne': 'Landsitz',
      'housecarl': 'Leibgardist',
      'huge_turnip': 'Riesenrübe',
      'renown': 'Ruhm',
      'bag_of_gold': 'Ein Sack voll Gold',
      'followers': 'Gefolge',
      'trusty_steed': 'Streitross',
      'taxman': 'Steuereintreiber',
    };
    for (final entry in printedNames.entries) {
      expect(german.lookup(entry.key)!.name, entry.value, reason: entry.key);
    }
    final imported = resolveSetupText(
        catalogue,
        'Hufschmied\nKrankenhaus\nGeschäft\nLandarbeiterinnen\nKarneval\n'
        'Fährmann\nStraßenräuber\nRitterkampf\nLeuchtenmacher\nNachbau',
        packs: [german]);
    expect(
        imported.kingdom.map((card) => card.id),
        unorderedEquals([
          'farrier',
          'infirmary',
          'shop',
          'farmhands',
          'carnival',
          'ferryman',
          'footpad',
          'joust',
          'candlestick_maker',
          'remake',
        ]));
    expect(german.lookup('merchant_guild')!.text,
        contains('Am Ende deiner Kaufphase in diesem Zug'));
    expect(german.lookup('merchant_guild')!.text,
        contains('in dieser Kaufphase genommen'));
    expect(german.lookup('footpad')!.text, contains('gilt für alle Spieler'));
    expect(german.lookup('footpad')!.text, contains('in einer Aktionsphase'));
    expect(german.lookup('farmhands')!.text,
        contains('Wenn du diese Karte nimmst'));
    expect(german.lookup('joust')!.text,
        contains('Lege die Provinz in der Aufräumphase ab'));
    expect(german.lookup('coronet')!.text,
        contains('Geldkarte ohne den Typ Belohnung'));
    expect(german.lookup('farrier')!.text, contains('am Ende dieses Zuges'));
    expect(german.lookup('infirmary')!.text,
        contains('einmal pro zusätzlich gezahltem Geld'));
    expect(german.lookup('stonemason')!.text,
        contains('genau so viel kosten wie der zusätzlich gezahlte Betrag'));
    expect(german.lookup('trusty_steed')!.text,
        contains('lege deinen Nachziehstapel auf deinen Ablagestapel'));
    expect(german.lookup('soothsayer')!.text,
        contains('wenn er einen Fluch genommen hat'));
  });

  test('German covers every promo with current effects and printed names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final promos =
        catalogue.where((card) => card.expansion == Expansion.promos);
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    const names = {
      'envoy': 'Gesandter',
      'black_market': 'Schwarzmarkt',
      'stash': 'Geldversteck',
      'walled_village': 'Befestigtes Dorf',
      'governor': 'Gouverneur',
      'prince': 'Prinz',
      'summon': 'Einladung',
      'sauna': 'Sauna',
      'avanto': 'Eisloch',
      'dismantle': 'Abbruch',
      'church': 'Schweriner Dom',
      'captain': 'Kapitän Tobias',
      'marchland': 'Grenzregion',
    };
    expect(promos.map((card) => card.id), unorderedEquals(names.keys));
    for (final entry in names.entries) {
      expect(german.lookup(entry.key)?.isComplete, isTrue, reason: entry.key);
      expect(german.lookup(entry.key)!.name, entry.value, reason: entry.key);
    }
    final resolved = resolveImportedKingdomCards(catalogue, [
      for (final entry in names.entries)
        if (entry.key != 'summon') entry.value
    ], packs: [
      german
    ]);
    expect(resolved.notFound, isEmpty);
    expect(resolved.cards.map((card) => card.id),
        unorderedEquals(names.keys.where((id) => id != 'summon')));
    expect(resolved.cards.map((card) => card.pileId).toSet(), hasLength(11));
    final setup = resolveSetupText(
        catalogue,
        'Gesandter\nSchwarzmarkt\nBefestigtes Dorf\nGouverneur\nPrinz\n'
        'Sauna / Eisloch\nAbbruch\nSchweriner Dom\nKapitän Tobias\nGrenzregion\n'
        '\nLandscapes:\nEinladung',
        packs: [german]);
    expect(setup.landscapes.single.id, 'summon');
    expect(setup.kingdom.map((card) => card.pileId).toSet(), hasLength(10));
    for (final id in ['prince', 'captain']) {
      expect(german.lookup(id)!.text,
          contains('weder den Typ Dauer noch den Typ Befehl'));
    }
    expect(german.lookup('sauna')!.text, contains('in diesem Zug ein Silber'));
    expect(german.lookup('church')!.text,
        contains('auf die Hand; danach darfst du'));
    expect(
        german.lookup('dismantle')!.text,
        contains(
            'mindestens 1 Geld, nimm eine billigere Karte und danach ein Gold'));
    expect(german.lookup('marchland')!.text, contains('pro 3 Punktekarten'));
    expect(german.lookup('marchland')!.text,
        contains('Wenn du diese Karte nimmst'));
    expect(german.lookup('walled_village')!.text,
        contains('zu Beginn deiner Aufräumphase'));
  });

  test('Intrigue Second Edition draw and trashing reflect the printed effects',
      () {
    final intrigue = cards
        .map(KingdomCard.fromJson)
        .where((card) =>
            card.expansion == Expansion.intrigueSecondEdition &&
            !card.firstEditionOnly)
        .toList();
    expect(intrigue, hasLength(26));
    expect(
        intrigue.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'courtyard',
          'diplomat',
          'masquerade',
          'minion',
          'nobles',
          'patrol',
          'shantyTown',
          'steward',
          'torturer',
          'wishingWell',
        ]));
    expect(
        intrigue.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals([
          'masquerade',
          'replace',
          'steward',
          'tradingPost',
          'upgrade',
        ]));
    expect(
        intrigue
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(['diplomat', 'miningVillage', 'nobles', 'shantyTown']));
    final german = TranslationService.validatePack(
      File('assets/data/translations/de.json').readAsStringSync(),
      cards.map((card) => card['id'] as String).toSet(),
    );
    expect(intrigue.where((card) => german.lookup(card.id) == null), isEmpty);
    expect(german.lookup('minion')?.name, 'Lakai');
    expect(german.lookup('pawn')?.name, 'Handlanger');
  });

  test('old Harem names and KF1 IDs resolve to the one Farm pile', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final resolved = resolveImportedKingdomCards(catalogue, ['Harem']);
    expect(resolved.notFound, isEmpty);
    expect(resolved.cards.single.pileId, 'farm');
    final base = catalogue
        .where((card) => card.expansion == Expansion.baseSecondEdition)
        .take(9);
    final payload =
        SharePayload(kingdomCardIds: ['harem', ...base.map((card) => card.id)]);
    final shared = resolveSharedKingdom(
        payload.encode(),
        catalogue,
        const ConfigState(
            ownedExpansions: {Expansion.baseSecondEdition},
            rules: SetupRules(),
            disabledCardIds: {}));
    expect(shared.kingdomSlotIds, hasLength(10));
    expect(shared.kingdomSlotIds, contains('farm'));
  });

  test('Seaside effects distinguish draw, cycling and deck trashing', () {
    final seaside = cards
        .map(KingdomCard.fromJson)
        .where((card) =>
            card.expansion == Expansion.seasideSecondEdition &&
            !card.firstEditionOnly)
        .toList();
    expect(seaside, hasLength(27));
    expect(
        seaside.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'caravan',
          'monkey',
          'native_village',
          'sea_chart',
          'sea_witch',
          'tactician',
          'tide_pools',
          'wharf',
        ]));
    expect(seaside.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['lookout', 'sailor', 'salvager']));
    expect(seaside.singleWhere((card) => card.id == 'blockade').tags,
        contains(CardTag.curse));
    final german = TranslationService.validatePack(
      File('assets/data/translations/de.json').readAsStringSync(),
      cards.map((card) => card['id'] as String).toSet(),
    );
    expect(seaside.where((card) => german.lookup(card.id) == null), isEmpty);
    expect(german.lookup('wharf')?.name, 'Werft');
  });

  test('Seaside mats appear in setup and Lighthouse supplies Attack protection',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final kingdom = [
      byId['cutpurse']!,
      byId['sea_witch']!,
      byId['pirate']!,
      byId['island']!,
      byId['native_village']!,
    ];
    final lighthouse = byId['lighthouse']!;
    expect(lighthouse.isReaction, isFalse);
    expect(byId['pirate']!.blocksAttacks, isFalse);
    final engine = SetupEngine();
    final notes = engine.generateSetupNotes(kingdom, []).join(' ');
    expect(notes, contains('one Island mat per player'));
    expect(notes, contains('one Native Village mat per player'));
    expect(notes, contains('unaffected by an Attack'));

    final defended = [...kingdom, lighthouse];
    expect(engine.generateSetupNotes(defended, []).join(' '),
        isNot(contains('unaffected by an Attack')));
    final mirror = HeuristicEngine().analyze(defended).singleWhere(
        (archetype) => archetype.kind == ArchetypeKind.mirrorMatch);
    expect(mirror.keyCardNames, contains('Lighthouse'));
  });

  test('Alchemy costs, draw requirements and Potion checklist agree', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final alchemy = byId.values
        .where((card) => card.expansion == Expansion.alchemy)
        .toList();
    expect(alchemy, hasLength(12));
    expect(alchemy.where((card) => card.potionCost), hasLength(10));
    expect(
        alchemy.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals(
            ['alchemist', 'apothecary', 'apprentice', 'scrying_pool']));
    expect(alchemy.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['apprentice', 'transmute']));
    final engine = SetupEngine();
    expect(
        engine.generateSetupNotes(
            [byId['apprentice']!, byId['herbalist']!], []).join(' '),
        isNot(contains('Potion Supply pile')));
    expect(engine.generateSetupNotes([byId['familiar']!], []).join(' '),
        contains('Use all 16 Potions'));
    expect(engine.generateSetupNotes([byId['black_market']!], []).join(' '),
        contains('If that deck contains any Potion-cost cards'));
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        byId.keys.toSet());
    expect(alchemy.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    expect(
        resolveImportedKingdomCards(byId.values.toList(), ['Vision'],
            packs: [german]).cards.single.id,
        'scrying_pool');
  });

  test('Prosperity requirements follow draw and trashing effects', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final prosperity = byId.values
        .where((card) =>
            card.expansion == Expansion.prosperitySecondEdition &&
            !card.firstEditionOnly)
        .toList();
    expect(prosperity, hasLength(25));
    expect(prosperity.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals(['watchtower', 'city', 'magnate', 'rabble', 'vault']));
    expect(
        prosperity
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(['workers_village', 'city']));
    expect(byId['mint']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['forge']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['crystal_ball']!.tags, isNot(contains(CardTag.plusAction)));
    for (final id in ['tiara', 'war_chest']) {
      expect(byId[id]!.tags, isNot(contains(CardTag.plusCoin)), reason: id);
    }
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        byId.keys.toSet());
    expect(
        prosperity.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    expect(
        resolveImportedKingdomCards(byId.values.toList(),
            ['Brautkrone', 'Magnatin', 'Sammelsurium', 'Wunderheilerin'],
            packs: [german]).cards.map((card) => card.id),
        ['tiara', 'magnate', 'collection', 'charlatan']);
  });

  test('Hinterlands effects and German coverage match the second edition', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final hinterlands = byId.values
        .where((card) =>
            card.expansion == Expansion.hinterlandsSecondEdition &&
            !card.firstEditionOnly)
        .toList();
    expect(hinterlands, hasLength(26));
    expect(
        hinterlands.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'crossroads',
          'guard_dog',
          'jack_of_all_trades',
          'margrave',
          'spice_merchant',
          'stables',
          'trail',
          'witchs_hut'
        ]));
    expect(
        hinterlands
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(['border_village', 'crossroads', 'inn']));
    expect(byId['crossroads']!.capabilities.extraActions, 2);
    expect(byId['souk']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['guard_dog']!.blocksAttacks, isFalse);
    expect(byId['nomads']!.tags, contains(CardTag.plusBuy));
    expect(byId['nomads']!.text, startsWith('+1 Buy.'));
    expect(byId['trader']!.text,
        contains('exchange the gained card for a Silver'));
    expect(byId['highway']!.text, contains('This turn, cards cost'));
    expect(byId['scheme']!.text, contains('when you discard it from play'));
    expect(byId['witchs_hut']!.text, contains('Discard 2 cards, revealed'));
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        byId.keys.toSet());
    expect(
        hinterlands.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    expect(
        resolveImportedKingdomCards(byId.values.toList(),
            ['Fahrende Händlerin', 'Hexenkessel', 'Nomaden', 'Radmacherin'],
            packs: [german]).cards.map((card) => card.id),
        ['trader', 'cauldron', 'nomads', 'wheelwright']);
  });

  test('Cornucopia and Guilds requirements reflect the second edition', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final expansion = byId.values
        .where((card) =>
            card.expansion == Expansion.cornucopiaGuildsSecondEdition &&
            card.isKingdomCard &&
            !card.firstEditionOnly)
        .toList();
    expect(expansion, hasLength(26));
    expect(
        expansion.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'advisor',
          'carnival',
          'farrier',
          'footpad',
          'hunting_party',
          'infirmary',
          'journeyman',
          'menagerie'
        ]));
    expect(
        expansion
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(['farmhands', 'hamlet', 'plaza']));
    expect(
        expansion.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['butcher', 'infirmary', 'remake', 'stonemason']));
    expect(byId['remake']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['jester']!.text, startsWith('+\$2.'));
    expect(byId['jester']!.tags, contains(CardTag.plusCoin));
    expect(byId['farmhands']!.isDuration, isFalse);
    expect(byId['farmhands']!.tags, isNot(contains(CardTag.duration)));
    expect(byId['joust']!.pileCardIds, hasLength(6));
    for (final id in byId['joust']!.pileCardIds) {
      expect(byId[id]!.isAuxiliary, isTrue);
      expect(byId[id]!.types, contains(CardType.reward));
    }
  });

  test('Adventures requirements distinguish draw, replay and opponent trashing',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final adventures = byId.values.where(
        (card) => card.expansion == Expansion.adventures && card.isKingdomCard);
    expect(adventures, hasLength(30));
    expect(
        adventures.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'gear',
          'guide',
          'magpie',
          'ranger',
          'haunted_woods',
          'lost_city',
          'storyteller',
          'hireling'
        ]));
    expect(
        adventures
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(['coin_of_the_realm', 'port', 'lost_city']));
    expect(
        adventures.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['ratcatcher', 'raze', 'amulet', 'transmogrify']));
    expect(byId['coin_of_the_realm']!.capabilities.extraActions, 2);
    expect(byId['storyteller']!.tags, isNot(contains(CardTag.plusCoin)));
    expect(byId['champion']!.blocksAttacks, isTrue);
    expect(byId['champion']!.isReaction, isFalse);
    expect(byId['warrior']!.trashesOwnCards, isFalse);
    expect(byId['fugitive']!.providesDraw, isFalse);
    expect(byId['mission']!.text, contains('not a 3rd turn in a row'));
    expect(byId['mission']!.text, isNot(contains('previous turn')));
    final pool = SetupEngine().eligibleKingdomPool(byId.values.toList(),
        {Expansion.adventures}, const SetupRules(noCursers: true));
    expect(pool, hasLength(28));
    expect(pool.map((card) => card.id),
        isNot(anyOf(contains('giant'), contains('swamp_hag'))));
  });

  test('Adventures setup prepares Tavern mats and Traveller upgrades', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    for (final id in ['miser', 'peasant', 'royal_carriage']) {
      expect(engine.generateSetupNotes([byId[id]!], []).join(' '),
          contains('Tavern mats'),
          reason: id);
    }
    for (final id in ['page', 'peasant']) {
      expect(engine.generateSetupNotes([byId[id]!], []).join(' '),
          contains('5 copies of each upgrade outside the Supply'),
          reason: id);
    }
    expect(engine.generateSetupNotes([byId['gear']!], []).join(' '),
        contains('If a Duration card leaves play, its future effects stop.'));
    expect(engine.generateSetupNotes([byId['miser']!], []).join(' '),
        isNot(contains('Duration cards:')));
  });

  test('German covers Adventures and imports Kingdom and Event names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final adventures = catalogue
        .where((card) => card.expansion == Expansion.adventures)
        .toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(adventures, hasLength(58));
    expect(
        adventures.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Zerstörung, Karawanenwächter, Geizhals, Hafenstadt, Wildhüter, Elster, '
        'Brückentroll, Königliche Kutsche, Kunsthandwerker, Verlorene Stadt\n'
        'Landscapes:\nFreudenfeuer, Überfahrt',
        packs: [german]);
    expect(
        setup.kingdom.map((card) => card.id),
        unorderedEquals([
          'raze',
          'caravan_guard',
          'miser',
          'port',
          'ranger',
          'magpie',
          'bridge_troll',
          'royal_carriage',
          'artificer',
          'lost_city'
        ]));
    expect(setup.landscapes.map((card) => card.id), ['bonfire', 'ferry']);
    expect(
        german.lookup('mission')!.text, contains('keinen dritten eigenen Zug'));
    expect(german.lookup('mission')!.text, isNot(contains('Einmal je Zug')));
    expect(german.lookup('storyteller')!.text,
        contains('Ziehe danach 1 Karte und zahle dann'));
    expect(german.lookup('storyteller')!.text, isNot(contains('+1 Geld')));
    expect(german.lookup('port')!.text, contains('Nimmst du diese Hafenstadt'));
    expect(german.lookup('messenger')!.text,
        contains('erste Karte, die du in deiner Kaufphase nimmst'));
    expect(german.lookup('plan')!.text, contains('Nimmst du eine Karte'));
    expect(german.lookup('inheritance')!.text, contains('ohne den Typ Befehl'));
    expect(german.lookup('inheritance')!.text,
        isNot(contains('keine Punktekarte')));
    expect(german.lookup('bonfire')!.text, contains('bis zu 2 deiner Kupfer'));
    expect(adventures.singleWhere((card) => card.id == 'bonfire').text,
        'Trash up to 2 Coppers you have in play.');
  });

  test('Empires requirements distinguish cycling and Supply trashing', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final empires = byId.values
        .where(
            (card) => card.expansion == Expansion.empires && card.isKingdomCard)
        .toList();
    expect(empires.map((card) => card.pileId).toSet(), hasLength(24));
    expect(byId['castles']!.types, contains(CardType.castle));
    expect(
        empires.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'archive',
          'city_quarter',
          'encampment',
          'enchantress',
          'patrician',
          'royal_blacksmith',
          'settlers',
          'bustling_village',
          'wild_hunt'
        ]));
    expect(
        empires
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals([
          'city_quarter',
          'encampment',
          'sacrifice',
          'bustling_village',
          'villa'
        ]));
    expect(empires.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['catapult', 'sacrifice', 'temple']));
    expect(byId['bustling_village']!.capabilities.extraActions, 2);
    expect(byId['temple']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['sacrifice']!.capabilities.draw, DrawCapability.cycling);
    expect(byId['royal_blacksmith']!.capabilities.draw,
        DrawCapability.conditional);
    expect(byId['crown']!.tags, isNot(contains(CardTag.plusAction)));
    expect(byId['chariot_race']!.text, contains('Draw 1 card and reveal it'));
    expect(byId['chariot_race']!.text, contains('If your card costs more'));
    expect(byId['chariot_race']!.text, isNot(contains('costs less')));
    expect(byId['forum']!.text, contains('When you gain this, +1 Buy'));
    expect(byId['overlord']!.text, isNot(contains('non-Duration')));
    expect(byId['overlord']!.text, contains('non-Command'));
    expect(byId['donate']!.text, startsWith('At the start of your next turn'));
    expect(byId['donate']!.text, endsWith('draw 5 cards.'));
    expect(byId['mountain_pass']!.text, isNot(contains('after that turn')));
    expect(byId['capital']!.text, endsWith('take 6 Debt.'));
    final pool = SetupEngine().eligibleKingdomPool(byId.values.toList(),
        {Expansion.empires}, const SetupRules(noCursers: true));
    expect(pool.map((card) => card.id), isNot(contains('catapult')));
    expect(pool.map((card) => card.id), isNot(contains('rocks')));
    expect(pool.map((card) => card.pileId).toSet(), hasLength(23));
  });

  test('Empires scoring extras prepare tokens without promising deck trashing',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    for (final id in [
      'dominate',
      'ritual',
      'salt_the_earth',
      'triumph',
      'wedding'
    ]) {
      expect(engine.generateSetupNotes([], [byId[id]!]).join(' '),
          contains('VP tokens: prepare the Victory Point token supply.'),
          reason: id);
    }
    expect(engine.generateSetupNotes([byId['castles']!], []).join(' '),
        contains('VP tokens: prepare the Victory Point token supply.'));
    expect(byId['salt_the_earth']!.trashesOwnCards, isFalse);
    expect(byId['donate']!.capabilities.trashing, TrashingThroughput.multiple);
    final events = byId.values.where((card) =>
        card.expansion == Expansion.empires &&
        card.types.contains(CardType.event));
    expect(events, hasLength(13));
    expect(
        events
            .where((card) => card.hasTag(CardTag.gainVictory))
            .map((card) => card.id),
        unorderedEquals(['annex', 'dominate', 'triumph']));
    for (final id in ['bandit_fort', 'wall', 'wolf_den']) {
      expect(byId[id]!.metadata.altVpPressure, isNot(AltVpPressure.none),
          reason: id);
    }
    final castles =
        byId['castles']!.pileCardIds.map((id) => byId[id]!).toList();
    expect(castles, hasLength(8));
    expect(
        castles.every(
            (card) => card.isAuxiliary && card.types.contains(CardType.castle)),
        isTrue);
    expect(castles.map((card) => card.cost), [3, 4, 5, 6, 7, 8, 9, 10]);
    final pool = engine.eligibleKingdomPool(
        byId.values.toList(), {Expansion.empires}, const SetupRules());
    expect(pool.map((card) => card.pileId).toSet(), hasLength(24));
    expect(pool.any((card) => castles.contains(card)), isFalse);
  });

  test(
      'German covers Empires and resolves translated split piles and landscapes',
      () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final empires =
        catalogue.where((card) => card.expansion == Expansion.empires).toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(empires, hasLength(71));
    expect(empires.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Katapult / Felsen, Feldlager / Diebesgut, Gladiator / Reichtum, '
        'Patrizier / Handelsplatz, Siedler / Emsiges Dorf, Archiv, Gärtnerin, '
        'Schlösser, Stadtviertel, Lehnsherr\n'
        'Landscapes:\nAquädukt, Kolonnaden, Entweihter Schrein, Spende',
        packs: [german]);
    expect(setup.kingdom, hasLength(15));
    expect(setup.kingdom.map((card) => card.pileId).toSet(), hasLength(10));
    expect(
        setup.kingdom.where((card) => card.isSplitPile).map((card) => card.id),
        unorderedEquals([
          'catapult',
          'rocks',
          'encampment',
          'plunder',
          'gladiator',
          'fortune',
          'patrician',
          'emporium',
          'settlers',
          'bustling_village'
        ]));
    expect(setup.landscapes.map((card) => card.id),
        ['aqueduct', 'colonnade', 'defiled_shrine', 'donate']);
    expect(german.lookup('donate')!.text,
        startsWith('Zu Beginn deines nächsten Zuges'));
    expect(german.lookup('donate')!.text, endsWith('ziehe 5 Karten.'));
    expect(german.lookup('mountain_pass')!.text,
        startsWith('Sobald du als erster Spieler eine Provinz nimmst'));
    expect(german.lookup('mountain_pass')!.text, isNot(contains('am Ende')));
    expect(german.lookup('chariot_race')!.text,
        contains('Ziehe 1 Karte und decke sie auf'));
    expect(german.lookup('chariot_race')!.text,
        contains('Kostet deine Karte mehr'));
    expect(
        german.lookup('forum')!.text, contains('Wenn du dieses Forum nimmst'));
    expect(german.lookup('groundskeeper')!.text, contains('in diesem Zug'));
    expect(german.lookup('overlord')!.text, contains('ohne den Typ Befehl'));
    expect(german.lookup('overlord')!.text, isNot(contains('Dauer')));
    expect(german.lookup('tax')!.text,
        contains('Nimmt ein Spieler in seiner Kaufphase'));
    expect(german.lookup('salt_the_earth')!.text, contains('aus dem Vorrat'));
    expect(german.lookup('grand_castle')!.name, 'Prunkschloss');
    expect(german.lookup('kings_castle')!.text,
        contains('einschließlich dieses Schlosses'));
  });

  test(
      'Nocturne direct requirements distinguish cycling and self-only trashing',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final nocturne = byId.values
        .where((card) =>
            card.expansion == Expansion.nocturne && card.isKingdomCard)
        .toList();
    expect(nocturne, hasLength(33));
    expect(
        nocturne.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'crypt',
          'cursed_village',
          'den_of_sin',
          'faithful_hound',
          'pooka',
          'shepherd',
          'tragic_hero',
          'werewolf'
        ]));
    expect(
        nocturne
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(
            ['blessed_village', 'conclave', 'cursed_village', 'ghost_town']));
    expect(
        nocturne.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['cemetery', 'exorcist', 'monastery', 'pooka']));
    expect(nocturne.where((card) => card.isReaction).map((card) => card.id),
        ['faithful_hound']);
    expect(byId['werewolf']!.types, contains(CardType.night));
    expect(byId['guardian']!.blocksAttacks, isTrue);
    expect(byId['guardian']!.isReaction, isFalse);
    expect(byId['fool']!.tags, isNot(contains(CardTag.plusBuy)));
    expect(byId['cursed_village']!.tags, contains(CardTag.drawToX));
    expect(
        byId['cemetery']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(
        byId['monastery']!.capabilities.trashing, TrashingThroughput.multiple);
  });

  test('Nocturne rules use the actual Fool, gain Boons and complete Hex deck',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    expect(byId['fool']!.text, contains('take 3 Boons'));
    expect(byId['fool']!.text, isNot(contains('discard an Estate')));
    expect(byId['fool']!.pileCardIds, containsAll(byId['bard']!.pileCardIds));
    expect(byId['blessed_village']!.text, contains('When you gain this'));
    expect(byId['blessed_village']!.text, isNot(contains('does not give')));
    expect(
        byId['necromancer']!.text, contains('Choose a face-up non-Duration'));
    expect(byId['necromancer']!.tags, isNot(contains(CardTag.plusAction)));
    expect(byId['tracker']!.text, contains('For the rest of this turn'));
    expect(byId['crypt']!.text, contains('non-Duration Treasures'));
    final hexes =
        byId.values.where((card) => card.types.contains(CardType.hex));
    expect(
        hexes.map((card) => card.id),
        unorderedEquals([
          'bad_omens',
          'delusion',
          'envy',
          'famine',
          'fear',
          'greed',
          'haunting',
          'locusts',
          'misery',
          'plague',
          'poverty',
          'war'
        ]));
    expect(byId, isNot(contains('theft')));
    for (final card
        in byId.values.where((card) => card.types.contains(CardType.doom))) {
      expect(
          card.pileCardIds.toSet(), containsAll(hexes.map((card) => card.id)),
          reason: card.id);
    }
    expect(byId['fear']!.text, contains('at least 5 cards'));
    expect(byId['fear']!.text, contains('discard an Action or Treasure'));
    expect(byId['fear']!.text, isNot(contains('to its pile')));
    expect(byId['famine']!.text, contains('shuffle the remaining'));
    expect(byId['delusion']!.text, contains('neither Deluded nor Envious'));
    expect(byId['envy']!.text, contains('neither Deluded nor Envious'));
    expect(byId['misery']!.text,
        contains('already have Twice Miserable, nothing happens'));
    expect(byId['bat']!.text, contains('If you trashed at least one card'));
  });

  test('exchange filters retain their scope without Traveller setup quantities',
      () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final byId = {for (final card in catalogue) card.id: card};
    final engine = SetupEngine();
    for (final id in ['hermit', 'urchin', 'vampire', 'bat']) {
      expect(byId[id]!.isTraveller, isFalse, reason: id);
      expect(byId[id]!.travellerChain, isNotEmpty, reason: id);
      expect(engine.generateSetupNotes([byId[id]!], []).join(' '),
          isNot(contains('5 copies of each upgrade')),
          reason: id);
    }
    final vampireNotes =
        engine.generateSetupNotes([byId['vampire']!], []).join(' ');
    expect(vampireNotes, contains('all 10 Bats'));
    expect(engine.generateSetupNotes([byId['page']!], []).join(' '),
        contains('5 copies of each upgrade'));
    expect(byId['page']!.isTraveller, isTrue);
    expect(byId['treasure_hunter']!.isTraveller, isTrue);
    final pool = engine.eligibleKingdomPool(
        catalogue,
        {Expansion.nocturne, Expansion.darkAges, Expansion.adventures},
        const SetupRules(noTravellers: true));
    expect(
        pool.map((card) => card.id),
        isNot(anyOf(contains('vampire'), contains('hermit'), contains('urchin'),
            contains('page'), contains('peasant'))));
    expect(const SetupRules(noTravellers: true).activeRuleDescriptions,
        contains('No exchange chains'));
  });

  test('Nocturne auxiliary effects retain printed types, timing and conditions',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final auxiliary = byId.values
        .where(
            (card) => card.expansion == Expansion.nocturne && card.isAuxiliary)
        .toList();
    expect(auxiliary, hasLength(44));
    expect(auxiliary.where((card) => card.types.contains(CardType.heirloom)),
        hasLength(7));
    expect(auxiliary.where((card) => card.types.contains(CardType.boon)),
        hasLength(12));
    expect(auxiliary.where((card) => card.types.contains(CardType.hex)),
        hasLength(12));
    expect(auxiliary.where((card) => card.types.contains(CardType.zombie)),
        hasLength(3));
    expect(byId['pasture']!.types,
        containsAll([CardType.treasure, CardType.victory, CardType.heirloom]));
    expect(byId['pasture']!.text, startsWith('+\$1.'));
    expect(byId['pasture']!.tags, contains(CardTag.plusCoin));
    expect(
        byId['magic_lamp']!.text,
        contains(
            'at least 6 differently named cards each have exactly one copy'));
    expect(byId['magic_lamp']!.text, contains('If you did, gain 3 Wishes'));
    expect(byId['magic_lamp']!.pileCardIds, contains('wish'));
    expect(byId['haunted_mirror']!.pileCardIds, contains('ghost'));
    expect(byId['wish']!.text, startsWith('+1 Action.'));
    expect(byId['wish']!.tags, contains(CardTag.plusAction));
    expect(byId['the_fields_gift']!.text, startsWith('+1 Action. +\$1.'));
    expect(byId['the_fields_gift']!.tags, isNot(contains(CardTag.plusBuy)));
    expect(byId['the_fields_gift']!.capabilities.extraActions, 1);
    for (final id in [
      'the_fields_gift',
      'the_forests_gift',
      'the_rivers_gift'
    ]) {
      expect(byId[id]!.text, contains('Keep this Boon until Clean-up'),
          reason: id);
    }
    expect(byId['the_rivers_gift']!.text,
        contains('after drawing your next hand'));
    expect(byId['the_moons_gift']!.text, contains('You may put one card'));
    expect(byId['the_swamps_gift']!.pileCardIds, contains('will_o_wisp'));
    expect(byId['the_winds_gift']!.providesDraw, isFalse);
    expect(byId['will_o_wisp']!.capabilities.draw, DrawCapability.conditional);
    expect(byId['imp']!.capabilities.draw, DrawCapability.net);
    expect(byId['zombie_spy']!.providesDraw, isFalse);
    for (final id in ['deluded', 'envious']) {
      expect(byId[id]!.text,
          startsWith('At the start of your Buy phase, return this State.'),
          reason: id);
      expect(byId[id]!.text, isNot(contains('next time you gain')), reason: id);
    }
    expect(byId['miserable']!.text, 'When scoring, -2VP.');
  });

  test('Nocturne setup names exact non-Supply quantities', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    String notes(String id) =>
        engine.generateSetupNotes([byId[id]!], []).join(' ');
    expect(notes('bard'), contains('shuffle the 12 Boons'));
    expect(notes('bard'), contains("all 12 Will-o'-Wisps outside the Supply"));
    expect(notes('skulk'), contains('shuffle the 12 Hexes'));
    expect(
        notes('skulk'),
        contains(
            '6 double-sided Deluded/Envious and 6 Miserable/Twice Miserable'));
    expect(notes('exorcist'),
        contains("all 12 Will-o'-Wisps, 13 Imps, and 6 Ghosts"));
    for (final id in ['secret_cave', 'leprechaun']) {
      expect(notes(id), contains('all 12 Wishes'), reason: id);
    }
    for (final id in ['devils_workshop', 'tormentor']) {
      expect(notes(id), contains('all 13 Imps'), reason: id);
    }
    expect(notes('cemetery'), contains('all 6 Ghosts'));
    expect(notes('necromancer'), contains('the 3 Zombies in the trash'));
  });

  test('German covers all Nocturne cards and retains corrected effects', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final nocturne = catalogue
        .where((card) => card.expansion == Expansion.nocturne)
        .toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(nocturne, hasLength(77));
    expect(nocturne.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Druidin, Fee, Puka, Narr, Fährtensucher, Schäferin, Friedhof, '
        'Vampirin, Werwolf, Totenbeschwörer',
        packs: [german]);
    expect(setup.kingdom.map((card) => card.id), [
      'druid',
      'pixie',
      'pooka',
      'fool',
      'tracker',
      'shepherd',
      'cemetery',
      'vampire',
      'werewolf',
      'necromancer'
    ]);
    expect(german.lookup('bard')!.name, 'Minnesängerin');
    expect(german.lookup('fool')!.text, contains('erhalte danach 3 Gaben'));
    expect(german.lookup('blessed_village')!.text,
        contains('Wenn du dieses Dorf nimmst'));
    expect(german.lookup('crypt')!.text,
        contains('Geldkarten ohne den Typ Dauer'));
    expect(
        german.lookup('tracker')!.text, contains('Für den Rest dieses Zuges'));
    expect(german.lookup('magic_lamp')!.text,
        contains('mindestens 6 Kartennamen mit jeweils genau einem Exemplar'));
    expect(german.lookup('pasture')!.text, startsWith('+1 Geld.'));
    expect(german.lookup('wish')!.text, startsWith('+1 Aktion.'));
    expect(german.lookup('bat')!.text,
        contains('Hast du mindestens eine Karte entsorgt'));
    expect(german.lookup('the_fields_gift')!.text, isNot(contains('+1 Kauf')));
    expect(german.lookup('the_rivers_gift')!.text,
        contains('nachdem du deine nächste Hand gezogen hast'));
    expect(german.lookup('famine')!.text, contains('mische die übrigen'));
    expect(german.lookup('fear')!.text, contains('mindestens 5 Handkarten'));
    expect(german.lookup('fear')!.text,
        contains('lege davon eine Aktions- oder Geldkarte ab'));
    expect(german.lookup('haunting')!.name, 'Spuk');
    expect(german.lookup('misery')!.text, contains('andernfalls nimm Elendig'));
    for (final id in ['deluded', 'envious']) {
      expect(german.lookup(id)!.text,
          startsWith('Gib diesen Zustand zu Beginn deiner Kaufphase zurück.'),
          reason: id);
    }
    expect(nocturne.singleWhere((card) => card.id == 'werewolf').text,
        contains('receives the next Hex'));
  });

  test('Dark Ages requirements distinguish own-deck trashing and cycling', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final darkAges = byId.values
        .where((card) =>
            card.expansion == Expansion.darkAges && card.isKingdomCard)
        .toList();
    expect(darkAges, hasLength(35));
    expect(
        darkAges.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'catacombs',
          'cultist',
          'hunting_grounds',
          'ironmonger',
          'vagrant'
        ]));
    expect(
        darkAges
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals([
          'bandit_camp',
          'fortress',
          'ironmonger',
          'squire',
          'wandering_minstrel'
        ]));
    expect(
        darkAges.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals([
          'altar',
          'count',
          'counterfeit',
          'death_cart',
          'forager',
          'graverobber',
          'hermit',
          'junk_dealer',
          'procession',
          'rats',
          'rebuild'
        ]));
    expect(byId['count']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['dame_anna']!.text, startsWith('You may trash up to 2 cards'));
    expect(byId['dame_anna']!.providesDraw, isFalse);
    expect(
        byId['dame_anna']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['storeroom']!.text, contains('draw that many. Then discard'));
    expect(byId['pillage']!.text, startsWith('Trash this. If you do,'));
    expect(byId['hermit']!.text, contains('At the end of your Buy phase'));
    expect(byId['counterfeit']!.text, contains('non-Duration Treasure'));
    expect(byId['procession']!.text, contains('non-Duration Action'));
    expect(byId['spoils']!.isAuxiliary, isTrue);
    for (final id in ['bandit_camp', 'marauder', 'pillage']) {
      expect(byId[id]!.pileCardIds, contains('spoils'), reason: id);
    }
  });

  test('Shelters are auxiliary starting cards with translated rules', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final shelters = catalogue
        .where((card) => card.types.contains(CardType.shelter))
        .toList();
    expect(shelters.map((card) => card.id),
        unorderedEquals(['hovel', 'necropolis', 'overgrown_estate']));
    expect(
        shelters.every((card) => card.isAuxiliary && card.cost == 1), isTrue);
    expect(
        shelters.singleWhere((card) => card.id == 'hovel').isVictory, isFalse);
    expect(shelters.singleWhere((card) => card.id == 'hovel').text,
        contains('When you gain a Victory card'));
    expect(
        shelters.singleWhere((card) => card.id == 'overgrown_estate').isVictory,
        isTrue);
    final pool = SetupEngine().eligibleKingdomPool(
        catalogue, {Expansion.darkAges}, const SetupRules());
    expect(pool, hasLength(35));
    expect(pool.any((card) => card.types.contains(CardType.shelter)), isFalse);
    final notes =
        SetupEngine().generateSetupNotes(pool.take(10).toList(), []).join(' ');
    expect(
        notes, contains('one Hovel, one Necropolis and one Overgrown Estate'));
    expect(
        notes,
        contains(
            'Estate Supply still has 8 cards for 2 players or 12 for 3-6 players'));
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    for (final id in [
      'hovel',
      'necropolis',
      'overgrown_estate',
      'ruins',
      'abandoned_mine',
      'ruined_library',
      'ruined_market',
      'ruined_village',
      'survivors'
    ]) {
      expect(german.lookup(id)?.isComplete, isTrue, reason: id);
    }
    expect(german.lookup('hovel')!.name, 'Hütte');
    expect(german.lookup('necropolis')!.name, 'Totenstadt');
  });

  test('German covers all Dark Ages records and imports printed names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final darkAges = catalogue
        .where((card) => card.expansion == Expansion.darkAges)
        .toList();
    expect(darkAges, hasLength(57));
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(darkAges.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    expect(
        resolveImportedKingdomCards(catalogue, [
          'Vogelfreie',
          'Eisenhändler',
          'Schrotthändler',
          'Neubau',
          'Gassenjunge',
          'Barde'
        ], packs: [
          german
        ]).cards.map((card) => card.id),
        [
          'band_of_misfits',
          'ironmonger',
          'junk_dealer',
          'rebuild',
          'urchin',
          'wandering_minstrel'
        ]);
    expect(german.lookup('dame_anna')!.text,
        startsWith('Du darfst bis zu 2 Handkarten entsorgen.'));
    expect(german.lookup('hermit')!.text, contains('Am Ende deiner Kaufphase'));
    expect(german.lookup('storeroom')!.text,
        contains('ziehe genauso viele Karten. Lege danach'));
  });

  test('exchange IDs survive snapshots and resolve renamed upgrade cards', () {
    final pageJson = cards.singleWhere((card) => card['id'] == 'page');
    final page = KingdomCard.fromJson(pageJson);
    expect(page.travellerChainIds,
        ['treasure_hunter', 'warrior', 'hero', 'champion']);
    expect(KingdomCard.fromJson(page.toJson()).travellerChainIds,
        page.travellerChainIds);
    expect(page.copyWith(isDisabled: true).travellerChainIds,
        page.travellerChainIds);
    final legacy =
        KingdomCard.fromJson({...pageJson}..remove('travellerChainIds'));
    expect(legacy.hasExchangeChain, isTrue);
    expect(legacy.travellerChainIds, isEmpty);
    expect(SetupEngine().generateSetupNotes([legacy], []).join(' '),
        contains('Treasure Hunter → Warrior → Hero → Champion'));
    final renamed = KingdomCard.fromJson({
      ...cards.singleWhere((card) => card['id'] == 'treasure_hunter'),
      'name': 'Renamed upgrade',
    });
    expect(
        SetupEngine()
            .generateSetupNotes([page], [], allCards: [renamed]).join(' '),
        contains('Renamed upgrade → Warrior → Hero → Champion'));
    final idsOnly =
        KingdomCard.fromJson({...pageJson}..remove('travellerChain'));
    expect(idsOnly.hasExchangeChain, isTrue);
    expect(
        SetupEngine().eligibleKingdomPool([idsOnly], {Expansion.adventures},
            const SetupRules(noTravellers: true)),
        isEmpty);
  });

  test('catalogue IDs, enums and linked cards are valid', () {
    final ids = cards.map((card) => card['id']).toSet();
    final names = cards.map((card) => card['name']).toSet();
    expect(ids.length, cards.length);
    for (final card in cards) {
      final parsed = KingdomCard.fromJson(card);
      expect(card['role'], parsed.role.name, reason: parsed.id);
      expect(card.containsKey('isDisabled'), isFalse, reason: parsed.id);
      if (parsed.isLandscape) {
        expect(parsed.types.any(CardRole.landscapeTypes.contains), isTrue,
            reason: parsed.id);
      }
      expect(ids.containsAll(parsed.pileCardIds), isTrue, reason: parsed.id);
      expect(ids.containsAll(parsed.travellerChainIds), isTrue,
          reason: parsed.id);
      if (parsed.hasExchangeChain) {
        expect(parsed.travellerChainIds, isNotEmpty, reason: parsed.id);
        expect(parsed.travellerChainIds.toSet().length,
            parsed.travellerChainIds.length,
            reason: parsed.id);
        expect(
            parsed.travellerChainIds.map((id) =>
                cards.singleWhere((target) => target['id'] == id)['name']),
            parsed.travellerChain,
            reason: parsed.id);
      }
      expect(Expansion.values.map((value) => value.name),
          contains(card['expansion']),
          reason: card['id']);
      for (final type in card['types']) {
        expect(CardType.values.map((value) => value.name), contains(type),
            reason: card['id']);
      }
      for (final tag in card['tags']) {
        expect(CardTag.values.map((value) => value.name), contains(tag),
            reason: card['id']);
      }
      for (final name in [
        ...(card['pileCards'] ?? []),
        ...(card['travellerChain'] ?? [])
      ]) {
        expect(names, contains(name), reason: card['id']);
      }
    }
  });

  test(
      'bundled translation packs reference valid cards and contain names and text',
      () {
    final ids = cards.map((card) => card['id'] as String).toSet();
    final files = Directory('assets/data/translations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'));
    expect(files, isNotEmpty);
    final codes = <String>{};
    for (final file in files) {
      final pack =
          TranslationService.validatePack(file.readAsStringSync(), ids);
      expect(codes.add(pack.languageCode), isTrue, reason: file.path);
      for (final entry in pack.cards.entries) {
        expect(entry.value.name.trim(), isNotEmpty, reason: entry.key);
        expect(entry.value.text.trim(), isNotEmpty, reason: entry.key);
      }
    }
  });

  test(
      'the frozen KF2 mapping covers the catalogue except newly added 1E piles',
      () {
    final parsed = cards.map(KingdomCard.fromJson).toList();
    final slots = parsed
        .where((card) => card.isKingdomCard)
        .map((card) => card.pileId)
        .toSet();
    final landscapes =
        parsed.where((card) => card.isLandscape).map((card) => card.id).toSet();
    final firstEditionSlots = parsed
        .where((card) => card.isKingdomCard && card.firstEditionOnly)
        .map((card) => card.pileId)
        .toSet();
    expect(slots.difference(ShareCodebook.kingdomSlotCodebook.toSet()),
        firstEditionSlots);
    expect(landscapes.difference(ShareCodebook.landscapeCodebook.toSet()),
        isEmpty);
  });

  test('promo requirements distinguish cycling and repeatable trashing', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final kingdom = byId.values
        .where(
            (card) => card.expansion == Expansion.promos && card.isKingdomCard)
        .toList();
    expect(kingdom, hasLength(12));
    expect(kingdom.map((card) => card.pileId).toSet(), hasLength(11));
    expect(kingdom.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals(['envoy', 'governor', 'avanto', 'church']));
    expect(
        kingdom
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        ['walled_village']);
    expect(kingdom.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['governor', 'sauna', 'dismantle', 'church']));
    expect(byId['sauna']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['sauna']!.text, contains('This turn, when you play a Silver'));
    expect(byId['dismantle']!.tags, contains(CardTag.gainCard));
    final pool = SetupEngine().eligibleKingdomPool(
        byId.values.toList(), {Expansion.promos}, const SetupRules());
    expect(pool.where((card) => card.pileId == 'promos_sauna_avanto'),
        hasLength(2));
    expect(byId['summon']!.isEvent, isTrue);
    expect(pool.map((card) => card.id), isNot(contains('summon')));
    for (final id in ['captain', 'prince']) {
      expect(
          byId[id]!.types, containsAll([CardType.duration, CardType.command]));
      expect(byId[id]!.text, contains('non-Duration'));
      expect(byId[id]!.text, contains('non-Command'));
    }
  });

  test('promo setup includes Black Market side-card requirements', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    final blackMarket =
        engine.generateSetupNotes([byId['black_market']!], []).join(' ');
    expect(blackMarket, contains('at least 15 cards are recommended'));
    expect(blackMarket, contains('one copy of each selected card'));
    expect(blackMarket, contains('their "in games using this" effects'));
    expect(blackMarket, contains('even if they are never revealed'));
    expect(blackMarket, contains('all 16 Potions'));
    final sauna = engine
        .generateSetupNotes([byId['sauna']!, byId['avanto']!], []).join(' ');
    expect(sauna, contains('5 copies of each card'));
    expect(sauna, contains('lower-cost (Sauna) on top'));
    expect(byId['marchland']!.types, [CardType.victory]);
    expect(byId['marchland']!.text, contains('per 3 Victory cards'));
    expect(byId['marchland']!.text, contains('When you gain this, +1 Buy'));
  });

  test('German covers Rising Sun and imports printed names over old aliases',
      () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final risingSun = catalogue
        .where((card) => card.expansion == Expansion.risingSun)
        .toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(risingSun, hasLength(50));
    expect(
        risingSun.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Gasse, Aristokratin, Künstlerin, Handwerker, Daimyo, Fischhändlerin, '
        'Goldmine, Sänfte, Bergschrein, Dichterin\n'
        'Landscapes:\nKampfübung, Gütiger Kaiser',
        packs: [german]);
    expect(setup.kingdom.map((card) => card.id), [
      'alley',
      'aristocrat',
      'artist',
      'craftsman',
      'daimyo',
      'fishmonger',
      'gold_mine',
      'litter',
      'mountain_shrine',
      'poet'
    ]);
    expect(
        setup.landscapes.map((card) => card.id), ['practice', 'kind_emperor']);
    expect(german.lookup('daimyo')!.text, contains('ohne den Typ Befehl'));
    expect(
        german.lookup('rice_broker')!.text, contains('erhältst du beide Boni'));
    expect(german.lookup('river_shrine')!.text,
        contains('in keiner deiner Kaufphasen dieses Zuges'));
    expect(german.lookup('riverboat')!.text,
        contains('ohne den Typ Dauer für genau 5 Geld'));
    expect(german.lookup('foresight')!.text,
        contains('nachdem du deine nächste Hand gezogen hast'));
    expect(german.lookup('credit')!.text,
        contains('Schulden in Höhe ihrer Geldkosten'));
    expect(german.lookup('bureaucracy')!.text,
        contains('auch bei Kosten mit Schulden oder Trank'));
    expect(german.lookup('flourishing_trade')!.text,
        contains('nicht verbrauchte Aktionen als Käufe'));
    expect(german.lookup('kind_emperor')!.text,
        contains('wenn du den letzten Sonnenmarker entfernst'));
    expect(german.lookup('harsh_winter')!.text,
        contains('übernimm alle Schuldenmarker'));
    expect(
        german.lookup('biding_time')!.text, contains('gesamte Hand verdeckt'));
    for (final shadow in risingSun.where((card) => card.isShadow)) {
      expect(german.lookup(shadow.id)!.text,
          contains('aus deinem Nachziehstapel ausspielen'),
          reason: shadow.id);
    }
  });

  test('Rising Sun requirements account for cycling, Shadow draw and trashing',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final kingdom = byId.values
        .where((card) =>
            card.expansion == Expansion.risingSun && card.isKingdomCard)
        .toList();
    expect(kingdom, hasLength(25));
    expect(
        kingdom.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'aristocrat',
          'artist',
          'imperial_envoy',
          'litter',
          'mountain_shrine',
          'ninja',
          'poet',
          'rice_broker',
          'ronin',
          'root_cellar'
        ]));
    expect(
        kingdom
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(['aristocrat', 'kitsune', 'litter', 'rustic_village']));
    expect(
        kingdom.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals([
          'change',
          'mountain_shrine',
          'rice_broker',
          'river_shrine',
          'tanuki'
        ]));
    expect(byId['aristocrat']!.capabilities.extraActions, 2);
    expect(byId['ninja']!.capabilities.draw, DrawCapability.conditional);
    expect(byId['alley']!.capabilities.draw, DrawCapability.cycling);
    for (final id in ['river_shrine', 'asceticism', 'sea_trade']) {
      expect(byId[id]!.capabilities.trashing, TrashingThroughput.multiple,
          reason: id);
    }
    expect(byId['enlightenment']!.providesDraw, isFalse);
    expect(
        byId['rapid_expansion']!.tags, isNot(contains(CardTag.gainTreasure)));
    expect(byId['growth']!.tags, isNot(contains(CardTag.gainTreasure)));
    expect(byId['river_shrine']!.tags, isNot(contains(CardTag.nextTurn)));
    final pool = SetupEngine().eligibleKingdomPool(byId.values.toList(),
        {Expansion.risingSun}, const SetupRules(noCursers: true));
    expect(pool.map((card) => card.id), isNot(contains('kitsune')));
    expect(pool.map((card) => card.id), isNot(contains('snake_witch')));
    expect(pool.map((card) => card.id), contains('ninja'));
  });

  test('Rising Sun retains Debt prices, distinct roles and phase conditions',
      () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final byId = {for (final card in catalogue) card.id: card};
    for (final entry in {
      'artist': 8,
      'daimyo': 6,
      'mountain_shrine': 5,
      'continue_event': 8
    }.entries) {
      expect(byId[entry.key]!.cost, 0, reason: entry.key);
      expect(byId[entry.key]!.debtCost, entry.value, reason: entry.key);
    }
    final risingSun =
        catalogue.where((card) => card.expansion == Expansion.risingSun);
    expect(risingSun.where((card) => card.isProphecy), hasLength(15));
    expect(risingSun.where((card) => card.isEvent), hasLength(10));
    expect(risingSun.where((card) => card.isShadow), hasLength(5));
    expect(risingSun.where((card) => card.isOmen), hasLength(6));
    expect(byId['rice_broker']!.text,
        contains("If it's a Treasure, +2 Cards. If it's an Action, +5 Cards."));
    expect(byId['river_shrine']!.text, contains('in your Buy phase this turn'));
    expect(byId['daimyo']!.types, contains(CardType.command));
    expect(byId['daimyo']!.text, contains('non-Command'));
    expect(byId['foresight']!.text, contains('after drawing your next hand'));
    final pool = SetupEngine().eligibleKingdomPool(
        catalogue, {Expansion.risingSun}, const SetupRules(noDebt: true));
    // This rule explicitly excludes Debt prices, not optional Debt effects.
    expect(pool.map((card) => card.id), isNot(contains('artist')));
    expect(pool.map((card) => card.id), isNot(contains('daimyo')));
    expect(pool.map((card) => card.id), isNot(contains('mountain_shrine')));
    expect(pool.map((card) => card.id), contains('gold_mine'));
  });

  test('Rising Sun setup resolves Sun before the rest of the Omen', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    final notes = engine.generateSetupNotes(
        [byId['mountain_shrine']!, byId['ninja']!],
        [byId['kind_emperor']!]).join(' ');
    expect(
        notes, contains('5 for 2p, 8 for 3p, 10 for 4p, 12 for 5p, 13 for 6p'));
    expect(
        notes, contains("Resolve +1 Sun before the Omen's other instructions"));
    expect(notes, contains('Prophecy becomes active immediately'));
    expect(notes, contains('Further +1 Sun does nothing'));
    expect(notes, contains('Pay \$1 per Debt token at any time on your turn'));
    expect(
        notes, contains('including when another card tells you to play one'));
    expect(engine.generateSetupNotes([], [byId['harsh_winter']!]).join(' '),
        contains('prepare the Debt token supply'));
  });

  test('German covers Plunder and imports Kingdom, Event and Trait names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final plunder =
        catalogue.where((card) => card.expansion == Expansion.plunder).toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(plunder, hasLength(85));
    expect(plunder.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Überfluss, Vergrabener Schatz, Schiffsjunge, Käfig, Mannschaft, '
        'Meuchlerin, Erste Maatin, Kartenzeichnerin, Sack voll Kostbarkeiten, '
        'Wohlhabendes Dorf\nLandscapes:\nReise, Fromm',
        packs: [german]);
    expect(setup.kingdom.map((card) => card.id), [
      'abundance',
      'buried_treasure',
      'cabin_boy',
      'cage',
      'crew',
      'cutthroat',
      'first_mate',
      'mapmaker',
      'sack_of_loot',
      'wealthy_village'
    ]);
    expect(
        setup.landscapes.map((card) => card.id), ['journey_plunder', 'pious']);
    expect(german.lookup('journey_plunder')!.text,
        contains('keinen dritten eigenen Zug in Folge'));
    expect(german.lookup('journey_plunder')!.text,
        isNot(contains('Einmal pro Zug')));
    expect(german.lookup('flagship')!.text, contains('ohne den Typ Befehl'));
    expect(german.lookup('grotto')!.text, contains('lege jene Karten ab'));
    expect(german.lookup('taskmaster')!.text, contains('später in diesem Zug'));
    expect(german.lookup('siren')!.text,
        contains('es sei denn, du entsorgst eine Aktionskarte'));
    expect(german.lookup('shaman')!.text,
        contains('muss jeder Spieler zu Beginn seines Zuges'));
    for (final id in ['trickster', 'puzzle_box', 'tireless']) {
      expect(german.lookup(id)!.text,
          contains('nachdem du deine nächste Hand gezogen hast'),
          reason: id);
    }
    expect(
        german.lookup('jewels')!.text, contains('unter deinen Nachziehstapel'));
    expect(german.lookup('shield')!.text, contains('nicht betroffen'));
    expect(german.lookup('prosper_event')!.text,
        contains('Nimm zuerst eine Kostbarkeit'));
    expect(german.lookup('inherited')!.text,
        contains('Jeder Spieler ersetzt eine Startkarte seiner Wahl'));
    expect(german.lookup('spell_scroll')!.name, 'Zauberrolle');
    expect(plunder.singleWhere((card) => card.id == 'maelstrom').cost, 4);
  });

  test('Plunder requirements distinguish draw, retention and self-trash', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final kingdom = byId.values
        .where(
            (card) => card.expansion == Expansion.plunder && card.isKingdomCard)
        .toList();
    expect(kingdom, hasLength(40));
    expect(
        kingdom.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'cage',
          'crew',
          'figurine',
          'first_mate',
          'grotto',
          'landing_party',
          'longship',
          'mapmaker',
          'maroon',
          'pilgrim',
          'quartermaster',
          'siren',
          'stowaway',
          'swamp_shacks'
        ]));
    expect(
        kingdom
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals([
          'harbor_village',
          'landing_party',
          'longship',
          'swamp_shacks',
          'taskmaster',
          'wealthy_village'
        ]));
    expect(
        kingdom.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals([
          'crucible',
          'enlarge',
          'maroon',
          'pickaxe',
          'rope',
          'secluded_shrine',
          'shaman',
          'siren'
        ]));
    expect(byId['secluded_shrine']!.capabilities.trashing,
        TrashingThroughput.multiple);
    expect(
        byId['maelstrom']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['spell_scroll']!.trashesOwnCards, isFalse);
    expect(byId['rope']!.capabilities.draw, DrawCapability.cycling);
    expect(byId['figurehead']!.capabilities.draw, DrawCapability.net);
    expect(byId['shield']!.blocksAttacks, isTrue);
    for (final id in ['abundance', 'mining_road']) {
      expect(byId[id]!.tags, isNot(contains(CardTag.gainTreasure)), reason: id);
    }
    expect(byId['taskmaster']!.tags, isNot(contains(CardTag.gainCard)));
    expect(byId['fawning']!.tags, isNot(contains(CardTag.gainVictory)));
  });

  test('Plunder costs feed the same price restrictions as generation', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final byId = {for (final card in catalogue) card.id: card};
    expect(byId['mapmaker']!.cost, 4);
    expect(byId['sack_of_loot']!.cost, 6);
    expect(byId['maelstrom']!.cost, 4);
    expect(byId['prosper_event']!.cost, 10);
    final loot = catalogue.where((card) => card.isLoot).toList();
    expect(loot, hasLength(15));
    expect(loot.every((card) => card.cost == 7), isTrue);
    expect(loot.every((card) => !card.isKingdomCard), isTrue);
    expect(byId['spell_scroll']!.types, contains(CardType.action));
    final pool = SetupEngine().eligibleKingdomPool(
        catalogue, {Expansion.plunder}, const SetupRules(maxCost: 4));
    expect(pool.map((card) => card.id), contains('mapmaker'));
    expect(pool.map((card) => card.id), isNot(contains('sack_of_loot')));
    expect(pool.any((card) => card.isLoot), isFalse);
  });

  test('Plunder setup never replenishes Loot from player discard piles', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    for (final id in [
      'cutthroat',
      'jewelled_egg',
      'pickaxe',
      'sack_of_loot',
      'search',
      'wealthy_village'
    ]) {
      final notes = engine.generateSetupNotes([byId[id]!], []).join(' ');
      expect(notes, contains('all 30 Loot cards (two of each)'), reason: id);
      expect(notes, contains('An empty Loot pile stays empty'), reason: id);
      expect(notes, isNot(contains('shuffle discarded Loot')), reason: id);
    }
    expect(engine.generateSetupNotes([], [byId['cursed']!]).join(' '),
        contains('all 30 Loot cards'));
    expect(engine.generateSetupNotes([byId['crew']!], []).join(' '),
        isNot(contains('Loot pile present')));
    expect(byId['journey_plunder']!.text, contains('not a 3rd turn in a row'));
    expect(byId['journey_plunder']!.text, isNot(contains('Once per turn')));
    expect(byId['trickster']!.text, contains('after drawing your next hand'));
  });

  test('German covers Allies and imports complete rotating piles', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final allies =
        catalogue.where((card) => card.expansion == Expansion.allies).toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(allies, hasLength(72));
    expect(allies.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Kräutersammlerin / Altardienerin / Meisterhexe / Prophetin, '
        'Zauberschüler / Beschwörer / Hexenmeister / Lich, '
        'Tand, Mittelsmann, Königliche Galeere, Jägerin, Importeurin, '
        'Wirtin, Umgestaltung, Barbar\nLandscapes:\nStadtstaat',
        packs: [german]);
    expect(setup.kingdom, hasLength(16));
    expect(setup.kingdom.map((card) => card.pileId).toSet(), hasLength(10));
    expect(
        setup.kingdom.where((card) => card.isSplitPile).map((card) => card.id),
        unorderedEquals([
          'herb_gatherer',
          'acolyte',
          'sorceress',
          'sibyl',
          'student',
          'conjurer',
          'sorcerer',
          'lich'
        ]));
    expect(setup.landscapes.single.id, 'city_state');
    expect(german.lookup('royal_galley')!.text,
        contains('falls sie noch im Spiel ist'));
    expect(german.lookup('royal_galley')!.text, isNot(contains('zur Seite')));
    expect(german.lookup('hunter')!.text,
        contains('zuerst eine Aktionskarte, dann eine Geldkarte'));
    expect(german.lookup('coastal_haven')!.text,
        contains('Ziehe deine neue Hand zusätzlich wie üblich'));
    for (final id in ['voyage', 'island_folk']) {
      expect(german.lookup(id)!.text,
          contains('keinen dritten eigenen Zug in Folge'),
          reason: id);
    }
    expect(german.lookup('importer')!.text, contains('zusätzlich 4 Gefallen'));
    expect(german.lookup('broker')!.text, contains('Wähle eins'));
    expect(
        german.lookup('student')!.text, contains('lege diesen Zauberschüler'));
    expect(german.lookup('conjurer')!.text,
        contains('nimm diesen Beschwörer auf die Hand'));
    expect(german.lookup('sorcerer')!.text,
        contains('bleibt oben auf seinem Nachziehstapel'));
    expect(
        german.lookup('lich')!.text, contains('Setze deinen nächsten Zug aus'));
    expect(german.lookup('league_of_shopkeepers')!.text,
        contains('keine Gefallen aus'));
    expect(german.lookup('woodworkers_guild')!.text,
        contains('Hast du eine entsorgt'));
  });

  test('Allies requirements distinguish draw, cycling and opponent trashing',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final kingdom = byId.values
        .where(
            (card) => card.expansion == Expansion.allies && card.isKingdomCard)
        .toList();
    expect(kingdom, hasLength(49));
    expect(kingdom.map((card) => card.pileId).toSet(), hasLength(31));
    expect(
        kingdom.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'broker',
          'emissary',
          'highwayman',
          'hunter',
          'capital_city',
          'marquis',
          'sibyl',
          'battle_plan',
          'warlord',
          'garrison',
          'stronghold',
          'distant_shore',
          'blacksmith',
          'lich'
        ]));
    expect(
        kingdom
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals(
            ['broker', 'merchant_camp', 'town', 'capital_city', 'lich']));
    expect(
        kingdom.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals([
          'broker',
          'carpenter',
          'sentinel',
          'modify',
          'acolyte',
          'student'
        ]));
    expect(
        byId['sentinel']!.capabilities.trashing, TrashingThroughput.multiple);
    expect(byId['peaceful_cult']!.capabilities.trashing,
        TrashingThroughput.multiple);
    expect(byId['cave_dwellers']!.providesDraw, isFalse);
    expect(byId['barbarian']!.types, isNot(contains(CardType.clash)));
    final clashes =
        kingdom.where((card) => card.types.contains(CardType.clash));
    expect(clashes, hasLength(4));
    expect(clashes.map((card) => card.pileId).toSet(), {'allies_clashes'});
    final pool = SetupEngine().eligibleKingdomPool(byId.values.toList(),
        {Expansion.allies}, const SetupRules(noCursers: true));
    expect(pool.map((card) => card.id), isNot(contains('barbarian')));
    expect(pool.where((card) => card.pileId == 'allies_clashes'), hasLength(4));
    expect(pool.where((card) => card.pileId == 'allies_augurs'), isEmpty);
    expect(pool.where((card) => card.pileId == 'allies_wizards'), isEmpty);
  });

  test('Allies current text preserves replay, selection order and new hands',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    expect(byId['royal_galley']!.text,
        contains('replay it if it is still in play'));
    expect(byId['royal_galley']!.text, isNot(contains('Set it aside')));
    expect(byId['royal_galley']!.text, contains('non-Duration Action'));
    expect(byId['hunter']!.text,
        contains('an Action into your hand, then a Treasure, then a Victory'));
    expect(
        byId['coastal_haven']!.text, contains('Draw your new hand normally'));
    expect(byId['coastal_haven']!.text, isNot(contains('still draw 5')));
    expect(byId['lich']!.text, contains('Skip your next turn'));
    for (final id in [
      'royal_galley',
      'specialist',
      'elder',
      'city_state',
      'market_towns'
    ]) {
      expect(byId[id]!.tags, isNot(contains(CardTag.plusAction)), reason: id);
    }
    for (final id in ['galleria', 'skirmisher']) {
      expect(byId[id]!.tags, isNot(contains(CardTag.gainCard)), reason: id);
    }
    expect(byId['herb_gatherer']!.tags, isNot(contains(CardTag.gainTreasure)));
    expect(byId['voyage']!.text, contains('not a 3rd turn in a row'));
    expect(byId['island_folk']!.text, contains('not a 3rd turn in a row'));
  });

  test('Allies setup preserves Importer Favors and contiguous pile rotation',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    final ordinary = engine.generateSetupNotes(
        [byId['underling']!], [byId['peaceful_cult']!]).join(' ');
    expect(ordinary, contains('start each player with 1 Favor token.'));
    expect(
        ordinary, contains('once per Ally trigger unless it says to repeat'));
    final importer = engine.generateSetupNotes(
        [byId['importer']!], [byId['peaceful_cult']!]).join(' ');
    expect(importer, contains('start each player with 5 Favor tokens.'));
    final rotating = engine.generateSetupNotes(
        byId.values.where((card) => card.pileId == 'allies_augurs').toList(),
        []).join(' ');
    expect(rotating, contains('4 copies of each card'));
    expect(rotating, contains('with Herb Gatherer on top'));
    expect(rotating, contains('identical cards directly beneath it'));
    expect(
        byId.values
            .where((card) => card.expansion == Expansion.allies && card.isAlly),
        hasLength(23));
  });

  test('German covers Menagerie and imports Kingdom, Event and Way names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final menagerie = catalogue
        .where((card) => card.expansion == Expansion.menagerie)
        .toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(menagerie, hasLength(71));
    expect(
        menagerie.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Viehmarkt, Lastkahn, Kopfgeldjägerin, Kavallerie, Schlachtross, '
        'Falknerin, Ziegenhirtin, Drahtzieher, Koppel, Dorfanger\n'
        'Landscapes:\nWeg des Frosches, Wagnis',
        packs: [german]);
    expect(setup.kingdom.map((card) => card.id), [
      'animal_fair',
      'barge',
      'bounty_hunter',
      'cavalry',
      'destrier',
      'falconer',
      'goatherd',
      'mastermind',
      'paddock',
      'village_green'
    ]);
    expect(
        setup.landscapes.map((card) => card.id), ['way_of_the_frog', 'gamble']);
    expect(german.lookup('cavalry')!.text,
        startsWith('Nimm 2 Pferde. Wenn du diese Karte nimmst'));
    expect(german.lookup('paddock')!.text, isNot(contains('+2 Aktionen')));
    expect(german.lookup('paddock')!.text,
        contains('+1 Aktion pro leerem Vorratsstapel'));
    expect(german.lookup('bounty_hunter')!.text,
        contains('Hast du eine Karte verbannt'));
    expect(menagerie.singleWhere((card) => card.id == 'bounty_hunter').text,
        contains('If you Exiled a card'));
    expect(german.lookup('way_of_the_frog')!.text,
        contains('in diesem Zug aus dem Spiel ablegst'));
    expect(german.lookup('way_of_the_mouse')!.text,
        contains('ohne den Typ Dauer'));
    expect(german.lookup('way_of_the_squirrel')!.text,
        contains('nachdem du deine nächste Hand gezogen hast'));
    expect(german.lookup('gamble')!.text,
        contains('Spielst du sie nicht, lege sie ab'));
    expect(german.lookup('invest')!.text, contains('ein Mitspieler'));
    expect(german.lookup('seize_the_day')!.text, startsWith('Einmal im Spiel'));
    expect(german.lookup('scrap')!.text,
        contains('pro 1 Geld ihrer Kosten eine andere Möglichkeit'));
    expect(german.lookup('horse')!.name, 'Pferd');
  });

  test('Menagerie requirements distinguish cycling, reactions and Exile', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final kingdom = byId.values
        .where((card) =>
            card.expansion == Expansion.menagerie && card.isKingdomCard)
        .toList();
    expect(kingdom, hasLength(30));
    expect(
        kingdom.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'barge',
          'black_cat',
          'cavalry',
          'destrier',
          'goatherd',
          'hunting_lodge',
          'sheepdog',
          'village_green',
          'wayfarer'
        ]));
    expect(
        kingdom
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals([
          'hostelry',
          'hunting_lodge',
          'paddock',
          'snowy_village',
          'village_green'
        ]));
    expect(kingdom.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals(['animal_fair', 'goatherd', 'scrap']));
    expect(byId['snowy_village']!.capabilities.extraActions, 3);
    expect(byId['cavalry']!.capabilities.draw, DrawCapability.conditional);
    expect(byId['scrap']!.tags, contains(CardTag.plusCoin));
    expect(byId['horse']!.capabilities.draw, DrawCapability.net);
    for (final id in ['camel_train', 'transport']) {
      expect(byId[id]!.tags, isNot(contains(CardTag.gainCard)), reason: id);
    }
    for (final id in ['mastermind', 'delay', 'march', 'toil']) {
      expect(byId[id]!.tags, isNot(contains(CardTag.plusAction)), reason: id);
    }
  });

  test('Menagerie corrected effects retain their triggers and phases', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    expect(byId['cavalry']!.text, startsWith('Gain 2 Horses. When you gain'));
    expect(byId['cavalry']!.text, contains('return to your Action phase'));
    expect(byId['paddock']!.text,
        '+\$2. Gain 2 Horses. +1 Action per empty Supply pile.');
    expect(byId['paddock']!.tags, isNot(contains(CardTag.plusTwoActions)));
    expect(byId['animal_fair']!.text, contains('When buying this'));
    expect(byId['gamble']!.text, contains('Reveal the top card'));
    expect(byId['gamble']!.text, contains('If you do not play it, discard it'));
    expect(byId['gamble']!.tags, isNot(contains(CardTag.plusCoin)));
    expect(byId['commerce']!.tags, isNot(contains(CardTag.plusCoin)));
    expect(byId['alliance']!.tags, contains(CardTag.gainVictory));
    expect(byId['way_of_the_frog']!.text,
        contains('When you discard this from play this turn'));
    expect(byId['way_of_the_squirrel']!.text,
        contains('normally after drawing your next hand'));
    expect(byId['way_of_the_pig']!.providesDraw, isFalse);
    expect(byId['way_of_the_horse']!.providesDraw, isTrue);
    expect(byId['way_of_the_mouse']!.text, contains('non-Duration'));
  });

  test('Menagerie setup distinguishes a Way from a Horse gainer', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final engine = SetupEngine();
    final wayOnly =
        engine.generateSetupNotes([], [byId['way_of_the_horse']!]).join(' ');
    expect(
        wayOnly, contains('choose its normal on-play instructions or one Way'));
    expect(wayOnly, isNot(contains('all 30 Horses')));
    expect(byId['way_of_the_horse']!.pileCardIds, isEmpty);
    expect(engine.generateSetupNotes([byId['cavalry']!], []).join(' '),
        contains('all 30 Horses'));
    final exile =
        engine.generateSetupNotes([byId['camel_train']!], []).join(' ');
    expect(exile, contains('discard all copies'));
    expect(exile, contains('not gaining or trashing'));
    expect(
        byId.values.where(
            (card) => card.expansion == Expansion.menagerie && card.isWay),
        hasLength(20));
    expect(
        byId.values.where(
            (card) => card.expansion == Expansion.menagerie && card.isEvent),
        hasLength(20));
  });

  test('German covers Renaissance and imports Kingdom and Project names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final renaissance = catalogue
        .where((card) => card.expansion == Expansion.renaissance)
        .toList();
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(renaissance, hasLength(50));
    expect(
        renaissance.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    final setup = resolveSetupText(
        catalogue,
        'Schauspieltruppe, Grenzposten, Frachtschiff, Goldmünze, Fahnenträger, '
        'Fortschritt, Anwerber, Forscherin, Freibeuterin, Zepter\n'
        'Landscapes:\nErkundung, Innovation',
        packs: [german]);
    expect(setup.kingdom.map((card) => card.id), [
      'acting_troupe',
      'border_guard',
      'cargo_ship',
      'ducat',
      'flag_bearer',
      'improve',
      'recruiter',
      'research',
      'swashbuckler',
      'scepter'
    ]);
    expect(
        setup.landscapes.map((card) => card.id), ['exploration', 'innovation']);
    expect(german.lookup('patron')!.text, contains('in einer Aktionsphase'));
    expect(german.lookup('scepter')!.text, contains('ohne den Typ Befehl'));
    expect(german.lookup('exploration')!.text,
        contains('in dieser Phase keine Karten genommen'));
    expect(german.lookup('exploration')!.text, isNot(contains('gekauft')));
    expect(german.lookup('innovation')!.text,
        startsWith('Einmal während jedes deiner Züge'));
    expect(german.lookup('innovation')!.text, isNot(contains('erste')));
    expect(german.lookup('priest')!.text, contains('Danach erhältst du'));
    expect(german.lookup('experiment')!.text,
        contains('jenes gibt dir kein zusätzliches Experiment'));
    expect(german.lookup('sinister_plot')!.text,
        contains('entferne alle deine Marker'));
    expect(german.lookup('treasure_chest')!.name, 'Schatzkiste');
    expect(german.lookup('lantern')!.text,
        contains('Alle 3 müssen Aktionskarten sein'));
    expect(german.lookup('flag')!.text, contains('1 zusätzliche Karte'));
  });

  test('Renaissance requirements count direct draw, Villagers and own trashing',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final kingdom = byId.values
        .where((card) =>
            card.expansion == Expansion.renaissance && card.isKingdomCard)
        .toList();
    expect(kingdom, hasLength(25));
    expect(
        kingdom.where((card) => card.providesDraw).map((card) => card.id),
        unorderedEquals([
          'experiment',
          'lackeys',
          'old_witch',
          'research',
          'scholar',
          'seer',
          'silk_merchant',
          'swashbuckler'
        ]));
    expect(
        kingdom
            .where((card) => card.providesExtraActions)
            .map((card) => card.id),
        unorderedEquals([
          'acting_troupe',
          'hideout',
          'lackeys',
          'mountain_village',
          'recruiter',
          'silk_merchant'
        ]));
    expect(
        kingdom.where((card) => card.trashesOwnCards).map((card) => card.id),
        unorderedEquals([
          'ducat',
          'hideout',
          'improve',
          'priest',
          'recruiter',
          'research',
          'treasurer'
        ]));
    expect(byId['acting_troupe']!.capabilities.extraActions, 3);
    expect(byId['lackeys']!.capabilities.extraActions, 2);
    expect(byId['patron']!.providesExtraActions, isFalse);
    expect(byId['sculptor']!.providesExtraActions, isFalse);
    for (final id in ['city_gate', 'silos']) {
      expect(byId[id]!.providesDraw, isFalse, reason: id);
    }
    expect(byId['barracks']!.capabilities.extraActions, 1);
    expect(byId['flag']!.capabilities.draw, DrawCapability.net);
  });

  test('Renaissance retains later errata and distinguishes replay from Actions',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    expect(byId['patron']!.text, contains('in an Action phase'));
    expect(byId['patron']!.tags, contains(CardTag.plusCoin));
    expect(byId['scepter']!.types, contains(CardType.command));
    expect(byId['scepter']!.text, contains('non-Command Action'));
    expect(byId['exploration']!.text, contains('gained no cards'));
    expect(
        byId['innovation']!.text, contains('Once during each of your turns'));
    expect(byId['innovation']!.text, isNot(contains('first time')));
    for (final id in ['scepter', 'piazza', 'citadel']) {
      expect(byId[id]!.tags, isNot(contains(CardTag.plusAction)), reason: id);
    }
    for (final id in ['cargo_ship', 'innovation']) {
      expect(byId[id]!.tags, isNot(contains(CardTag.gainCard)), reason: id);
    }
    expect(
        byId.values.where((card) =>
            card.expansion == Expansion.renaissance && card.isLandscape),
        hasLength(20));
    expect(
        byId.values.where((card) =>
            card.expansion == Expansion.renaissance &&
            !card.isLandscape &&
            !card.isKingdomCard),
        hasLength(5));
  });

  test('Renaissance setup gives two Project cubes and one of each Artifact',
      () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final notes = SetupEngine().generateSetupNotes([
      byId['border_guard']!,
      byId['flag_bearer']!,
      byId['swashbuckler']!,
      byId['treasurer']!
    ], [
      byId['cathedral']!
    ]).join(' ');
    expect(notes, contains('two cubes of one color'));
    expect(notes, contains('at most two different Projects'));
    expect(notes, contains('set aside one of each'));
    for (final artifact in [
      'Lantern',
      'Horn',
      'Flag',
      'Key',
      'Treasure Chest'
    ]) {
      expect(notes, contains(artifact));
    }
    expect(notes, contains('take it from its current holder'));
  });

  test('Artisan gains to hand without drawing a card', () {
    final artisan = cards.singleWhere((card) => card['id'] == 'artisan');
    expect(artisan['tags'], isNot(contains('plusCard')));
    expect(artisan['text'], isNot(contains('+1 Card')));
    final german =
        jsonDecode(File('assets/data/translations/de.json').readAsStringSync());
    expect(german['cards']['artisan']['text'], isNot(contains('+1 Karte')));
  });

  test('German covers both Base editions and imports the printed names', () {
    final catalogue = cards.map(KingdomCard.fromJson).toList();
    final base = catalogue
        .where((card) => card.expansion == Expansion.baseSecondEdition);
    expect(base, hasLength(32));
    final german = TranslationService.validatePack(
        File('assets/data/translations/de.json').readAsStringSync(),
        catalogue.map((card) => card.id).toSet());
    expect(base.where((card) => german.lookup(card.id)?.isComplete != true),
        isEmpty);
    expect(german.lookup('artisan')?.name, 'Töpferei');
    expect(german.lookup('bandit')?.name, 'Banditin');
    expect(german.lookup('woodcutter')?.name, 'Holzfäller');
    final setup = resolveSetupText(catalogue,
        'Keller, Markt, Händlerin, Miliz, Mine, Burggraben, Umbau, Schmiede, Dorf, Werkstatt',
        packs: [german]);
    expect(
        setup.kingdom.map((card) => card.id),
        unorderedEquals([
          'cellar',
          'market',
          'merchant',
          'militia',
          'mine',
          'moat',
          'remodel',
          'smithy',
          'village',
          'workshop',
        ]));
    expect(
        resolveImportedKingdomCards(catalogue, ['Handwerker']).cards.single.id,
        'artisan');
  });

  test('strategy tips attribute Curse giving to the correct type of card', () {
    final byId = {
      for (final raw in cards) raw['id'] as String: KingdomCard.fromJson(raw)
    };
    final archetype = HeuristicEngine().analyze([
      byId['bandit']!,
      byId['bureaucrat']!,
      byId['ill_gotten_gains']!
    ]).singleWhere((entry) => entry.kind == ArchetypeKind.aggressiveControl);
    expect(archetype.headline, 'Deck Disruption');
    expect(archetype.tips.join(' '), isNot(contains('hands out Curses')));
    final notes = SetupEngine()
        .generateSetupNotes([byId['ill_gotten_gains']!], []).join(' ');
    expect(notes, contains('Curse-giving cards present'));
    expect(notes, isNot(contains('Curse-giving Attacks')));
  });

  test('card parsing rejects an unknown tag with the card ID', () {
    final artisan = cards.singleWhere((card) => card['id'] == 'artisan');
    expect(
      () => KingdomCard.fromJson({
        ...artisan,
        'tags': ['typo']
      }),
      throwsA(isA<FormatException>()
          .having((error) => error.message, 'message', contains('artisan'))),
    );
  });

  test('required Prophecies remain available for generation', () {
    final prophecies =
        cards.where((card) => (card['types'] as List).contains('prophecy'));
    expect(prophecies, isNotEmpty);
    expect(
        prophecies.map(KingdomCard.fromJson).every((card) => card.isLandscape),
        isTrue);
  });

  test('split piles have distinct IDs and a complete group in one expansion',
      () {
    final groups = <String, List<KingdomCard>>{};
    final parsed = cards.map(KingdomCard.fromJson).toList();
    final allIds = parsed.map((card) => card.id).toSet();
    for (final card in parsed.where((card) => card.isSplitPile)) {
      (groups[card.pileId] ??= []).add(card);
    }
    for (final entry in groups.entries) {
      expect(allIds, isNot(contains(entry.key)));
      expect(entry.value.length, greaterThan(1), reason: entry.key);
      expect(entry.value.map((card) => card.expansion).toSet(), hasLength(1),
          reason: entry.key);
      expect(entry.value.every((card) => card.isKingdomCard), isTrue,
          reason: entry.key);
    }
  });
}
