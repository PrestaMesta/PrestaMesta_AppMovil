import 'package:decimal/decimal.dart';

/// Exactly `AvalDetalle` in `openapi.yaml`, only ever nested inside
/// `GET /client/prestamos/:id` — never `null`-coalesced into a "no aval"
/// object with empty/zero fields; the caller ([PrestamoDetalle.aval] being
/// `null`) is what means "no aval registered", matching the server's own
/// `LEFT JOIN` semantics (`repositories/prestamoRepository.js`).
///
/// `direccion` is `null` when it was never sent at solicitation time — never
/// an empty string. `ingresoMensual` is `null` for the same reason, and is a
/// [Decimal] (parsed from the raw `DECIMAL` string, e.g. `"15000.00"`) —
/// never `double`, same rule as everywhere else in this feature.
class AvalDetalle {
  final int id;
  final String nombre;
  final String telefono;
  final String? direccion;
  final Decimal? ingresoMensual;

  const AvalDetalle({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.direccion,
    this.ingresoMensual,
  });

  factory AvalDetalle.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final telefono = json['telefono'];
    final direccion = json['direccion'];
    final ingresoMensualRaw = json['ingreso_mensual'];

    if (id is! int ||
        nombre is! String ||
        telefono is! String ||
        (direccion != null && direccion is! String) ||
        (ingresoMensualRaw != null && ingresoMensualRaw is! String)) {
      throw const FormatException('Aval con forma inesperada.');
    }

    return AvalDetalle(
      id: id,
      nombre: nombre,
      telefono: telefono,
      direccion: direccion as String?,
      ingresoMensual: ingresoMensualRaw == null
          ? null
          : Decimal.parse(ingresoMensualRaw as String),
    );
  }
}
