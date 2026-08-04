/// Minimal credit view (`id` + `nombre`) nested inside a client's own loan
/// list/detail — exactly `CreditoResumen` in `openapi.yaml`. Deliberately not
/// the full `Credito` catalog model (`features/credits/data/credit_model.dart`)
/// — the loans endpoints never return the other credit fields
/// (`monto_minimo`/`monto_maximo`/`tasa_interes_anual`/`plazo_meses`), so
/// this app must not pretend it has them.
class CreditoResumen {
  final int id;
  final String nombre;

  const CreditoResumen({required this.id, required this.nombre});

  factory CreditoResumen.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    if (id is! int || nombre is! String) {
      throw const FormatException('Crédito anidado con forma inesperada.');
    }
    return CreditoResumen(id: id, nombre: nombre);
  }
}
