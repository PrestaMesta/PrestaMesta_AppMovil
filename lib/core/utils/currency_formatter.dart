import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Formats an exact [Decimal] money amount for display using the `es_MX`
/// locale. The conversion to `double` happens **only here, at the final
/// display boundary** — `intl`'s `NumberFormat` requires a `num`, but no
/// arithmetic is ever performed on that `double`; it exists purely to
/// render digit grouping/currency symbol placement. All computation
/// (`calculateEstimate`, catalog parsing) stays on [Decimal]/[Rational]
/// end to end.
///
/// Currency code is left unconfirmed in the backend (see
/// `PrestaMesta_Server/utils/money.js`), so this uses the generic `es_MX`
/// number grouping with a literal `$ ... MXN` presentation rather than
/// asserting an ISO 4217 code the server has never actually declared.
String formatMoney(Decimal amount) {
  final formatter = NumberFormat.currency(
    locale: 'es_MX',
    symbol: r'$',
    decimalDigits: 2,
  );
  return '${formatter.format(amount.toDouble())} MXN';
}

/// Formats a percentage rate (e.g. `tasa_interes_anual`) with exactly 2
/// decimals, regardless of how many trailing zeros [Decimal.toString] would
/// otherwise trim (`Decimal.parse('24.00').toString()` is `'24'`, not
/// `'24.00'` — [Decimal] normalizes away trailing zeros). Display-only, same
/// double-at-the-boundary rule as [formatMoney].
String formatPercent(Decimal rate) {
  final formatter = NumberFormat('#,##0.00', 'es_MX');
  return '${formatter.format(rate.toDouble())}%';
}
