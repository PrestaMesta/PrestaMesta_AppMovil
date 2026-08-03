import '../data/loan_submission_response.dart';

/// Single source of truth for how [EstadoPrestamo] is worded in the UI —
/// shared by the confirmation screen, Home's session summary, and
/// StatusScreen so the three never drift (e.g. one of them accidentally
/// wording `pendiente` as "Aprobado"). `aprobado`/`rechazado` are only ever
/// shown when that is exactly the value the server returned — never
/// inferred or guessed.
String estadoPrestamoLabel(EstadoPrestamo estado) {
  switch (estado) {
    case EstadoPrestamo.pendiente:
      return 'Pendiente de revisión';
    case EstadoPrestamo.aprobado:
      return 'Aprobado';
    case EstadoPrestamo.rechazado:
      return 'Rechazado';
  }
}

/// Hand-formatted (no `intl` `DateFormat` with month names) for the same
/// reason as `loan_confirmation_screen.dart`: avoids `LocaleDataException`
/// without adding `initializeDateFormatting()` to `main.dart`.
String formatLoanDate(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
