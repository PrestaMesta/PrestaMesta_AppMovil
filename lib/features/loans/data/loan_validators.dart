// Local mirrors of `validators/prestamoValidators.js#avalSchema` — UX only,
// the server remains the authority. `monto_solicitado` itself is validated
// by `features/credits` (range against the selected `Credito`); this file
// only covers the guarantor fields, which have no equivalent elsewhere.

/// `nombre`: required, max 150 chars (`AvalInput.nombre`).
bool isGuarantorNombreValid(String nombre) {
  final trimmed = nombre.trim();
  return trimmed.isNotEmpty && trimmed.length <= 150;
}

/// `telefono`: required (unlike the client's own optional phone at
/// registration), 7–20 chars after trimming — same length rule as
/// `clienteAuthValidators.js`, but required here because `avalSchema` has no
/// `.optional()` on it.
bool isGuarantorTelefonoValid(String telefono) {
  final trimmed = telefono.trim();
  return trimmed.length >= 7 && trimmed.length <= 20;
}

/// `direccion`: genuinely optional; when provided, max 255 chars.
bool isGuarantorDireccionValid(String direccion) {
  return direccion.trim().length <= 255;
}
