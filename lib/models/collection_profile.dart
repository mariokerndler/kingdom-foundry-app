import 'expansion.dart';
import 'kingdom_card.dart';

enum CollectionEdition {
  full('Full box'),
  firstEdition('First edition (shared cards)'),
  updatePack('Update pack only'),
  upgraded('First edition + update pack');

  final String label;
  const CollectionEdition(this.label);
}

// Each update pack selects a subset of the existing, canonical card IDs.
const updatePackCards = <Expansion, Set<String>>{
  Expansion.baseSecondEdition: {
    'artisan',
    'bandit',
    'harbinger',
    'merchant',
    'poacher',
    'sentry',
    'vassal'
  },
  Expansion.intrigueSecondEdition: {
    'courtier',
    'diplomat',
    'lurker',
    'mill',
    'patrol',
    'replace',
    'secretPassage'
  },
  Expansion.seasideSecondEdition: {
    'astrolabe',
    'blockade',
    'corsair',
    'monkey',
    'pirate',
    'sailor',
    'sea_chart',
    'sea_witch',
    'tide_pools'
  },
  Expansion.prosperitySecondEdition: {
    'anvil',
    'charlatan',
    'clerk',
    'collection',
    'crystal_ball',
    'investment',
    'magnate',
    'tiara',
    'war_chest'
  },
  Expansion.hinterlandsSecondEdition: {
    'berserker',
    'cauldron',
    'guard_dog',
    'nomads',
    'souk',
    'trail',
    'weaver',
    'wheelwright',
    'witchs_hut'
  },
  Expansion.cornucopiaGuildsSecondEdition: {
    'carnival',
    'farmhands',
    'farrier',
    'ferryman',
    'footpad',
    'infirmary',
    'joust',
    'shop',
    'coronet',
    'courser',
    'demesne',
    'housecarl',
    'huge_turnip',
    'renown'
  },
};

class CollectionProfile {
  final Map<Expansion, CollectionEdition> boxes;
  final Set<String> promoPiles;
  final Set<Expansion> selected;

  const CollectionProfile(
      {required this.boxes, required this.promoPiles, required this.selected});

  Set<Expansion> get available => {
        ...boxes.keys,
        if (promoPiles.isNotEmpty) Expansion.promos,
      };

  bool owns(KingdomCard card) {
    if (card.expansion == Expansion.promos) {
      return promoPiles.contains(card.pileId);
    }
    final inPack = updatePackCards[card.expansion]?.contains(card.id) ?? false;
    return switch (boxes[card.expansion]) {
      CollectionEdition.full => !card.firstEditionOnly,
      CollectionEdition.upgraded => true,
      CollectionEdition.firstEdition => !inPack,
      CollectionEdition.updatePack => inPack,
      null => false,
    };
  }

  CollectionProfile withSelection(Set<Expansion> expansions) =>
      CollectionProfile(
          boxes: Map.unmodifiable(boxes),
          promoPiles: Set.unmodifiable(promoPiles),
          selected: Set.unmodifiable(expansions.intersection(available)));

  Map<String, dynamic> toJson() => {
        'boxes': boxes.map(
            (expansion, edition) => MapEntry(expansion.name, edition.name)),
        'promos': promoPiles.toList(),
        'selected': selected.map((expansion) => expansion.name).toList(),
      };

  factory CollectionProfile.fromJson(Map<String, dynamic> json) {
    final boxes = json['boxes'] as Map? ?? const {};
    final selected = json['selected'] as List? ?? const [];
    final profile = CollectionProfile(
      boxes: {
        for (final expansion
            in Expansion.values.where((value) => value != Expansion.promos))
          for (final edition in CollectionEdition.values)
            if (boxes[expansion.name] == edition.name &&
                (edition == CollectionEdition.full ||
                    updatePackCards.containsKey(expansion)))
              expansion: edition,
      },
      promoPiles:
          (json['promos'] as List? ?? const []).whereType<String>().toSet(),
      selected: const {},
    );
    return profile.withSelection(Expansion.values
        .where((expansion) => selected.contains(expansion.name))
        .toSet());
  }
}
