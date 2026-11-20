enum TableSetupChoice {
  undecided('Decide at table'),
  include('Use'),
  exclude('Do not use');

  final String label;
  const TableSetupChoice(this.label);

  static TableSetupChoice fromJson(Object? value) {
    if (value == null) return undecided;
    for (final choice in values) {
      if (choice.name == value) return choice;
    }
    throw FormatException('Invalid table setup choice: $value');
  }
}
