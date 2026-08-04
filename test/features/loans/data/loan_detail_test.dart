import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/loan_detail.dart';

Map<String, dynamic> _validDetailJson({Object? aval}) => {
      'id': 1,
      'credito': {'id': 1, 'nombre': 'Crédito Personal Express'},
      'monto_solicitado': '10000.00',
      'monto_total_a_pagar': '13000.00',
      'saldo_pendiente': '13000.00',
      'estado': 'PENDIENTE',
      'fecha_solicitud': '2026-08-02T20:46:06.000Z',
      'fecha_decision': null,
      'aval': aval,
    };

void main() {
  group('PrestamoDetalle.fromJson', () {
    test('parses the underlying loan fields via the shared list-item parser',
        () {
      final detail = PrestamoDetalle.fromJson(_validDetailJson());

      expect(detail.id, 1);
      expect(detail.credito.nombre, 'Crédito Personal Express');
      expect(detail.montoSolicitado, Decimal.parse('10000.00'));
      expect(detail.montoTotalAPagar, Decimal.parse('13000.00'));
      expect(detail.saldoPendiente, Decimal.parse('13000.00'));
    });

    test('a null aval means no guarantor on record', () {
      final detail = PrestamoDetalle.fromJson(_validDetailJson(aval: null));

      expect(detail.aval, isNull);
    });

    test('a present aval is parsed in full', () {
      final detail = PrestamoDetalle.fromJson(_validDetailJson(aval: {
        'id': 5,
        'nombre': 'Roberto Gómez',
        'telefono': '8711234567',
        'direccion': 'Av. Morelos #450, Centro',
        'ingreso_mensual': '15000.00',
      }));

      expect(detail.aval, isNotNull);
      expect(detail.aval!.nombre, 'Roberto Gómez');
      expect(detail.aval!.direccion, 'Av. Morelos #450, Centro');
      expect(detail.aval!.ingresoMensual, Decimal.parse('15000.00'));
    });

    test('an aval with absent optional fields keeps them null, not empty', () {
      final detail = PrestamoDetalle.fromJson(_validDetailJson(aval: {
        'id': 5,
        'nombre': 'Roberto Gómez',
        'telefono': '8711234567',
        'direccion': null,
        'ingreso_mensual': null,
      }));

      expect(detail.aval!.direccion, isNull);
      expect(detail.aval!.ingresoMensual, isNull);
    });

    test('rejects a malformed aval (not an object)', () {
      expect(
        () => PrestamoDetalle.fromJson(_validDetailJson(aval: 'not-an-object')),
        throwsFormatException,
      );
    });
  });
}
