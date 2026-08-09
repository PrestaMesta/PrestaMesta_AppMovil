/// Local, UX-only mirrors of the server's MFA input shapes
/// (`MfaEnrollConfirmInput`/`MfaVerifyInput` in `openapi.yaml`). Same caveat
/// as `auth_validators.dart`: these only gate the submit button, the server
/// remains the sole authority on whether a code is actually correct.
library;

final _totpPattern = RegExp(r'^\d{6}$');

/// A TOTP code: exactly 6 digits (`MfaEnrollConfirmInput.codigo`/
/// `MfaVerifyInput.codigo` both use the pattern `^\d{6}$`).
bool isTotpCodeValid(String codigo) => _totpPattern.hasMatch(codigo.trim());

/// A recovery code: the server never publishes a strict format for
/// `codigoRecuperacion` beyond "non-empty, one-time-use" — this only rejects
/// the obviously-empty case, unlike the TOTP check above.
bool isRecoveryCodeValid(String codigo) => codigo.trim().isNotEmpty;
