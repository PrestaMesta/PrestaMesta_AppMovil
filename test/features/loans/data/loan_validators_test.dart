import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/loan_validators.dart';

void main() {
  group('isGuarantorNombreValid', () {
    test('rejects empty/whitespace-only', () {
      expect(isGuarantorNombreValid(''), isFalse);
      expect(isGuarantorNombreValid('   '), isFalse);
    });

    test('accepts a normal name', () {
      expect(isGuarantorNombreValid('Roberto Gómez'), isTrue);
    });

    test('accepts exactly 150 characters', () {
      expect(isGuarantorNombreValid('a' * 150), isTrue);
    });

    test('rejects more than 150 characters', () {
      expect(isGuarantorNombreValid('a' * 151), isFalse);
    });
  });

  group('isGuarantorTelefonoValid', () {
    test(
        'rejects empty — unlike the client\'s own phone, aval telefono is required',
        () {
      expect(isGuarantorTelefonoValid(''), isFalse);
      expect(isGuarantorTelefonoValid('   '), isFalse);
    });

    test('rejects fewer than 7 characters', () {
      expect(isGuarantorTelefonoValid('12345'), isFalse);
    });

    test('accepts a typical 10-digit phone number', () {
      expect(isGuarantorTelefonoValid('8711234567'), isTrue);
    });

    test('accepts exactly 20 characters', () {
      expect(isGuarantorTelefonoValid('1' * 20), isTrue);
    });

    test('rejects more than 20 characters', () {
      expect(isGuarantorTelefonoValid('1' * 21), isFalse);
    });
  });

  group('isGuarantorDireccionValid', () {
    test('empty is valid — direccion is optional', () {
      expect(isGuarantorDireccionValid(''), isTrue);
    });

    test('accepts exactly 255 characters', () {
      expect(isGuarantorDireccionValid('a' * 255), isTrue);
    });

    test('rejects more than 255 characters', () {
      expect(isGuarantorDireccionValid('a' * 256), isFalse);
    });
  });
}
