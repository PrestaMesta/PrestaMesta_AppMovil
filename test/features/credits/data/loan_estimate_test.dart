import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/credits/data/loan_estimate.dart';

/// These vectors are copied/adapted from
/// `PrestaMesta_Server/tests/unit/money.test.js` (which tests
/// `utils/money.js#calcularMontoTotalAPagar`) specifically to catch any
/// drift between the Node and Flutter implementations of the same formula.
/// This duplication exists **only for UX** (an instant, local estimate
/// before the user submits anything) — the server remains the sole
/// authority on `monto_total_a_pagar` the moment a real
/// `POST /prestamos/solicitar` exists.
void main() {
  group('calculateEstimate (mirrors PrestaMesta_Server/utils/money.js)', () {
    test('10000 @ 24% for 12 months -> 12400.00 (server test vector)', () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('10000'),
        annualRatePercent: Decimal.parse('24'),
        termMonths: 12,
      );
      expect(estimate.estimatedTotal.toStringAsFixed(2), '12400.00');
      expect(estimate.estimatedInterest.toStringAsFixed(2), '2400.00');
    });

    test(
        '5000 @ 24% for 6 months -> 5600.00 (server test vector, prorated term)',
        () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('5000'),
        annualRatePercent: Decimal.parse('24'),
        termMonths: 6,
      );
      expect(estimate.estimatedTotal.toStringAsFixed(2), '5600.00');
    });

    test('1000 @ 13% for 7 months -> 1075.83 (server test vector, rounds down)',
        () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('1000'),
        annualRatePercent: Decimal.parse('13'),
        termMonths: 7,
      );
      // interest = 1000 * 0.13 * (7/12) = 75.8333... -> total 1075.8333... -> 1075.83
      expect(estimate.estimatedTotal.toStringAsFixed(2), '1075.83');
    });

    test('1 @ 0% for 1 month -> 1.00, always 2 decimals (server test vector)',
        () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('1'),
        annualRatePercent: Decimal.parse('0'),
        termMonths: 1,
      );
      expect(estimate.estimatedTotal.toStringAsFixed(2), '1.00');
    });

    test(
        'exact tie: ROUND_HALF_UP rounds .005 up, not to even (decimal.js semantics)',
        () {
      // 1 @ 1% for 6 months: interest = 1 * 0.01 * 0.5 = 0.005 exactly.
      // total = 1.005 exactly -> a genuine tie between 1.00 and 1.01.
      // ROUND_HALF_UP (away from zero) must give 1.01; ROUND_HALF_EVEN
      // (banker's rounding) would give 1.00 — this test would catch an
      // accidental switch to the wrong rounding mode.
      final estimate = calculateEstimate(
        amount: Decimal.parse('1'),
        annualRatePercent: Decimal.parse('1'),
        termMonths: 6,
      );
      expect(estimate.estimatedTotal.toStringAsFixed(2), '1.01');
    });

    test('rounds up on a non-tie fractional cent', () {
      // 100 @ 5% for 5 months: interest = 100*0.05*(5/12) = 2.08333...
      // -> total 102.08333... -> 102.08 (rounds down, third decimal is 3)
      final estimate = calculateEstimate(
        amount: Decimal.parse('100'),
        annualRatePercent: Decimal.parse('5'),
        termMonths: 5,
      );
      expect(estimate.estimatedTotal.toStringAsFixed(2), '102.08');
    });

    test('minimum boundary amount (matches a catalog monto_minimo)', () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('1000.00'),
        annualRatePercent: Decimal.parse('24.00'),
        termMonths: 12,
      );
      expect(estimate.estimatedTotal.toStringAsFixed(2), '1240.00');
    });

    test('maximum boundary amount within DECIMAL(12,2) range', () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('9999999999.99'),
        annualRatePercent: Decimal.parse('1.00'),
        termMonths: 12,
      );
      // interest = 9999999999.99 * 0.01 * 1 = 99999999.9999 -> rounds to 100000000.00
      expect(estimate.estimatedTotal.toStringAsFixed(2), '10099999999.99');
    });

    test('rate with decimals (DECIMAL(5,2) e.g. 13.50%)', () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('2000'),
        annualRatePercent: Decimal.parse('13.50'),
        termMonths: 12,
      );
      // interest = 2000 * 0.135 * 1 = 270.00
      expect(estimate.estimatedTotal.toStringAsFixed(2), '2270.00');
    });

    test('estimatedInterest + amount always equals estimatedTotal exactly', () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('1000'),
        annualRatePercent: Decimal.parse('13'),
        termMonths: 7,
      );
      expect(estimate.amount + estimate.estimatedInterest,
          estimate.estimatedTotal);
    });

    test('zero rate produces zero interest and total equal to amount', () {
      final estimate = calculateEstimate(
        amount: Decimal.parse('5000'),
        annualRatePercent: Decimal.parse('0'),
        termMonths: 24,
      );
      expect(estimate.estimatedInterest.toStringAsFixed(2), '0.00');
      expect(estimate.estimatedTotal.toStringAsFixed(2), '5000.00');
    });
  });
}
