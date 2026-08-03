import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/loan_submission_response.dart';

Map<String, dynamic> _validJson({
  Object? mensaje = 'Solicitud de préstamo enviada con éxito',
  Object? prestamoId = 1,
  Object? fechaSolicitud = '2026-08-02T20:46:06.000Z',
  Object? montoSolicitado = 10000,
  Object? montoTotalAPagar = '12400.00',
  Object? estado = 'PENDIENTE',
}) {
  return {
    'mensaje': mensaje,
    'prestamoId': prestamoId,
    'fechaSolicitud': fechaSolicitud,
    'montoSolicitado': montoSolicitado,
    'montoTotalAPagar': montoTotalAPagar,
    'estado': estado,
  };
}

void main() {
  group('LoanSubmissionResponse.fromJson', () {
    test('parses every field with the exact real shape', () {
      final response = LoanSubmissionResponse.fromJson(_validJson());

      expect(response.mensaje, 'Solicitud de préstamo enviada con éxito');
      expect(response.prestamoId, 1);
      expect(
          response.fechaSolicitud, DateTime.parse('2026-08-02T20:46:06.000Z'));
      expect(response.montoSolicitado, Decimal.parse('10000'));
      expect(response.montoTotalAPagar, Decimal.parse('12400.00'));
      expect(response.estado, EstadoPrestamo.pendiente);
    });

    test(
        'montoSolicitado is accepted as a JSON number (int), per openapi type: number',
        () {
      final response =
          LoanSubmissionResponse.fromJson(_validJson(montoSolicitado: 10000));
      expect(response.montoSolicitado, Decimal.parse('10000'));
    });

    test('montoSolicitado is accepted as a JSON number (double) too', () {
      final response =
          LoanSubmissionResponse.fromJson(_validJson(montoSolicitado: 10000.5));
      expect(response.montoSolicitado, Decimal.parse('10000.5'));
    });

    test(
        'rejects montoSolicitado as a string (contract says number, not string)',
        () {
      expect(
        () => LoanSubmissionResponse.fromJson(
            _validJson(montoSolicitado: '10000')),
        throwsFormatException,
      );
    });

    test(
        'rejects montoTotalAPagar as a number (contract says string, not number)',
        () {
      expect(
        () => LoanSubmissionResponse.fromJson(
            _validJson(montoTotalAPagar: 12400.0)),
        throwsFormatException,
      );
    });

    test('rejects an invalid decimal string for montoTotalAPagar', () {
      expect(
        () => LoanSubmissionResponse.fromJson(
            _validJson(montoTotalAPagar: 'not-a-decimal')),
        throwsFormatException,
      );
    });

    test('rejects a missing field entirely (prestamoId)', () {
      final json = _validJson()..remove('prestamoId');
      expect(
          () => LoanSubmissionResponse.fromJson(json), throwsFormatException);
    });

    test('rejects a missing field entirely (montoTotalAPagar)', () {
      final json = _validJson()..remove('montoTotalAPagar');
      expect(
          () => LoanSubmissionResponse.fromJson(json), throwsFormatException);
    });

    test(
        'rejects an invalid fechaSolicitud instead of substituting DateTime.now()',
        () {
      expect(
        () => LoanSubmissionResponse.fromJson(
            _validJson(fechaSolicitud: 'not-a-date')),
        throwsFormatException,
      );
    });

    test('rejects an unknown estado rather than accepting it silently', () {
      expect(
        () => LoanSubmissionResponse.fromJson(_validJson(estado: 'ACTIVO')),
        throwsFormatException,
      );
    });

    test(
        'parses APROBADO and RECHAZADO too (even though this endpoint only ever returns PENDIENTE)',
        () {
      expect(
        LoanSubmissionResponse.fromJson(_validJson(estado: 'APROBADO')).estado,
        EstadoPrestamo.aprobado,
      );
      expect(
        LoanSubmissionResponse.fromJson(_validJson(estado: 'RECHAZADO')).estado,
        EstadoPrestamo.rechazado,
      );
    });

    test(
        'defaults mensaje to empty string if missing (cosmetic field, same policy as auth models)',
        () {
      final json = _validJson()..remove('mensaje');
      final response = LoanSubmissionResponse.fromJson(json);
      expect(response.mensaje, '');
    });

    test(
        'rejects a response shaped as a wrapper object instead of the flat fields',
        () {
      expect(
        () => LoanSubmissionResponse.fromJson({'prestamo': _validJson()}),
        throwsFormatException,
      );
    });
  });
}
