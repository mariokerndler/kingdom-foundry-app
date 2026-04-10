import 'package:flutter_test/flutter_test.dart';

import 'package:kingdom_foundry/providers/generation_provider.dart';

void main() {
  group('parseKingdomText', () {
    const validInput = '''
1. Village (\$3)
2. Smithy (\$4)
3. Chapel (\$2)
4. Witch (\$5)
5. Market (\$5)
6. Laboratory (\$5)
7. Cellar (\$2)
8. Moat (\$2)
9. Militia (\$4)
10. Festival (\$5)
''';

    test('parses all 10 cards from valid clipboard text', () {
      final names = parseKingdomText(validInput);
      expect(names, hasLength(10));
    });

    test('extracts correct card names', () {
      final names = parseKingdomText(validInput);
      expect(names, containsAll([
        'Village', 'Smithy', 'Chapel', 'Witch', 'Market',
        'Laboratory', 'Cellar', 'Moat', 'Militia', 'Festival',
      ]));
    });

    test('preserves order', () {
      final names = parseKingdomText(validInput);
      expect(names.first, equals('Village'));
      expect(names.last,  equals('Festival'));
    });

    test('handles Windows-style CRLF line endings', () {
      final crlf = validInput.replaceAll('\n', '\r\n');
      expect(parseKingdomText(crlf), hasLength(10));
    });

    test('ignores blank lines', () {
      const withBlanks = '\n\n$validInput\n\n';
      expect(parseKingdomText(withBlanks), hasLength(10));
    });

    test('ignores unrecognised lines (e.g. a header or message text)', () {
      const withHeader = 'Here is our kingdom:\n$validInput\nHave fun!';
      expect(parseKingdomText(withHeader), hasLength(10));
    });

    test('returns empty list for empty string', () {
      expect(parseKingdomText(''), isEmpty);
    });

    test('returns empty list for completely unrelated text', () {
      expect(parseKingdomText('hello world\nno cards here'), isEmpty);
    });

    test('handles multi-word card names', () {
      const text = '1. Merchant Ship (\$5)\n'
          '2. Council Room (\$5)\n'
          '3. Treasure Map (\$4)\n'
          '4. Scrying Pool (\$2P)\n'
          '5. Great Hall (\$3)\n'
          '6. Wishing Well (\$3)\n'
          '7. Throne Room (\$4)\n'
          '8. Secret Chamber (\$2)\n'
          '9. Mining Village (\$4)\n'
          '10. Trading Post (\$5)\n';
      final names = parseKingdomText(text);
      expect(names, hasLength(10));
      expect(names, contains('Merchant Ship'));
      expect(names, contains('Council Room'));
      expect(names, contains('Scrying Pool')); // potion cost
    });

    test('handles potion-cost format (e.g. \$2P)', () {
      const text = '1. Alchemist (\$3P)\n'
          '2. Familiar (\$3P)\n'
          '3. Vineyard (\$0P)\n'
          '4. Village (\$3)\n'
          '5. Smithy (\$4)\n'
          '6. Chapel (\$2)\n'
          '7. Witch (\$5)\n'
          '8. Market (\$5)\n'
          '9. Cellar (\$2)\n'
          '10. Moat (\$2)\n';
      expect(parseKingdomText(text), hasLength(10));
    });

    test('handles debt-cost format (e.g. \$0+8D)', () {
      const text = '1. Engineer (\$0+4D)\n'
          '2. City Quarter (\$0+8D)\n'
          '3. Village (\$3)\n'
          '4. Smithy (\$4)\n'
          '5. Chapel (\$2)\n'
          '6. Witch (\$5)\n'
          '7. Market (\$5)\n'
          '8. Cellar (\$2)\n'
          '9. Moat (\$2)\n'
          '10. Festival (\$5)\n';
      expect(parseKingdomText(text), hasLength(10));
      expect(parseKingdomText(text), contains('Engineer'));
    });

    test('partial list returns fewer than 10 names', () {
      const partial = '1. Village (\$3)\n2. Smithy (\$4)\n3. Chapel (\$2)\n';
      expect(parseKingdomText(partial), hasLength(3));
    });

    test('duplicate card names are preserved as-is', () {
      // The parser shouldn't de-duplicate — that's the importer's job.
      const text = '1. Village (\$3)\n'
          '2. Village (\$3)\n'
          '3. Smithy (\$4)\n'
          '4. Chapel (\$2)\n'
          '5. Witch (\$5)\n'
          '6. Market (\$5)\n'
          '7. Laboratory (\$5)\n'
          '8. Cellar (\$2)\n'
          '9. Moat (\$2)\n'
          '10. Militia (\$4)\n';
      final names = parseKingdomText(text);
      expect(names, hasLength(10));
      expect(names.where((n) => n == 'Village').length, equals(2));
    });

    test('leading/trailing whitespace on lines is handled gracefully', () {
      const text = '  1. Village (\$3)  \n'
          '  2. Smithy (\$4)  \n'
          '3. Chapel (\$2)\n'
          '4. Witch (\$5)\n'
          '5. Market (\$5)\n'
          '6. Laboratory (\$5)\n'
          '7. Cellar (\$2)\n'
          '8. Moat (\$2)\n'
          '9. Militia (\$4)\n'
          '10. Festival (\$5)\n';
      expect(parseKingdomText(text), hasLength(10));
    });
  });
}
