import 'card_tag.dart';
import 'card_type.dart';

enum CardComplexity { low, medium, high }

enum SetupWeight { low, medium, high }

enum InteractionProfile { passive, interactive, attackHeavy }

enum EngineSupportLevel { low, medium, high }

enum PayloadProfile { support, economy, spike }

enum QualityLevel { none, low, medium, high }

enum GainSpeed { none, slow, medium, fast }

enum AltVpPressure { none, light, medium, heavy }

enum RerollAffinity { sticky, flexible, swingy }

extension _EnumJson on Enum {
  String get jsonName => name;
}

T _enumFromJson<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => fallback,
  );
}

class CardMetadata {
  final CardComplexity complexity;
  final SetupWeight setupWeight;
  final InteractionProfile interactionProfile;
  final EngineSupportLevel engineSupport;
  final PayloadProfile payloadProfile;
  final QualityLevel trashQuality;
  final QualityLevel drawQuality;
  final GainSpeed gainSpeed;
  final AltVpPressure altVpPressure;
  final RerollAffinity rerollAffinity;

  const CardMetadata({
    this.complexity = CardComplexity.medium,
    this.setupWeight = SetupWeight.medium,
    this.interactionProfile = InteractionProfile.interactive,
    this.engineSupport = EngineSupportLevel.medium,
    this.payloadProfile = PayloadProfile.support,
    this.trashQuality = QualityLevel.none,
    this.drawQuality = QualityLevel.none,
    this.gainSpeed = GainSpeed.none,
    this.altVpPressure = AltVpPressure.none,
    this.rerollAffinity = RerollAffinity.flexible,
  });

  factory CardMetadata.fromJson(Map<String, dynamic> json) => CardMetadata(
        complexity: _enumFromJson(
          CardComplexity.values,
          json['complexity'],
          CardComplexity.medium,
        ),
        setupWeight: _enumFromJson(
          SetupWeight.values,
          json['setupWeight'],
          SetupWeight.medium,
        ),
        interactionProfile: _enumFromJson(
          InteractionProfile.values,
          json['interactionProfile'],
          InteractionProfile.interactive,
        ),
        engineSupport: _enumFromJson(
          EngineSupportLevel.values,
          json['engineSupport'],
          EngineSupportLevel.medium,
        ),
        payloadProfile: _enumFromJson(
          PayloadProfile.values,
          json['payloadProfile'],
          PayloadProfile.support,
        ),
        trashQuality: _enumFromJson(
          QualityLevel.values,
          json['trashQuality'],
          QualityLevel.none,
        ),
        drawQuality: _enumFromJson(
          QualityLevel.values,
          json['drawQuality'],
          QualityLevel.none,
        ),
        gainSpeed: _enumFromJson(
          GainSpeed.values,
          json['gainSpeed'],
          GainSpeed.none,
        ),
        altVpPressure: _enumFromJson(
          AltVpPressure.values,
          json['altVpPressure'],
          AltVpPressure.none,
        ),
        rerollAffinity: _enumFromJson(
          RerollAffinity.values,
          json['rerollAffinity'],
          RerollAffinity.flexible,
        ),
      );

  factory CardMetadata.derived({
    required List<CardType> types,
    required List<CardTag> tags,
    bool potionCost = false,
    int? debtCost,
    bool isLandscape = false,
    bool isSplitPile = false,
    bool isTraveller = false,
  }) {
    final hasAttack =
        types.contains(CardType.attack) || tags.contains(CardTag.attack);
    final hasDuration =
        types.contains(CardType.duration) || tags.contains(CardTag.duration);
    final hasNight = types.contains(CardType.night);
    final hasDraw =
        tags.contains(CardTag.plusCard) || tags.contains(CardTag.drawToX);
    final hasVillage = tags.contains(CardTag.villageEffect) ||
        tags.contains(CardTag.plusTwoActions) ||
        tags.contains(CardTag.plusAction);
    final hasTrash = tags.contains(CardTag.trashCards) ||
        tags.contains(CardTag.trashForBenefit) ||
        tags.contains(CardTag.remodel);
    final hasGain = tags.contains(CardTag.gainCard) ||
        tags.contains(CardTag.gainCheaply) ||
        tags.contains(CardTag.gainTreasure) ||
        tags.contains(CardTag.goldGain) ||
        tags.contains(CardTag.silverGain);
    final hasAltVp = tags.contains(CardTag.altVictory) ||
        tags.contains(CardTag.pointTokens) ||
        tags.contains(CardTag.gainVictory);
    final setupScore = [
      if (isLandscape) 1,
      if (isSplitPile) 1,
      if (isTraveller) 1,
      if (hasDuration) 1,
      if (hasNight) 1,
      if (potionCost) 1,
      if (debtCost != null) 1,
      if (tags.contains(CardTag.tokens) ||
          tags.contains(CardTag.villagers) ||
          tags.contains(CardTag.coffers) ||
          tags.contains(CardTag.exile))
        1,
    ].length;

    final complexity = setupScore >= 3 || (hasAttack && hasDraw)
        ? CardComplexity.high
        : (setupScore >= 1 || hasAttack || hasTrash)
            ? CardComplexity.medium
            : CardComplexity.low;

    final setupWeight = setupScore >= 3
        ? SetupWeight.high
        : setupScore >= 1
            ? SetupWeight.medium
            : SetupWeight.low;

    final interaction = hasAttack
        ? (tags.contains(CardTag.curse) ||
                tags.contains(CardTag.junking) ||
                tags.contains(CardTag.discard))
            ? InteractionProfile.attackHeavy
            : InteractionProfile.interactive
        : InteractionProfile.passive;

    final engineSupport = hasVillage || hasDraw
        ? (hasVillage && hasDraw
            ? EngineSupportLevel.high
            : EngineSupportLevel.medium)
        : EngineSupportLevel.low;

    final payloadProfile = hasAltVp
        ? PayloadProfile.spike
        : (tags.contains(CardTag.plusCoin) ||
                tags.contains(CardTag.gainTreasure) ||
                tags.contains(CardTag.goldGain))
            ? PayloadProfile.economy
            : PayloadProfile.support;

    final trashQuality = hasTrash
        ? tags.contains(CardTag.trashForBenefit)
            ? QualityLevel.high
            : tags.contains(CardTag.remodel)
                ? QualityLevel.medium
                : QualityLevel.low
        : QualityLevel.none;

    final drawQuality = hasDraw
        ? (tags.contains(CardTag.drawToX) || tags.contains(CardTag.plusCard))
            ? (hasVillage ? QualityLevel.high : QualityLevel.medium)
            : QualityLevel.low
        : QualityLevel.none;

    final gainSpeed = hasGain
        ? (tags.contains(CardTag.gainCheaply) ||
                tags.contains(CardTag.goldGain))
            ? GainSpeed.fast
            : GainSpeed.medium
        : GainSpeed.none;

    final altVpPressure = hasAltVp
        ? tags.contains(CardTag.altVictory)
            ? AltVpPressure.heavy
            : AltVpPressure.medium
        : AltVpPressure.none;

    final rerollAffinity = hasAttack || hasAltVp
        ? RerollAffinity.swingy
        : (hasVillage || hasDraw || hasTrash)
            ? RerollAffinity.sticky
            : RerollAffinity.flexible;

    return CardMetadata(
      complexity: complexity,
      setupWeight: setupWeight,
      interactionProfile: interaction,
      engineSupport: engineSupport,
      payloadProfile: payloadProfile,
      trashQuality: trashQuality,
      drawQuality: drawQuality,
      gainSpeed: gainSpeed,
      altVpPressure: altVpPressure,
      rerollAffinity: rerollAffinity,
    );
  }

  Map<String, dynamic> toJson() => {
        'complexity': complexity.jsonName,
        'setupWeight': setupWeight.jsonName,
        'interactionProfile': interactionProfile.jsonName,
        'engineSupport': engineSupport.jsonName,
        'payloadProfile': payloadProfile.jsonName,
        'trashQuality': trashQuality.jsonName,
        'drawQuality': drawQuality.jsonName,
        'gainSpeed': gainSpeed.jsonName,
        'altVpPressure': altVpPressure.jsonName,
        'rerollAffinity': rerollAffinity.jsonName,
      };
}
