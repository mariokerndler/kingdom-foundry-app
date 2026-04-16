import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_foundry/models/card_metadata.dart';
import 'package:kingdom_foundry/models/card_type.dart';
import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/translation_pack.dart';
import 'package:kingdom_foundry/providers/translation_provider.dart';

void main() {
  test('localizedCardProvider uses translation when present', () {
    final card = KingdomCard(
      id: 'village',
      name: 'Village',
      expansion: Expansion.baseSecondEdition,
      types: [CardType.action],
      tags: [],
      cost: 3,
      text: '+1 Card. +2 Actions.',
      metadata: const CardMetadata(),
    );

    final container = ProviderContainer(
      overrides: [
        activeTranslationPackProvider.overrideWith(
          (ref) => const AsyncValue.data(
            TranslationPack(
              languageCode: 'de',
              label: 'Deutsch',
              cards: {
                'village': CardTranslation(
                  name: 'Dorf',
                  text: '+1 Karte. +2 Aktionen.',
                ),
              },
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final localized = container.read(localizedCardProvider(card));
    expect(localized.name, 'Dorf');
    expect(localized.text, '+1 Karte. +2 Aktionen.');
  });

  test('localizedCardProvider falls back to English when translation missing',
      () {
    final card = KingdomCard(
      id: 'smithy',
      name: 'Smithy',
      expansion: Expansion.baseSecondEdition,
      types: [CardType.action],
      tags: [],
      cost: 4,
      text: '+3 Cards.',
      metadata: const CardMetadata(),
    );

    final container = ProviderContainer(
      overrides: [
        activeTranslationPackProvider.overrideWith(
          (ref) => const AsyncValue.data(
            TranslationPack(languageCode: 'de', label: 'Deutsch'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final localized = container.read(localizedCardProvider(card));
    expect(localized.name, 'Smithy');
    expect(localized.text, '+3 Cards.');
  });
}
