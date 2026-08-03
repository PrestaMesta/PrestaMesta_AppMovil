import 'dart:convert';

/// Reads the `exp` claim out of a JWT **without verifying its signature**.
/// This is only a local, offline hint used to decide whether it's worth
/// keeping a token around at all before the app has made a single request —
/// it is never used to authorize anything and never a substitute for the
/// server rejecting the token (`TOKEN_EXPIRED`/`TOKEN_INVALID`, handled in
/// `core/network/auth_interceptor.dart`), which remains the real authority.
///
/// A token that can't be decoded, or that has no `exp` claim, is treated as
/// expired: this backend's tokens always carry `exp` (see
/// `PrestaMesta_Server/CLAUDE.md`, "Auth model"), so the absence of one means
/// the value isn't a token this app should trust or keep.
bool isJwtExpired(String token, {DateTime? now}) {
  final payload = _decodePayload(token);
  if (payload == null) return true;

  final exp = payload['exp'];
  if (exp is! int) return true;

  final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  return !expiry.isAfter((now ?? DateTime.now()).toUtc());
}

Map<String, dynamic>? _decodePayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    if (json is Map<String, dynamic>) return json;
    return null;
  } catch (_) {
    return null;
  }
}
