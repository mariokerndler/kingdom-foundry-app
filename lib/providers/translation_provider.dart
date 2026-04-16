import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kingdom_card.dart';
import '../models/translation_pack.dart';
import '../services/translation_service.dart';
import 'config_provider.dart';

final translationServiceProvider = Provider<TranslationService>(
  (ref) => TranslationService(ref.watch(sharedPreferencesProvider)),
);

final translationPacksProvider = FutureProvider<List<TranslationPack>>((ref) {
  return ref.watch(translationServiceProvider).loadAvailablePacks();
});

final activeTranslationPackProvider =
    Provider<AsyncValue<TranslationPack?>>((ref) {
  final code = ref.watch(configProvider).selectedLanguageCode;
  return ref.watch(translationPacksProvider).whenData(
        (packs) => packs.firstWhere(
          (pack) => pack.languageCode == code,
          orElse: () => const TranslationPack(
            languageCode: 'en',
            label: 'English',
          ),
        ),
      );
});

class LocalizedCardView {
  final String name;
  final String text;

  const LocalizedCardView({
    required this.name,
    required this.text,
  });
}

final localizedCardProvider =
    Provider.family<LocalizedCardView, KingdomCard>((ref, card) {
  final pack = ref.watch(activeTranslationPackProvider).valueOrNull;
  final translation = pack?.lookup(card.id);
  return LocalizedCardView(
    name:
        (translation?.name.isNotEmpty ?? false) ? translation!.name : card.name,
    text:
        (translation?.text.isNotEmpty ?? false) ? translation!.text : card.text,
  );
});
