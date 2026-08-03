import 'dart:convert';

/// Local mirrors of the server's exact validation rules
/// (`PrestaMesta_Server/utils/passwordPolicy.js`,
/// `validators/clienteAuthValidators.js`) — for UX only (inline field errors
/// before submitting). The server remains the sole authority; these never
/// alter what gets sent, only whether the submit button is enabled.

const passwordMinLength = 12;
const passwordMaxBytes = 72;

/// Mirrors `checkPasswordStrength` byte-for-byte: min 12 chars, max 72
/// **bytes** measured in UTF-8 (not `.length`, since accented/multibyte
/// characters can push a "72-character" password over the real byte limit),
/// at least one lowercase, one uppercase, one digit. Returns the empty list
/// when the password is valid.
List<String> passwordProblems(String password) {
  final problems = <String>[];
  if (password.isEmpty) return ['La contraseña es obligatoria.'];

  if (password.length < passwordMinLength) {
    problems.add('Debe tener al menos $passwordMinLength caracteres.');
  }
  if (utf8.encode(password).length > passwordMaxBytes) {
    problems.add(
        'Es demasiado larga (máximo $passwordMaxBytes bytes; acentos y emoji cuentan más).');
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    problems.add('Debe incluir al menos una minúscula.');
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    problems.add('Debe incluir al menos una mayúscula.');
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    problems.add('Debe incluir al menos un dígito.');
  }
  return problems;
}

bool isPasswordValid(String password) => passwordProblems(password).isEmpty;

/// A permissive, non-"universal" shape check — just enough to catch obvious
/// typos before hitting the server, which does the real validation
/// (`z.email()`). Trims first since the server also trims before validating.
bool isEmailFormatValid(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty || trimmed.length > 190) return false;
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
}

/// `nombre`: required, max 150 chars (`ClienteRegistroInput.nombre`).
bool isNombreValid(String nombre) {
  final trimmed = nombre.trim();
  return trimmed.isNotEmpty && trimmed.length <= 150;
}

/// `telefono`: genuinely optional; when provided, 7–20 chars after trimming
/// (`ClienteRegistroInput.telefono`). An empty/missing value is valid — it's
/// optional, not a validation failure.
bool isTelefonoValid(String telefono) {
  final trimmed = telefono.trim();
  if (trimmed.isEmpty) return true;
  return trimmed.length >= 7 && trimmed.length <= 20;
}
