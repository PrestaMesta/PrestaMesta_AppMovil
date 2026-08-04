import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/loan_list_item.dart';
import 'package:prestamesta_app/features/loans/data/loan_submission_response.dart';

Map<String, dynamic> _validItemJson({
  Object? id = 1,
  Object? credito = const {'id': 1, 'nombre': 'Crédito Personal Express'},
  Object? montoSolicitado = '10000.00',
  Object? montoTotalAPagar = '13000.00',
  Object? saldoPendiente = '13000.00',
  Object? estado = 'PENDIENTE',
  Object? fechaSolicitud = '2026-08-02T20:46:06.000Z',
  Object? fechaDecision,
}) {
  return {
    'id': id,
    'credito': credito,
    'monto_solicitado': montoSolicitado,
    'monto_total_a_pagar': montoTotalAPagar,
    'saldo_pendiente': saldoPendiente,
    'estado': estado,
    'fecha_solicitud': fechaSolicitud,
    'fecha_decision': fechaDecision,
  };
}

void main() {
  group('PrestamoListItem.fromJson', () {
    test('parses every field with the exact real shape', () {
      final item = PrestamoListItem.fromJson(_validItemJson());

      expect(item.id, 1);
      expect(item.credito.id, 1);
      expect(item.credito.nombre, 'Crédito Personal Express');
      expect(item.montoSolicitado, Decimal.parse('10000.00'));
      expect(item.montoTotalAPagar, Decimal.parse('13000.00'));
      expect(item.saldoPendiente, Decimal.parse('13000.00'));
      expect(item.estado, EstadoPrestamo.pendiente);
      expect(item.fechaSolicitud, DateTime.parse('2026-08-02T20:46:06.000Z'));
      expect(item.fechaDecision, isNull);
    });

    test('fecha_decision is parsed when present (an admin already decided)',
        () {
      final item = PrestamoListItem.fromJson(
          _validItemJson(fechaDecision: '2026-08-03T09:00:00.000Z'));

      expect(item.fechaDecision, DateTime.parse('2026-08-03T09:00:00.000Z'));
    });

    test('rejects monto_solicitado as a number (contract says string here)',
        () {
      expect(
        () => PrestamoListItem.fromJson(_validItemJson(montoSolicitado: 10000)),
        throwsFormatException,
      );
    });

    test('rejects an unrecognized estado', () {
      expect(
        () => PrestamoListItem.fromJson(_validItemJson(estado: 'ACTIVO')),
        throwsFormatException,
      );
    });

    test('rejects a missing credito object', () {
      expect(
        () => PrestamoListItem.fromJson(_validItemJson(credito: null)),
        throwsFormatException,
      );
    });

    test('rejects an invalid fecha_solicitud', () {
      expect(
        () => PrestamoListItem.fromJson(
            _validItemJson(fechaSolicitud: 'not-a-date')),
        throwsFormatException,
      );
    });
  });

  group('LoanListPage.fromJson', () {
    test('parses data and pagination together', () {
      final page = LoanListPage.fromJson({
        'data': [_validItemJson(), _validItemJson(id: 2)],
        'pagination': {'page': 1, 'limit': 20, 'total': 2, 'totalPages': 1},
      });

      expect(page.data, hasLength(2));
      expect(page.data.first.id, 1);
      expect(page.pagination.total, 2);
    });

    test('an empty data array parses to an empty list, not an error', () {
      final page = LoanListPage.fromJson({
        'data': <dynamic>[],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0},
      });

      expect(page.data, isEmpty);
    });

    test('rejects a response missing the pagination envelope', () {
      expect(
        () => LoanListPage.fromJson({'data': <dynamic>[]}),
        throwsFormatException,
      );
    });

    test('rejects a response where data is not a list', () {
      expect(
        () => LoanListPage.fromJson({
          'data': {'not': 'a list'},
          'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0},
        }),
        throwsFormatException,
      );
    });
  });
}
