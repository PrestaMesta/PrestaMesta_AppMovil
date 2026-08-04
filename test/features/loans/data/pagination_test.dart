import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/pagination.dart';

void main() {
  group('Pagination.fromJson', () {
    test('parses every field', () {
      final pagination = Pagination.fromJson(
          {'page': 2, 'limit': 20, 'total': 45, 'totalPages': 3});

      expect(pagination.page, 2);
      expect(pagination.limit, 20);
      expect(pagination.total, 45);
      expect(pagination.totalPages, 3);
    });

    test('totalPages is 0 exactly when total is 0', () {
      final pagination = Pagination.fromJson(
          {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0});

      expect(pagination.totalPages, 0);
    });

    test('rejects a missing field', () {
      expect(
        () => Pagination.fromJson({'page': 1, 'limit': 20, 'total': 0}),
        throwsFormatException,
      );
    });

    test('rejects a field with the wrong type', () {
      expect(
        () => Pagination.fromJson(
            {'page': '1', 'limit': 20, 'total': 0, 'totalPages': 0}),
        throwsFormatException,
      );
    });
  });
}
