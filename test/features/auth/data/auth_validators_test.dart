import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/auth/data/auth_validators.dart';

void main() {
  group('passwordProblems / isPasswordValid', () {
    test('empty password is invalid', () {
      expect(isPasswordValid(''), isFalse);
    });

    test('rejects a password shorter than 12 characters', () {
      expect(passwordProblems('Abc123'), isNotEmpty);
    });

    test('rejects a password missing an uppercase letter', () {
      expect(isPasswordValid('minusculas123'), isFalse);
    });

    test('rejects a password missing a lowercase letter', () {
      expect(isPasswordValid('MAYUSCULAS123'), isFalse);
    });

    test('rejects a password missing a digit', () {
      expect(isPasswordValid('SoloLetrasAqui'), isFalse);
    });

    test('accepts a password meeting every rule', () {
      expect(isPasswordValid('ClaveSegura123'), isTrue);
    });

    test(
        'rejects by UTF-8 byte length, not character count (multibyte accents)',
        () {
      // 72 'á' characters are 72 chars but 144 bytes in UTF-8 — must be
      // rejected even though `.length` alone would look fine at plain ASCII.
      final longAccented = 'áB1${'á' * 70}';
      expect(passwordProblems(longAccented), contains(contains('72 bytes')));
    });

    test('accepts a password exactly at the 72-byte ASCII boundary', () {
      final exactly72 = 'Aa1${'b' * 69}'; // 72 ASCII chars = 72 bytes
      expect(exactly72.length, 72);
      expect(isPasswordValid(exactly72), isTrue);
    });

    test('rejects a password one byte over the limit', () {
      final over72 = 'Aa1${'b' * 70}'; // 73 ASCII chars = 73 bytes
      expect(isPasswordValid(over72), isFalse);
    });
  });

  group('isEmailFormatValid', () {
    test('accepts a well-formed email', () {
      expect(isEmailFormatValid('juan@example.com'), isTrue);
    });

    test(
        'accepts an email with surrounding whitespace (trimmed before checking)',
        () {
      expect(isEmailFormatValid('  juan@example.com  '), isTrue);
    });

    test('rejects missing @', () {
      expect(isEmailFormatValid('juanexample.com'), isFalse);
    });

    test('rejects missing domain dot', () {
      expect(isEmailFormatValid('juan@examplecom'), isFalse);
    });

    test('rejects empty string', () {
      expect(isEmailFormatValid(''), isFalse);
    });

    test('rejects an email over 190 characters (server maxLength)', () {
      final tooLong = '${'a' * 185}@example.com';
      expect(isEmailFormatValid(tooLong), isFalse);
    });
  });

  group('isNombreValid', () {
    test('rejects empty/whitespace-only', () {
      expect(isNombreValid(''), isFalse);
      expect(isNombreValid('   '), isFalse);
    });

    test('accepts a normal name', () {
      expect(isNombreValid('Juan Pérez'), isTrue);
    });

    test('rejects a name over 150 characters', () {
      expect(isNombreValid('a' * 151), isFalse);
    });

    test('accepts exactly 150 characters', () {
      expect(isNombreValid('a' * 150), isTrue);
    });
  });

  group('isTelefonoValid', () {
    test('empty is valid — telefono is optional', () {
      expect(isTelefonoValid(''), isTrue);
      expect(isTelefonoValid('   '), isTrue);
    });

    test('rejects fewer than 7 characters when provided', () {
      expect(isTelefonoValid('12345'), isFalse);
    });

    test('accepts a typical 10-digit phone number', () {
      expect(isTelefonoValid('8711234567'), isTrue);
    });

    test('rejects more than 20 characters', () {
      expect(isTelefonoValid('1' * 21), isFalse);
    });
  });
}
