import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// A **local, non-authoritative** projection of what a loan might cost.
///
/// This mirrors, byte-for-byte, the formula in
/// `PrestaMesta_Server/utils/money.js#calcularMontoTotalAPagar` (simple
/// annual interest, prorated linearly by term, no compounding, rounded
/// ROUND_HALF_UP to 2 decimals) — but the server is the only thing that ever
/// computes an authoritative `monto_total_a_pagar`, at the moment a loan is
/// actually requested (`POST /prestamos/solicitar`, not implemented yet in
/// this checkpoint). Nothing here creates a request or a financial
/// commitment.
class LoanEstimate {
  final Decimal amount;
  final Decimal annualRatePercent;
  final int termMonths;

  /// `estimatedTotal - amount`, derived **after** rounding the total — never
  /// independently rounded — so the two numbers shown to the user always add
  /// up exactly. The server has no separate "interest" field; this exists
  /// only for display.
  final Decimal estimatedInterest;

  /// Rounded the same way the server rounds `monto_total_a_pagar`
  /// (ROUND_HALF_UP to 2 decimals) — this is the only value here that could
  /// ever coincide with what the server would actually return, and even then
  /// only as an estimate computed before the request, not a guarantee.
  final Decimal estimatedTotal;

  const LoanEstimate({
    required this.amount,
    required this.annualRatePercent,
    required this.termMonths,
    required this.estimatedInterest,
    required this.estimatedTotal,
  });
}

final _hundred = Decimal.fromInt(100);
final _twelve = Rational.fromInt(12);
final _half = Rational(BigInt.one, BigInt.two);

/// Pure function: same inputs always produce the same output, no I/O, no
/// server call. `amount`/`annualRatePercent` are exact [Decimal]s (never
/// `double`) parsed from either the catalog's DECIMAL(12,2)/DECIMAL(5,2)
/// strings or validated user input — see `amount_input_parser.dart`.
///
/// Only meaningful for non-negative amounts/rates and a positive term, which
/// is all the catalog and the amount parser ever allow through; this does
/// not implement rounding semantics for negative numbers.
LoanEstimate calculateEstimate({
  required Decimal amount,
  required Decimal annualRatePercent,
  required int termMonths,
}) {
  final rateFraction = annualRatePercent / _hundred; // Rational, e.g. 24.00/100
  final termFraction = Rational.fromInt(termMonths) / _twelve;
  final interestExact = amount.toRational() * rateFraction * termFraction;
  final totalExact = amount.toRational() + interestExact;

  final estimatedTotal = _roundHalfUpToDecimal(totalExact);
  final estimatedInterest = estimatedTotal - amount;

  return LoanEstimate(
    amount: amount,
    annualRatePercent: annualRatePercent,
    termMonths: termMonths,
    estimatedInterest: estimatedInterest,
    estimatedTotal: estimatedTotal,
  );
}

/// Rounds an exact [Rational] money value to 2 decimal places using
/// ROUND_HALF_UP (ties round away from zero) — matching decimal.js's
/// `ROUND_HALF_UP` used server-side. Implemented on exact [Rational]
/// comparisons (no floating point at any point) so a tie is never missed or
/// misjudged due to binary floating-point representation error.
Decimal _roundHalfUpToDecimal(Rational value) {
  final cents = value * _hundred.toRational();
  final flo = cents
      .truncate(); // toward zero; equals floor for non-negative money values
  final remainder = cents - flo.toRational();
  final roundedCents = remainder >= _half ? flo + BigInt.one : flo;
  return Decimal.fromBigInt(roundedCents).shift(-2);
}
