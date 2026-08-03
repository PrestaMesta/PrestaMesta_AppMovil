import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/utils/jwt_utils.dart';

/// Builds a syntactically valid (unsigned) JWT for testing `isJwtExpired`,
/// which only ever reads the payload — it never checks the signature.
String _fakeJwt(Map<String, dynamic> payload, {Map<String, dynamic>? header}) {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final headerPart = encode(header ?? {'alg': 'HS256', 'typ': 'JWT'});
  final payloadPart = encode(payload);
  return '$headerPart.$payloadPart.fake-signature';
}

void main() {
  group('isJwtExpired', () {
    test('is false for a token whose exp is in the future', () {
      final now = DateTime.utc(2026, 8, 3, 12);
      final token = _fakeJwt({
        'sub': 1,
        'exp': now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      });
      expect(isJwtExpired(token, now: now), isFalse);
    });

    test('is true for a token whose exp is in the past', () {
      final now = DateTime.utc(2026, 8, 3, 12);
      final token = _fakeJwt({
        'sub': 1,
        'exp': now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      });
      expect(isJwtExpired(token, now: now), isTrue);
    });

    test('is true exactly at the expiry instant (not-after, not inclusive)',
        () {
      final now = DateTime.utc(2026, 8, 3, 12);
      final token =
          _fakeJwt({'sub': 1, 'exp': now.millisecondsSinceEpoch ~/ 1000});
      expect(isJwtExpired(token, now: now), isTrue);
    });

    test('is true for a malformed token (not three dot-separated segments)',
        () {
      expect(isJwtExpired('not-a-jwt'), isTrue);
      expect(isJwtExpired('only.two-parts'), isTrue);
    });

    test('is true for a token whose payload is not valid base64/JSON', () {
      expect(isJwtExpired('header.###not-base64###.signature'), isTrue);
    });

    test('is true for a token missing the exp claim', () {
      final token = _fakeJwt({'sub': 1});
      expect(isJwtExpired(token), isTrue);
    });

    test('is true when exp is present but not an int', () {
      final token = _fakeJwt({'sub': 1, 'exp': 'not-a-number'});
      expect(isJwtExpired(token), isTrue);
    });
  });
}
