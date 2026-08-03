import 'package:decimal/decimal.dart';

/// The optional "aval" — exactly `AvalInput` in
/// `PrestaMesta_Server/openapi.yaml`, confirmed against `avalSchema` in
/// `validators/prestamoValidators.js`: `nombre`/`telefono` required,
/// `direccion`/`ingreso_mensual` genuinely optional. Never reused as a
/// response model — the server never echoes the guarantor back.
class Guarantor {
  final String nombre;
  final String telefono;
  final String? direccion;
  final Decimal? ingresoMensual;

  const Guarantor({
    required this.nombre,
    required this.telefono,
    this.direccion,
    this.ingresoMensual,
  });

  /// Omits every optional field that's empty/absent rather than sending
  /// `null` or `""` — the server's Zod schema treats a present-but-empty
  /// optional field differently from an absent one for some validators, and
  /// there's no reason to send a value the user never actually provided.
  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      if (direccion != null && direccion!.trim().isNotEmpty)
        'direccion': direccion!.trim(),
      // Verified lossless for DECIMAL(12,2)-range values — see
      // loan_request.dart's doc comment on the same conversion for
      // `monto_solicitado`.
      if (ingresoMensual != null) 'ingreso_mensual': ingresoMensual!.toDouble(),
    };
  }
}
