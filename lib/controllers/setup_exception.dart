/// Typed failure reasons so the UI can display targeted messages.
enum SetupFailureReason {
  /// After all filters are applied, fewer than 10 cards remain.
  poolTooSmall,

  /// A "require X" rule cannot be satisfied because the pool has zero
  /// matching cards (e.g., requireVillage but no Village cards exist after
  /// filtering).
  requirementImpossible,

  /// The minExpansionVariety constraint cannot be met with the chosen
  /// expansions.
  varietyImpossible,
}

/// Thrown by [SetupEngine.generate] when a valid kingdom cannot be produced.
class SetupException implements Exception {
  final String message;
  final SetupFailureReason reason;

  const SetupException(this.message, this.reason);

  @override
  String toString() => 'SetupException(${reason.name}): $message';
}
