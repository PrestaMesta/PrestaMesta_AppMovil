import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/credits/data/credit_model.dart';

Map<String, dynamic> _validJson({
  Object? id = 1,
  Object? nombre = 'Crédito Personal Express',
  Object? montoMinimo = '1000.00',
  Object? montoMaximo = '20000.00',
  Object? tasa = '24.00',
  Object? plazoMeses = 12,
  Object? creadoEn = '2026-08-02T02:43:54.000Z',
}) {
  return {
    'id': id,
    'nombre': nombre,
    'monto_minimo': montoMinimo,
    'monto_maximo': montoMaximo,
    'tasa_interes_anual': tasa,
    'plazo_meses': plazoMeses,
    'creado_en': creadoEn,
  };
}

void main() {
  group('Credito.fromJson', () {
    test('parses every field with the exact real shape', () {
      final credito = Credito.fromJson(_validJson());

      expect(credito.id, 1);
      expect(credito.nombre, 'Crédito Personal Express');
      expect(credito.montoMinimo, Decimal.parse('1000.00'));
      expect(credito.montoMaximo, Decimal.parse('20000.00'));
      expect(credito.tasaInteresAnual, Decimal.parse('24.00'));
      expect(credito.plazoMeses, 12);
      expect(credito.creadoEn, DateTime.parse('2026-08-02T02:43:54.000Z'));
    });

    test('rejects when id is a string instead of a number', () {
      expect(
          () => Credito.fromJson(_validJson(id: '1')), throwsFormatException);
    });

    test('rejects when monto_minimo is a number instead of a decimal string',
        () {
      // mysql2 returns DECIMAL columns as strings; a raw number here would
      // mean the contract changed underneath us — must not be silently
      // coerced.
      expect(() => Credito.fromJson(_validJson(montoMinimo: 1000.0)),
          throwsFormatException);
    });

    test('rejects an invalid decimal string for monto_maximo', () {
      expect(() => Credito.fromJson(_validJson(montoMaximo: 'not-a-decimal')),
          throwsFormatException);
    });

    test(
        'preserves extra decimal precision exactly rather than silently truncating it',
        () {
      // Not a validation rule we invent — just confirms Decimal.parse itself
      // never truncates or rounds a value it wasn't asked to.
      final credito = Credito.fromJson(_validJson(montoMinimo: '1000.999'));
      expect(credito.montoMinimo, Decimal.parse('1000.999'));
    });

    test('rejects plazo_meses as a string', () {
      expect(() => Credito.fromJson(_validJson(plazoMeses: '12')),
          throwsFormatException);
    });

    test('rejects a missing field entirely', () {
      final json = _validJson()..remove('tasa_interes_anual');
      expect(() => Credito.fromJson(json), throwsFormatException);
    });

    test('rejects an invalid creado_en date string', () {
      expect(() => Credito.fromJson(_validJson(creadoEn: 'not-a-date')),
          throwsFormatException);
    });

    test(
        'rejects a response shaped like a wrapper object instead of the raw fields',
        () {
      // e.g. a hypothetical `{ credito: {...} }` envelope — this endpoint's
      // contract is a flat object, not a nested one.
      expect(
        () => Credito.fromJson({
          'credito': _validJson(),
        }),
        throwsFormatException,
      );
    });
  });
}
