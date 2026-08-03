import 'package:decimal/decimal.dart';

/// A digit string with at most one decimal separator (`.` or `,`) and at
/// most 2 digits after it — no sign, no thousands separator, no exponent,
/// no leading/trailing junk. Anything else is rejected outright rather than
/// guessed at: a thousands-separated or dual-separator input (`"1,234.56"`,
/// `"1.234,56"`) is genuinely ambiguous between locales and is treated as
/// invalid rather than parsed with a guessed convention.
final _amountPattern = RegExp(r'^[0-9]+([.,][0-9]{1,2})?$');

/// Parses a user-typed loan amount into an exact [Decimal], or returns
/// `null` if the input can't be interpreted safely. **`null` means
/// "invalid" — callers must never treat it as zero or substitute a
/// default.** Rejects empty input, negative signs, scientific notation,
/// more than 2 decimal digits, and ambiguous separator combinations.
Decimal? parseUserAmount(String raw) {
  final trimmed = raw.trim();
  if (!_amountPattern.hasMatch(trimmed)) return null;

  final normalized = trimmed.replaceFirst(',', '.');
  return Decimal.tryParse(normalized);
}
