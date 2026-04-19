import 'kingdom_card.dart';

class CompactShareSelection {
  final List<String> kingdomSlotKeys;
  final List<String> landscapeIds;

  const CompactShareSelection({
    required this.kingdomSlotKeys,
    required this.landscapeIds,
  });
}

class ShareCodebook {
  static const compactPrefix = 'KF2-';
  static const kingdomSlotCount = 10;
  static const maxLandscapeCount = 15;
  static const _landscapeCountRadix = 16;
  static const _base58Alphabet =
      '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static final List<String> kingdomSlotCodebook =
      _kingdomSlotData.trim().split('\n');
  static final List<String> landscapeCodebook =
      _landscapeData.trim().split('\n');

  static final Map<String, int> _kingdomIndexByKey = {
    for (var i = 0; i < kingdomSlotCodebook.length; i++) kingdomSlotCodebook[i]: i,
  };
  static final Map<String, int> _landscapeIndexById = {
    for (var i = 0; i < landscapeCodebook.length; i++) landscapeCodebook[i]: i,
  };
  static final BigInt _kingdomCombinationCount =
      _choose(kingdomSlotCodebook.length, kingdomSlotCount);
  static final BigInt _checksumModulo = BigInt.from(
    _base58Alphabet.length * _base58Alphabet.length,
  );

  static String encode({
    required Iterable<String> kingdomSlotKeys,
    required Iterable<String> landscapeIds,
  }) {
    final normalizedKingdom = _normalizeIndices(
      values: kingdomSlotKeys,
      indexByValue: _kingdomIndexByKey,
      expectedCount: kingdomSlotCount,
      label: 'kingdom slots',
    );
    final normalizedLandscapes = _normalizeIndices(
      values: landscapeIds,
      indexByValue: _landscapeIndexById,
      maxCount: maxLandscapeCount,
      label: 'landscape cards',
    );

    final landscapeCount = normalizedLandscapes.length;
    final kingdomRank = _rankCombination(normalizedKingdom);
    final landscapeSpace = _choose(landscapeCodebook.length, landscapeCount);
    final landscapeRank = _rankCombination(normalizedLandscapes);
    final payload =
        (((kingdomRank * landscapeSpace) + landscapeRank) *
                BigInt.from(_landscapeCountRadix)) +
            BigInt.from(landscapeCount);

    final payloadBody = _encodeBase58(payload);
    final checksum = _checksumFor(payload);
    return '$compactPrefix$payloadBody$checksum';
  }

  static CompactShareSelection? tryDecode(String raw) {
    final value = raw.trim();
    if (!value.startsWith(compactPrefix)) return null;

    final body = value.substring(compactPrefix.length);
    if (body.length < 3) return null;

    final payloadPart = body.substring(0, body.length - 2);
    final checksumPart = body.substring(body.length - 2);

    final payload = _tryDecodeCanonicalBase58(payloadPart);
    if (payload == null) return null;
    if (_checksumFor(payload) != checksumPart) return null;

    final landscapeCount =
        (payload % BigInt.from(_landscapeCountRadix)).toInt();
    if (landscapeCount > maxLandscapeCount) return null;

    final payloadWithoutCount = payload ~/ BigInt.from(_landscapeCountRadix);
    final landscapeSpace = _choose(landscapeCodebook.length, landscapeCount);
    if (landscapeSpace == BigInt.zero) return null;

    final landscapeRank = payloadWithoutCount % landscapeSpace;
    final kingdomRank = payloadWithoutCount ~/ landscapeSpace;
    if (kingdomRank >= _kingdomCombinationCount) return null;

    final kingdomIndexes = _unrankCombination(
      n: kingdomSlotCodebook.length,
      k: kingdomSlotCount,
      rank: kingdomRank,
    );
    final landscapeIndexes = _unrankCombination(
      n: landscapeCodebook.length,
      k: landscapeCount,
      rank: landscapeRank,
    );

    return CompactShareSelection(
      kingdomSlotKeys:
          kingdomIndexes.map((index) => kingdomSlotCodebook[index]).toList(),
      landscapeIds:
          landscapeIndexes.map((index) => landscapeCodebook[index]).toList(),
    );
  }

  static List<String> extractKingdomSlotKeys(Iterable<KingdomCard> cards) {
    final unique = <String>{};
    for (final card in cards) {
      unique.add(card.splitPileId ?? card.id);
    }
    final slotKeys = unique.toList();
    slotKeys.sort((a, b) => _kingdomIndexByKey[a]!.compareTo(_kingdomIndexByKey[b]!));
    return slotKeys;
  }

  static List<String> extractLandscapeIds(Iterable<KingdomCard> cards) {
    final unique = cards.map((card) => card.id).toSet().toList();
    unique.sort((a, b) => _landscapeIndexById[a]!.compareTo(_landscapeIndexById[b]!));
    return unique;
  }

  static List<KingdomCard>? expandKingdomSlots(
    Iterable<String> kingdomSlotKeys,
    List<KingdomCard> allCards,
  ) {
    final bySlot = <String, List<KingdomCard>>{};
    for (final card in allCards.where((card) => card.isKingdomCard)) {
      final slotKey = card.splitPileId ?? card.id;
      (bySlot[slotKey] ??= []).add(card);
    }

    final kingdom = <KingdomCard>[];
    for (final slotKey in kingdomSlotKeys) {
      final cards = bySlot[slotKey];
      if (cards == null || cards.isEmpty) return null;
      final sorted = [...cards]..sort(_kingdomCardComparator);
      kingdom.addAll(sorted);
    }
    return kingdom;
  }

  static List<KingdomCard>? expandLandscapes(
    Iterable<String> landscapeIds,
    List<KingdomCard> allCards,
  ) {
    final byId = {for (final card in allCards) card.id: card};
    final landscape = <KingdomCard>[];
    for (final id in landscapeIds) {
      final card = byId[id];
      if (card == null) return null;
      landscape.add(card);
    }
    landscape.sort(_landscapeCardComparator);
    return landscape;
  }

  static int _kingdomCardComparator(KingdomCard a, KingdomCard b) {
    final cost = a.cost.compareTo(b.cost);
    if (cost != 0) return cost;
    return a.name.compareTo(b.name);
  }

  static int _landscapeCardComparator(KingdomCard a, KingdomCard b) {
    final type = _landscapeTypeOrder(a).compareTo(_landscapeTypeOrder(b));
    if (type != 0) return type;
    return a.name.compareTo(b.name);
  }

  static int _landscapeTypeOrder(KingdomCard card) {
    if (card.isEvent) return 0;
    if (card.isLandmark) return 1;
    if (card.isProject) return 2;
    if (card.isWay) return 3;
    if (card.isAlly) return 4;
    if (card.isProphecy) return 5;
    if (card.isTrait) return 6;
    return 7;
  }

  static List<int> _normalizeIndices({
    required Iterable<String> values,
    required Map<String, int> indexByValue,
    required String label,
    int? expectedCount,
    int? maxCount,
  }) {
    final indexes = <int>{};
    for (final value in values) {
      final index = indexByValue[value];
      if (index == null) {
        throw ArgumentError('Unknown $label entry "$value".');
      }
      indexes.add(index);
    }

    final normalized = indexes.toList()..sort();
    if (expectedCount != null && normalized.length != expectedCount) {
      throw ArgumentError(
        'Expected exactly $expectedCount $label but found ${normalized.length}.',
      );
    }
    if (maxCount != null && normalized.length > maxCount) {
      throw ArgumentError(
        'Expected at most $maxCount $label but found ${normalized.length}.',
      );
    }
    return normalized;
  }

  static BigInt _rankCombination(List<int> combination) {
    var rank = BigInt.zero;
    for (var i = 0; i < combination.length; i++) {
      rank += _choose(combination[i], i + 1);
    }
    return rank;
  }

  static List<int> _unrankCombination({
    required int n,
    required int k,
    required BigInt rank,
  }) {
    if (k == 0) return const [];

    final combination = List<int>.filled(k, 0);
    var remaining = rank;
    var upperBound = n - 1;

    for (var i = k; i >= 1; i--) {
      var value = upperBound;
      while (_choose(value, i) > remaining) {
        value--;
      }
      combination[i - 1] = value;
      remaining -= _choose(value, i);
      upperBound = value - 1;
    }

    return combination;
  }

  static BigInt _choose(int n, int k) {
    if (k < 0 || k > n) return BigInt.zero;
    if (k == 0 || k == n) return BigInt.one;
    final effectiveK = k > n - k ? n - k : k;
    var result = BigInt.one;
    for (var i = 1; i <= effectiveK; i++) {
      result = (result * BigInt.from(n - effectiveK + i)) ~/ BigInt.from(i);
    }
    return result;
  }

  static String _encodeBase58(BigInt value) {
    if (value == BigInt.zero) return _base58Alphabet[0];

    final chars = <String>[];
    final radix = BigInt.from(_base58Alphabet.length);
    var remaining = value;

    while (remaining > BigInt.zero) {
      final index = (remaining % radix).toInt();
      chars.add(_base58Alphabet[index]);
      remaining ~/= radix;
    }

    return chars.reversed.join();
  }

  static BigInt? _tryDecodeCanonicalBase58(String value) {
    if (value.isEmpty) return null;

    var decoded = BigInt.zero;
    final radix = BigInt.from(_base58Alphabet.length);

    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final index = _base58Alphabet.indexOf(char);
      if (index == -1) return null;
      decoded = (decoded * radix) + BigInt.from(index);
    }

    if (_encodeBase58(decoded) != value) return null;
    return decoded;
  }

  static String _checksumFor(BigInt payload) {
    final checksumValue =
        (_crc16Ccitt(_bigIntToBytes(payload)) % _checksumModulo.toInt());
    final first = checksumValue ~/ _base58Alphabet.length;
    final second = checksumValue % _base58Alphabet.length;
    return '${_base58Alphabet[first]}${_base58Alphabet[second]}';
  }

  static List<int> _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) return const [0];

    final bytes = <int>[];
    var remaining = value;
    while (remaining > BigInt.zero) {
      bytes.add((remaining & BigInt.from(0xFF)).toInt());
      remaining >>= 8;
    }
    return bytes.reversed.toList(growable: false);
  }

  static int _crc16Ccitt(List<int> bytes) {
    var crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= byte << 8;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  static const _kingdomSlotData = '''
abundance
acting_troupe
advisor
alchemist
alley
allies_augurs
allies_clashes
allies_forts
allies_odysseys
allies_townsfolk
allies_wizards
altar
amulet
animal_fair
anvil
apothecary
apprentice
archive
aristocrat
armory
artificer
artisan
artist
astrolabe
baker
band_of_misfits
bandit
bandit_camp
bank
barbarian
bard
barge
baron
bat
bauble
bazaar
beggar
berserker
bishop
black_cat
black_market
blessed_village
blockade
border_guard
border_village
bounty_hunter
bridge
bridge_troll
broker
bureaucrat
buried_treasure
butcher
cabin_boy
cage
camel_train
candlestick_maker
capital
capital_city
captain
caravan
caravan_guard
cardinal
cargo_ship
carnival
carpenter
cartographer
castles
catacombs
cauldron
cavalry
cellar
cemetery
champion
change
changeling
chapel
chariot_race
charlatan
charm
church
city
city_quarter
clerk
cobbler
coin_of_the_realm
collection
conclave
conspirator
contract
coronet
corsair
councilRoom
count
counterfeit
courier
courser
courtier
courtyard
coven
craftsman
crew
crossroads
crown
crucible
crumbling_castle
crypt
crystal_ball
cultist
cursed_gold
cursed_village
cutpurse
cutthroat
daimyo
dame_anna
dame_josephine
dame_molly
dame_natalie
dame_sylvia
death_cart
demesne
den_of_sin
destrier
develop
devils_workshop
diplomat
disciple
dismantle
displace
distant_lands
druid
ducat
duke
dungeon
duplicate
emissary
empires_catapult_rocks
empires_encampment_plunder
empires_gladiator_fortune
empires_patrician_emporium
empires_settlers_bustling
enchantress
engineer
enlarge
envoy
exorcist
expand
experiment
fairgrounds
faithful_hound
falconer
familiar
farm
farmers_market
farmhands
farmland
farrier
feodum
ferryman
festival
figurine
first_mate
fisherman
fishingVillage
fishmonger
flag_bearer
flagship
fool
fools_gold
footpad
forager
forge
fortress
fortune_hunter
forum
frigate
fugitive
galleria
gardens
gatekeeper
gear
ghost
ghost_town
giant
goat
goatherd
gold_mine
golem
gondola
governor
grand_castle
grand_market
graverobber
groom
grotto
groundskeeper
guard_dog
guardian
guide
guildmaster
haggler
hamlet
harbinger
harbor_village
haunted_castle
haunted_mirror
haunted_woods
haven
herald
herbalist
hermit
hero
hideout
highway
highwayman
hireling
hoard
horn_of_plenty
horse
hostelry
housecarl
huge_turnip
humble_castle
hunter
hunting_grounds
hunting_lodge
hunting_party
idol
imp
imperial_envoy
importer
improve
infirmary
inn
innkeeper
inventor
investment
ironmonger
ironworks
island
jack_of_all_trades
jester
jewelled_egg
journeyman
joust
junk_dealer
kiln
kings_cache
kings_castle
kings_court
kitsune
knights
laboratory
lackeys
landing_party
legionary
leprechaun
library
lighthouse
litter
livery
longship
lookout
lost_city
lucky_coin
lurker
madman
magic_lamp
magnate
magpie
mapmaker
marauder
marchland
margrave
market
market_square
maroon
marquis
masquerade
mastermind
menagerie
mercenary
merchant
merchant_camp
merchant_guild
merchantShip
messenger
militia
mill
mine
mining_road
miningVillage
minion
mint
miser
moat
modify
monastery
moneylender
monkey
monument
mountain_shrine
mountain_village
mystic
native_village
necromancer
night_watchman
ninja
nobles
nomads
oasis
old_witch
opulent_castle
outpost
overlord
paddock
page
pasture
patrol
patron
pawn
peasant
peddler
pendant
philosophers_stone
pickaxe
pilgrim
pillage
pirate
pixie
plaza
poacher
poet
pooka
poor_house
port
possession
pouch
priest
prince
procession
promos_sauna_avanto
quarry
quartermaster
rabble
raider
ranger
ratcatcher
rats
raze
rebuild
recruiter
relic
remake
remodel
renown
replace
research
rice
rice_broker
river_shrine
riverboat
rogue
ronin
root_cellar
rope
royal_blacksmith
royal_carriage
royal_galley
rustic_village
sack_of_loot
sacred_grove
sacrifice
sage
sailor
salvager
samurai
sanctuary
scavenger
scepter
scheme
scholar
scrap
scrying_pool
sculptor
sea_chart
sea_witch
search
secluded_shrine
secret_cave
secretPassage
seer
sentinel
sentry
shaman
shantyTown
sheepdog
shepherd
shop
silk_merchant
silver_mine
sir_bailey
sir_destry
sir_martin
sir_michael
sir_vander
siren
skirmisher
skulk
sleigh
small_castle
smithy
smugglers
snake_witch
snowy_village
soldier
soothsayer
souk
specialist
spice_merchant
spices
sprawling_castle
squire
stables
stash
steward
stockpile
stonemason
storeroom
storyteller
stowaway
supplies
swamp_hag
swamp_shacks
swap
swashbuckler
swindler
sycophant
tactician
tanuki
taskmaster
tea_house
teacher
temple
throneRoom
tiara
tide_pools
tools
tormentor
torturer
town
tracker
trader
tradingPost
tragic_hero
trail
transmogrify
transmute
treasure_hunter
treasure_map
treasure_trove
treasurer
treasury
trickster
tunnel
underling
university
upgrade
urchin
vagrant
vampire
vassal
vault
villa
village
village_green
villain
vineyard
walled_village
wandering_minstrel
war_chest
warehouse
warrior
watchtower
wayfarer
wealthy_village
weaver
werewolf
wharf
wheelwright
wild_hunt
will_o_wisp
wine_merchant
wish
wishingWell
witch
witchs_hut
workers_village
workshop
young_witch
zombie_apprentice
zombie_mason
zombie_spy
''';

  static const _landscapeData = '''
academy
advance
alliance
alms
amass
annex
approaching_army
aqueduct
architects_guild
arena
asceticism
avoid
ball
band_of_nomads
bandit_fort
banish
banquet
bargain
barracks
basilica
baths
battlefield
biding_time
bonfire
borrow
bureaucracy
bury
canal
capitalism
cathedral
cave_dwellers
cheap
circle_of_witches
citadel
city_gate
city_state
coastal_haven
colonnade
commerce
conquest
continue_event
crafters_guild
credit
crop_rotation
cursed
defiled_shrine
delay
deliver
delve
demand
desert_guides
desperation
divine_wind
dominate
donate
enclave
enhance
enlightenment
expedition
exploration
fair
family_of_inventors
fated
fawning
fellowship_of_scribes
ferry
fleet
flourishing_trade
foray
foresight
forest_dwellers
fountain
friendly
gamble
gang_of_pickpockets
gather
good_harvest
great_leader
growth
guildhall
harsh_winter
hasty
inheritance
inherited
innovation
inspiring
invasion
invest
island_folk
journey_plunder
keep
kind_emperor
kintsugi
labyrinth
launch
league_of_bankers
league_of_shopkeepers
looting
lost_arts
maelstrom
march
market_towns
mirror
mission
mountain_folk
mountain_pass
museum
nearby
obelisk
orchard
order_of_astrologers
order_of_masons
pageant
palace
panic
pathfinding
patient
peaceful_cult
peril
piazza
pilgrimage
pious
plan
plateau_shepherds
populate
practice
prepare
progress
prosper_event
pursue
quest
raid
rapid_expansion
reap
receive_tribute
reckless
rich
ride
ritual
road_network
rush
salt_the_earth
save
scouting_party
scrounge
sea_trade
seaway
seize_the_day
sewers
shy
sickness
silos
sinister_plot
stampede
star_chart
summon
tax
tireless
toil
tomb
tower
trade
training
transport
trappers_lodge
travelling_fair
triumph
triumphal_arch
wall
way_of_the_butterfly
way_of_the_camel
way_of_the_chameleon
way_of_the_frog
way_of_the_goat
way_of_the_horse
way_of_the_mole
way_of_the_monkey
way_of_the_mouse
way_of_the_mule
way_of_the_otter
way_of_the_owl
way_of_the_ox
way_of_the_pig
way_of_the_rat
way_of_the_seal
way_of_the_sheep
way_of_the_squirrel
way_of_the_turtle
way_of_the_worm
wedding
windfall
wolf_den
woodworkers_guild
''';
}
