import 'dart:convert';
import 'dart:io';

import 'package:kingdom_foundry/models/expansion.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';

void main(List<String> args) {
  final catalogue =
      jsonDecode(File('assets/data/cards.json').readAsStringSync());
  final cards = (catalogue as List)
      .map((value) => KingdomCard.fromJson(value as Map<String, dynamic>))
      .toList();
  const start = '<!-- catalogue:start -->';
  const end = '<!-- catalogue:end -->';
  final summary = StringBuffer('$start\n')
    ..writeln('${cards.length} records across '
        '${cards.map((card) => card.expansion).toSet().length} expansion and edition groups.')
    ..writeln()
    ..writeln(
        '| Expansion | Kingdom piles | First-edition-only piles | Landscapes | Auxiliary records | Total records |')
    ..writeln('| --- | ---: | ---: | ---: | ---: | ---: |');

  final expansions = cards.map((card) => card.expansion).toSet().toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
  for (final expansion in expansions) {
    final group = cards.where((card) => card.expansion == expansion).toList();
    final kingdom = group
        .where((card) => card.isKingdomCard && !card.firstEditionOnly)
        .map((card) => card.pileId)
        .toSet();
    final retired = group
        .where((card) => card.isKingdomCard && card.firstEditionOnly)
        .map((card) => card.pileId)
        .toSet();
    final landscapes = group.where((card) => card.isLandscape);
    final auxiliary = group.where((card) => card.isAuxiliary);
    summary.writeln('| ${expansion.displayName} | ${kingdom.length} | '
        '${retired.length} | ${landscapes.length} | ${auxiliary.length} | ${group.length} |');
  }
  summary.write(end);

  final readme = File('README.md');
  final current = readme.readAsStringSync().replaceAll('\r\n', '\n');
  final range = RegExp('$start[\\s\\S]*?$end');
  if (!range.hasMatch(current)) {
    throw StateError('Missing catalogue markers in README.md.');
  }
  final updated = current.replaceFirst(range, summary.toString());
  if (current == updated) return;
  if (args.contains('--check')) {
    stderr.writeln(
        'Catalogue summary is stale. Run dart run tool/catalogue_summary.dart.');
    exitCode = 1;
  } else {
    readme.writeAsStringSync(updated);
  }
}
