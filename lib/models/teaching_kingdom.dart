typedef TeachingKingdom = ({String name, String lesson, List<String> cardIds});

const _firstGameCommonPiles = [
  'cellar',
  'market',
  'militia',
  'mine',
  'moat',
  'remodel',
  'smithy',
  'village',
  'workshop',
];

// Publisher's recommended sets from the Base and Intrigue rulebooks.
const teachingKingdoms = <TeachingKingdom>[
  (
    name: 'First Game',
    lesson:
        'Learn extra Actions, draw, gaining, and defending against Attacks.',
    cardIds: [..._firstGameCommonPiles, 'merchant'],
  ),
  (
    name: 'First Game (1st Ed.)',
    lesson:
        'Learn extra Actions, drawing, gaining, and the extra Buy from Woodcutter.',
    cardIds: [..._firstGameCommonPiles, 'woodcutter'],
  ),
  (
    name: 'Deck Top',
    lesson:
        'Practice arranging the top of your deck and drawing the cards you need.',
    cardIds: [
      'artisan',
      'bureaucrat',
      'councilRoom',
      'festival',
      'harbinger',
      'laboratory',
      'moneylender',
      'sentry',
      'vassal',
      'village'
    ],
  ),
  (
    name: 'Grand Scheme',
    lesson:
        'Try cost reduction and a split between Base and Intrigue mechanics.',
    cardIds: [
      'bridge',
      'mill',
      'miningVillage',
      'patrol',
      'shantyTown',
      'artisan',
      'councilRoom',
      'market',
      'militia',
      'workshop'
    ],
  ),
];
