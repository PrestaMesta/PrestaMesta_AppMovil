import 'package:decimal/decimal.dart';

/// One entry of the credit catalog — exactly `Credito` in
/// `PrestaMesta_Server/openapi.yaml`, confirmed against
/// `controllers/prestamoController.js#obtenerCreditos` and
/// `repositories/prestamoRepository.js#listarCreditos` (`SELECT * FROM
/// creditos`, `migrations/003_creditos.sql`).
///
/// Field shapes as they actually arrive over the wire (`mysql2` returns
/// `DECIMAL` columns as strings by default; `TIMESTAMP` as a JS `Date`,
/// which `res.json()` serializes to an ISO-8601 string):
/// - `id`: JSON number (`INT UNSIGNED`).
/// - `nombre`: JSON string.
/// - `monto_minimo`, `monto_maximo`: JSON strings, e.g. `"1000.00"`
///   (`DECIMAL(12,2)`) — parsed as [Decimal], never `double`.
/// - `tasa_interes_anual`: JSON string, e.g. `"24.00"` (`DECIMAL(5,2)`) —
///   parsed as [Decimal].
/// - `plazo_meses`: JSON number (`SMALLINT UNSIGNED`).
/// - `creado_en`: JSON string, ISO-8601 (`TIMESTAMP`) — parsed as [DateTime].
///
/// This is the catalog model only — never reused for the future loan
/// request/response shape, which has different fields and a different
/// contract (`SolicitudPrestamoInput`, not implemented yet).
class Credito {
  final int id;
  final String nombre;
  final Decimal montoMinimo;
  final Decimal montoMaximo;
  final Decimal tasaInteresAnual;
  final int plazoMeses;
  final DateTime creadoEn;

  const Credito({
    required this.id,
    required this.nombre,
    required this.montoMinimo,
    required this.montoMaximo,
    required this.tasaInteresAnual,
    required this.plazoMeses,
    required this.creadoEn,
  });

  /// Throws [FormatException] (never returns a partially-valid credit, never
  /// substitutes a default) when the shape doesn't match — including on a
  /// malformed decimal string, which [Decimal.parse] itself already rejects
  /// rather than silently truncating or coercing to zero.
  factory Credito.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final montoMinimoRaw = json['monto_minimo'];
    final montoMaximoRaw = json['monto_maximo'];
    final tasaRaw = json['tasa_interes_anual'];
    final plazoMeses = json['plazo_meses'];
    final creadoEnRaw = json['creado_en'];

    if (id is! int ||
        nombre is! String ||
        montoMinimoRaw is! String ||
        montoMaximoRaw is! String ||
        tasaRaw is! String ||
        plazoMeses is! int ||
        creadoEnRaw is! String) {
      throw const FormatException('Crédito del catálogo con forma inesperada.');
    }

    final creadoEn = DateTime.tryParse(creadoEnRaw);
    if (creadoEn == null) {
      throw const FormatException('Crédito del catálogo con fecha inválida.');
    }

    return Credito(
      id: id,
      nombre: nombre,
      montoMinimo: Decimal.parse(montoMinimoRaw),
      montoMaximo: Decimal.parse(montoMaximoRaw),
      tasaInteresAnual: Decimal.parse(tasaRaw),
      plazoMeses: plazoMeses,
      creadoEn: creadoEn,
    );
  }
}
