import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/credits/data/amount_input_parser.dart';

void main() {
  group('parseUserAmount', () {
    test('accepts a plain integer', () {
      expect(parseUserAmount('1000'), Decimal.parse('1000'));
    });

    test('accepts a dot as the decimal separator', () {
      expect(parseUserAmount('1000.50'), Decimal.parse('1000.50'));
    });

    test('accepts a comma as the decimal separator', () {
      expect(parseUserAmount('1000,50'), Decimal.parse('1000.50'));
    });

    test('accepts exactly one decimal digit', () {
      expect(parseUserAmount('1000.5'), Decimal.parse('1000.5'));
    });

    test('accepts zero', () {
      expect(parseUserAmount('0'), Decimal.zero);
    });

    test('rejects more than two decimal digits', () {
      expect(parseUserAmount('1000.555'), isNull);
    });

    test('rejects a negative sign', () {
      expect(parseUserAmount('-1000'), isNull);
    });

    test('rejects scientific notation', () {
      expect(parseUserAmount('1e10'), isNull);
      expect(parseUserAmount('1E3'), isNull);
    });

    test('rejects non-numeric text', () {
      expect(parseUserAmount('abc'), isNull);
      expect(parseUserAmount('NaN'), isNull);
      expect(parseUserAmount('Infinity'), isNull);
    });

    test('rejects empty input', () {
      expect(parseUserAmount(''), isNull);
      expect(parseUserAmount('   '), isNull);
    });

    test(
        'rejects an ambiguous input mixing both separators (thousands + decimal)',
        () {
      expect(parseUserAmount('1,234.56'), isNull);
      expect(parseUserAmount('1.234,56'), isNull);
    });

    test('rejects a value with two decimal points', () {
      expect(parseUserAmount('10.20.30'), isNull);
    });

    test('rejects embedded whitespace', () {
      expect(parseUserAmount('10 000'), isNull);
    });

    test('trims surrounding whitespace before validating', () {
      expect(parseUserAmount('  1000.50  '), Decimal.parse('1000.50'));
    });
  });
}
