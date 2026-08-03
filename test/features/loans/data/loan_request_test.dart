import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/guarantor.dart';
import 'package:prestamesta_app/features/loans/data/loan_request.dart';

/// Fields the server's `.strict()` Zod validator rejects outright if
/// present (`solicitarPrestamoSchema`/`avalSchema` in
/// `validators/prestamoValidators.js`) — this test file exists specifically
/// to prove none of them are ever serialized.
const _forbiddenKeys = {
  'cliente_id',
  'administrador_id',
  'monto_total_a_pagar',
  'saldo_pendiente',
  'estado',
  'fecha_solicitud',
  'tasa_interes_anual',
  'plazo_meses',
};

void main() {
  group('LoanRequest.toJson without aval', () {
    test('contains exactly credito_id and monto_solicitado', () {
      final request =
          LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000'));
      expect(request.toJson().keys.toSet(), {'credito_id', 'monto_solicitado'});
    });

    test('omits the aval key entirely — never null, never {}', () {
      final request =
          LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000'));
      final json = request.toJson();
      expect(json.containsKey('aval'), isFalse);
    });

    test('never contains a forbidden field', () {
      final request =
          LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000'));
      final keys = request.toJson().keys.toSet();
      expect(keys.intersection(_forbiddenKeys), isEmpty);
    });
  });

  group('LoanRequest.toJson with aval', () {
    test('contains exactly credito_id, monto_solicitado, aval', () {
      final request = LoanRequest(
        creditoId: 1,
        montoSolicitado: Decimal.parse('10000'),
        aval: const Guarantor(nombre: 'Roberto Gómez', telefono: '8711234567'),
      );
      expect(request.toJson().keys.toSet(),
          {'credito_id', 'monto_solicitado', 'aval'});
    });

    test('aval contains only nombre/telefono when direccion/ingreso are absent',
        () {
      final request = LoanRequest(
        creditoId: 1,
        montoSolicitado: Decimal.parse('10000'),
        aval: const Guarantor(nombre: 'Roberto Gómez', telefono: '8711234567'),
      );
      final aval = request.toJson()['aval'] as Map<String, dynamic>;
      expect(aval.keys.toSet(), {'nombre', 'telefono'});
    });

    test('aval includes direccion/ingreso_mensual only when provided', () {
      final request = LoanRequest(
        creditoId: 1,
        montoSolicitado: Decimal.parse('10000'),
        aval: Guarantor(
          nombre: 'Roberto Gómez',
          telefono: '8711234567',
          direccion: 'Av. Morelos #450, Centro',
          ingresoMensual: Decimal.parse('15000'),
        ),
      );
      final aval = request.toJson()['aval'] as Map<String, dynamic>;
      expect(aval.keys.toSet(),
          {'nombre', 'telefono', 'direccion', 'ingreso_mensual'});
    });

    test('never contains a forbidden field even with aval present', () {
      final request = LoanRequest(
        creditoId: 1,
        montoSolicitado: Decimal.parse('10000'),
        aval: const Guarantor(nombre: 'Roberto Gómez', telefono: '8711234567'),
      );
      final keys = request.toJson().keys.toSet();
      final avalKeys =
          (request.toJson()['aval'] as Map<String, dynamic>).keys.toSet();
      expect(keys.intersection(_forbiddenKeys), isEmpty);
      expect(avalKeys.intersection(_forbiddenKeys), isEmpty);
    });
  });

  group('monetary serialization', () {
    test('credito_id is a JSON integer', () {
      final request =
          LoanRequest(creditoId: 7, montoSolicitado: Decimal.parse('1000'));
      final encoded = jsonEncode(request.toJson());
      expect(jsonDecode(encoded)['credito_id'], 7);
    });

    test('monto_solicitado round-trips exactly through JSON for typical values',
        () {
      for (final v in ['0.01', '1.01', '1000', '10000.50', '1234.56']) {
        final request =
            LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse(v));
        final encoded = jsonEncode(request.toJson());
        final decoded = jsonDecode(encoded)['monto_solicitado'] as num;
        expect(Decimal.parse(decoded.toString()), Decimal.parse(v),
            reason: 'input $v');
      }
    });

    test('monto_solicitado round-trips exactly at the DECIMAL(12,2) maximum',
        () {
      final request = LoanRequest(
          creditoId: 1, montoSolicitado: Decimal.parse('9999999999.99'));
      final encoded = jsonEncode(request.toJson());
      final decoded = jsonDecode(encoded)['monto_solicitado'] as num;
      expect(Decimal.parse(decoded.toString()), Decimal.parse('9999999999.99'));
    });

    test('never produces scientific notation in the encoded JSON', () {
      final request = LoanRequest(
          creditoId: 1, montoSolicitado: Decimal.parse('9999999999.99'));
      final encoded = jsonEncode(request.toJson());
      expect(encoded, isNot(contains('e+')));
      expect(encoded, isNot(contains('E+')));
    });

    test('ingreso_mensual round-trips exactly too', () {
      final request = LoanRequest(
        creditoId: 1,
        montoSolicitado: Decimal.parse('1000'),
        aval: Guarantor(
            nombre: 'x',
            telefono: '1234567',
            ingresoMensual: Decimal.parse('15000.75')),
      );
      final encoded = jsonEncode(request.toJson());
      final decoded = jsonDecode(encoded)['aval']['ingreso_mensual'] as num;
      expect(Decimal.parse(decoded.toString()), Decimal.parse('15000.75'));
    });
  });
}
