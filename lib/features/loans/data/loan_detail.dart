import 'package:decimal/decimal.dart';

import 'aval_detalle.dart';
import 'credito_resumen.dart';
import 'loan_list_item.dart';
import 'loan_submission_response.dart';

/// The full `200` body of `GET /client/prestamos/:id` — exactly
/// `PrestamoClienteDetalle` in `openapi.yaml`, which is `PrestamoClienteListItem`
/// plus [aval]. Composed over [PrestamoListItem] rather than duplicating its
/// fields, so both endpoints share exactly one parsing implementation.
///
/// [aval] is `null` whenever the loan has no guarantor on record — the
/// server's `LEFT JOIN` returning no row, not an empty/zero-filled object.
/// The 404 this endpoint returns for "loan doesn't exist" and "loan belongs
/// to another client" is identical (`LOAN_NOT_FOUND`, anti-enumeration by
/// design — see `routes/clientePrestamoRoutes.js`) — this app never tries to
/// distinguish the two cases.
class PrestamoDetalle {
  final PrestamoListItem resumen;
  final AvalDetalle? aval;

  const PrestamoDetalle({required this.resumen, this.aval});

  int get id => resumen.id;
  CreditoResumen get credito => resumen.credito;
  Decimal get montoSolicitado => resumen.montoSolicitado;
  Decimal get montoTotalAPagar => resumen.montoTotalAPagar;
  Decimal get saldoPendiente => resumen.saldoPendiente;
  EstadoPrestamo get estado => resumen.estado;
  DateTime get fechaSolicitud => resumen.fechaSolicitud;
  DateTime? get fechaDecision => resumen.fechaDecision;

  factory PrestamoDetalle.fromJson(Map<String, dynamic> json) {
    final resumen = PrestamoListItem.fromJson(json);
    final avalRaw = json['aval'];
    if (avalRaw != null && avalRaw is! Map<String, dynamic>) {
      throw const FormatException('Aval con forma inesperada.');
    }
    return PrestamoDetalle(
      resumen: resumen,
      aval: avalRaw == null
          ? null
          : AvalDetalle.fromJson(avalRaw as Map<String, dynamic>),
    );
  }
}
