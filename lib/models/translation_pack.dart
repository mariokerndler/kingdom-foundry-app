import 'dart:convert';

class CardTranslation {
  final String name;
  final String text;

  const CardTranslation({
    required this.name,
    required this.text,
  });

  factory CardTranslation.fromJson(Map<String, dynamic> json) =>
      CardTranslation(
        name: json['name'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'text': text,
      };
}

class TranslationPack {
  final String languageCode;
  final String label;
  final int version;
  final Map<String, CardTranslation> cards;

  const TranslationPack({
    required this.languageCode,
    required this.label,
    this.version = 1,
    this.cards = const {},
  });

  factory TranslationPack.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as Map<String, dynamic>? ?? const {};
    return TranslationPack(
      languageCode: json['languageCode'] as String? ?? 'en',
      label: json['label'] as String? ?? 'English',
      version: json['version'] as int? ?? 1,
      cards: rawCards.map(
        (key, value) => MapEntry(
          key,
          CardTranslation.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  factory TranslationPack.fromJsonString(String raw) {
    return TranslationPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'label': label,
        'version': version,
        'cards': cards.map((key, value) => MapEntry(key, value.toJson())),
      };

  String toJsonString() => jsonEncode(toJson());

  CardTranslation? lookup(String cardId) => cards[cardId];
}
