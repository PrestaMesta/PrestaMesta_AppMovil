import 'package:decimal/decimal.dart';

/// Exactly `EstadoPrestamo` in `openapi.yaml`: only the three states the
/// state machine (`utils/prestamoStateMachine.js`) actually implements.
/// `ACTIVO`/`PAGADO`/`EN_MORA`/`CANCELADO` are marked `x-pendiente-decision`
/// in the spec — they do not exist in the real API, so there is no case for
/// them here. An unrecognized value must never be silently accepted.
enum EstadoPrestamo {
  pendiente,
  aprobado,
  rechazado;

  static EstadoPrestamo parse(String raw) {
    switch (raw) {
      case 'PENDIENTE':
        return EstadoPrestamo.pendiente;
      case 'APROBADO':
        return EstadoPrestamo.aprobado;
      case 'RECHAZADO':
        return EstadoPrestamo.rechazado;
      default:
        throw FormatException('estado de préstamo desconocido: "$raw"');
    }
  }
}

/// The real `201` body of `POST /prestamos/solicitar` — the only source of
/// truth for what actually happened. Nothing here is computed locally:
/// `montoTotalAPagar` in particular **replaces** whatever local estimate was
/// shown before submitting, never the other way around.
///
/// Field shapes confirmed against `openapi.yaml` and
/// `controllers/prestamoController.js#solicitarPrestamo`:
/// - `montoSolicitado`: JSON **number** (an echo of what was sent, not
///   server-computed) — decoded as `num`, then converted to [Decimal] via
///   its string form; never kept as `double`.
/// - `montoTotalAPagar`: JSON **string** (server-computed via
///   `utils/money.js`, e.g. `"12400.00"`) — parsed directly as [Decimal].
class LoanSubmissionResponse {
  final String mensaje;
  final int prestamoId;
  final DateTime fechaSolicitud;
  final Decimal montoSolicitado;
  final Decimal montoTotalAPagar;
  final EstadoPrestamo estado;

  const LoanSubmissionResponse({
    required this.mensaje,
    required this.prestamoId,
    required this.fechaSolicitud,
    required this.montoSolicitado,
    required this.montoTotalAPagar,
    required this.estado,
  });

  /// Throws [FormatException] for anything missing, mistyped, or
  /// unrecognized — a confirmation screen built from a partially-trusted
  /// response would be worse than showing an error.
  factory LoanSubmissionResponse.fromJson(Map<String, dynamic> json) {
    final prestamoId = json['prestamoId'];
    final fechaRaw = json['fechaSolicitud'];
    final montoSolicitadoRaw = json['montoSolicitado'];
    final montoTotalRaw = json['montoTotalAPagar'];
    final estadoRaw = json['estado'];

    if (prestamoId is! int ||
        fechaRaw is! String ||
        montoSolicitadoRaw is! num ||
        montoTotalRaw is! String ||
        estadoRaw is! String) {
      throw const FormatException(
          'Respuesta de solicitud de préstamo con forma inesperada.');
    }

    final fechaSolicitud = DateTime.tryParse(fechaRaw);
    if (fechaSolicitud == null) {
      throw const FormatException('Respuesta de solicitud con fecha inválida.');
    }

    return LoanSubmissionResponse(
      mensaje: json['mensaje'] as String? ?? '',
      prestamoId: prestamoId,
      fechaSolicitud: fechaSolicitud,
      montoSolicitado: Decimal.parse(montoSolicitadoRaw.toString()),
      montoTotalAPagar: Decimal.parse(montoTotalRaw),
      estado: EstadoPrestamo.parse(estadoRaw),
    );
  }
}
