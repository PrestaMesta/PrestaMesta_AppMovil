import 'package:decimal/decimal.dart';

import 'credito_resumen.dart';
import 'loan_submission_response.dart';
import 'pagination.dart';

/// One row of `GET /client/prestamos` — exactly `PrestamoClienteListItem` in
/// `openapi.yaml`. `monto_solicitado`/`monto_total_a_pagar`/`saldo_pendiente`
/// arrive as **decimal strings** (raw `DECIMAL` columns read via `mysql2`),
/// unlike `POST /prestamos/solicitar`'s response where `montoSolicitado` is
/// the JSON number the client sent — a real, confirmed asymmetry between the
/// two endpoints, not normalized away here. `fecha_decision` is `null` until
/// an admin has approved/rejected the request.
class PrestamoListItem {
  final int id;
  final CreditoResumen credito;
  final Decimal montoSolicitado;
  final Decimal montoTotalAPagar;
  final Decimal saldoPendiente;
  final EstadoPrestamo estado;
  final DateTime fechaSolicitud;
  final DateTime? fechaDecision;

  const PrestamoListItem({
    required this.id,
    required this.credito,
    required this.montoSolicitado,
    required this.montoTotalAPagar,
    required this.saldoPendiente,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaDecision,
  });

  /// Throws [FormatException] for anything missing, mistyped, or
  /// unrecognized — never returns a partially-trusted loan.
  factory PrestamoListItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final creditoRaw = json['credito'];
    final montoSolicitadoRaw = json['monto_solicitado'];
    final montoTotalRaw = json['monto_total_a_pagar'];
    final saldoPendienteRaw = json['saldo_pendiente'];
    final estadoRaw = json['estado'];
    final fechaSolicitudRaw = json['fecha_solicitud'];
    final fechaDecisionRaw = json['fecha_decision'];

    if (id is! int ||
        creditoRaw is! Map<String, dynamic> ||
        montoSolicitadoRaw is! String ||
        montoTotalRaw is! String ||
        saldoPendienteRaw is! String ||
        estadoRaw is! String ||
        fechaSolicitudRaw is! String ||
        (fechaDecisionRaw != null && fechaDecisionRaw is! String)) {
      throw const FormatException('Préstamo con forma inesperada.');
    }

    final fechaSolicitud = DateTime.tryParse(fechaSolicitudRaw);
    if (fechaSolicitud == null) {
      throw const FormatException('Préstamo con fecha de solicitud inválida.');
    }
    DateTime? fechaDecision;
    if (fechaDecisionRaw != null) {
      fechaDecision = DateTime.tryParse(fechaDecisionRaw);
      if (fechaDecision == null) {
        throw const FormatException('Préstamo con fecha de decisión inválida.');
      }
    }

    return PrestamoListItem(
      id: id,
      credito: CreditoResumen.fromJson(creditoRaw),
      montoSolicitado: Decimal.parse(montoSolicitadoRaw),
      montoTotalAPagar: Decimal.parse(montoTotalRaw),
      saldoPendiente: Decimal.parse(saldoPendienteRaw),
      estado: EstadoPrestamo.parse(estadoRaw),
      fechaSolicitud: fechaSolicitud,
      fechaDecision: fechaDecision,
    );
  }
}

/// The full `200` body of `GET /client/prestamos`: a page of loans plus its
/// [Pagination] envelope. Order is fixed server-side
/// (`fecha_solicitud DESC, id DESC`, confirmed against
/// `repositories/prestamoRepository.js`) — this app never re-sorts [data].
class LoanListPage {
  final List<PrestamoListItem> data;
  final Pagination pagination;

  const LoanListPage({required this.data, required this.pagination});

  factory LoanListPage.fromJson(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    final paginationRaw = json['pagination'];
    if (dataRaw is! List || paginationRaw is! Map<String, dynamic>) {
      throw const FormatException(
          'Respuesta de préstamos con forma inesperada.');
    }
    return LoanListPage(
      data: dataRaw.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Préstamo con forma inesperada.');
        }
        return PrestamoListItem.fromJson(item);
      }).toList(growable: false),
      pagination: Pagination.fromJson(paginationRaw),
    );
  }
}
