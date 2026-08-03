import 'package:decimal/decimal.dart';

import 'guarantor.dart';

/// Body for `POST /prestamos/solicitar` — exactly `SolicitudPrestamoInput`
/// (`PrestaMesta_Server/openapi.yaml`, confirmed against
/// `solicitarPrestamoSchema` in `validators/prestamoValidators.js`, `.strict()`
/// — unknown properties are rejected server-side). Identity comes from the
/// JWT; there is deliberately no `clienteId` field here to accidentally send.
///
/// Never send, because the validator rejects them and the server computes
/// them itself: `monto_total_a_pagar`, `saldo_pendiente`, `estado`,
/// `fecha_solicitud`, `tasa_interes_anual`, `plazo_meses`, `cliente_id`,
/// `administrador_id`.
class LoanRequest {
  final int creditoId;
  final Decimal montoSolicitado;
  final Guarantor? aval;

  const LoanRequest(
      {required this.creditoId, required this.montoSolicitado, this.aval});

  Map<String, dynamic> toJson() {
    return {
      'credito_id': creditoId,
      // `monto_solicitado` is declared `type: number` in openapi.yaml (not a
      // decimal string like the catalog's fields) — `Decimal.toDouble()` is
      // the one sanctioned use of `double` in this feature, verified lossless
      // for the full DECIMAL(12,2) range in
      // `test/features/loans/data/loan_request_test.dart` (e.g.
      // 9999999999.99, 0.01, 1.01 all round-trip through JSON exactly).
      'monto_solicitado': montoSolicitado.toDouble(),
      if (aval != null) 'aval': aval!.toJson(),
    };
  }
}
