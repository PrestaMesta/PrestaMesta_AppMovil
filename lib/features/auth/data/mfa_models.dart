import '../../../core/storage/session_local_storage.dart';

/// Discriminator the server returns after a correct password
/// (`POST /client/auth/login`) telling this app which MFA endpoint to call
/// next. Per `openapi.yaml`'s `SiguientePasoMfa` schema, the UI must branch
/// on this value **only** — never on the informational `mfaEstado` field,
/// which is why this app doesn't even model `mfaEstado` at all.
enum SiguientePasoMfa {
  enrollmentRequired,
  challengeRequired;

  static SiguientePasoMfa parse(String raw) {
    switch (raw) {
      case 'MFA_ENROLLMENT_REQUIRED':
        return SiguientePasoMfa.enrollmentRequired;
      case 'MFA_CHALLENGE_REQUIRED':
        return SiguientePasoMfa.challengeRequired;
      default:
        throw FormatException('siguientePaso desconocido: $raw');
    }
  }
}

/// The `200` body of `POST /client/auth/login` since Checkpoint 6B-2 on the
/// server: a correct password no longer returns a usable session — it
/// returns a short-lived [preMfaToken] plus [siguientePaso]. This app must
/// never treat [preMfaToken] as a session JWT: it is only ever sent to
/// `mfa/enroll`, `mfa/enroll/confirm` and `mfa/verify`, and it is never
/// passed to `SessionLocalStorage`/`core/network/auth_interceptor.dart`'s
/// `requiresAuthExtraKey` path.
class LoginPreMfaResult {
  final String mensaje;
  final String preMfaToken;
  final SiguientePasoMfa siguientePaso;

  const LoginPreMfaResult({
    required this.mensaje,
    required this.preMfaToken,
    required this.siguientePaso,
  });

  factory LoginPreMfaResult.fromJson(Map<String, dynamic> json) {
    final preMfaToken = json['preMfaToken'] as String?;
    final siguientePasoRaw = json['siguientePaso'] as String?;
    if (preMfaToken == null ||
        preMfaToken.isEmpty ||
        siguientePasoRaw == null) {
      throw const FormatException(
          'Respuesta de login incompleta: falta preMfaToken o siguientePaso.');
    }
    return LoginPreMfaResult(
      mensaje: json['mensaje'] as String? ?? '',
      preMfaToken: preMfaToken,
      siguientePaso: SiguientePasoMfa.parse(siguientePasoRaw),
    );
  }
}

/// The `201` body of `POST /client/auth/mfa/enroll`: a freshly generated TOTP
/// secret and its `otpauth://` URI. Per `openapi.yaml`, both values are
/// returned **only in this response** — the server never exposes the secret
/// in clear text again after this, so nothing here is ever cached to disk.
class MfaEnrollResult {
  final String mensaje;
  final String secreto;
  final String otpauthUri;

  const MfaEnrollResult({
    required this.mensaje,
    required this.secreto,
    required this.otpauthUri,
  });

  factory MfaEnrollResult.fromJson(Map<String, dynamic> json) {
    final secreto = json['secreto'] as String?;
    final otpauthUri = json['otpauthUri'] as String?;
    if (secreto == null || secreto.isEmpty || otpauthUri == null) {
      throw const FormatException(
          'Respuesta de enrolamiento MFA incompleta: falta secreto o otpauthUri.');
    }
    return MfaEnrollResult(
      mensaje: json['mensaje'] as String? ?? '',
      secreto: secreto,
      otpauthUri: otpauthUri,
    );
  }
}

/// Body for `POST /client/auth/mfa/enroll/confirm` — exactly
/// `MfaEnrollConfirmInput` (`{codigo}`, the first 6-digit TOTP from the
/// secret `mfa/enroll` just generated).
class MfaEnrollConfirmRequest {
  final String codigo;

  const MfaEnrollConfirmRequest({required this.codigo});

  Map<String, dynamic> toJson() => {'codigo': codigo};
}

/// Body for `POST /client/auth/mfa/verify` — exactly `MfaVerifyInput`:
/// **exactly one** of a 6-digit TOTP or a recovery code, never both, never
/// neither (enforced by the two named factories below, not by a nullable
/// pair of fields callers could misuse).
class MfaVerifyRequest {
  final String? codigo;
  final String? codigoRecuperacion;

  const MfaVerifyRequest._({this.codigo, this.codigoRecuperacion});

  const MfaVerifyRequest.totp(String codigo) : this._(codigo: codigo);

  const MfaVerifyRequest.recoveryCode(String codigoRecuperacion)
      : this._(codigoRecuperacion: codigoRecuperacion);

  Map<String, dynamic> toJson() => {
        if (codigo != null) 'codigo': codigo,
        if (codigoRecuperacion != null)
          'codigoRecuperacion': codigoRecuperacion,
      };
}

/// The `200` body of `POST /client/auth/mfa/enroll/confirm` and
/// `POST /client/auth/mfa/verify` when MFA completes successfully: the real
/// session token, at last. [codigosRecuperacion] is only ever non-null from
/// `mfa/enroll/confirm` (the one-time batch generated when MFA is first
/// activated) — `mfa/verify`'s response never includes it, matching the
/// server contract exactly (never defaulted to an empty list, so callers can
/// tell "no codes in this response" apart from "server returned zero
/// codes").
class MfaSessionResult {
  final String mensaje;
  final String token;
  final ClienteSummary cliente;
  final List<String>? codigosRecuperacion;

  const MfaSessionResult({
    required this.mensaje,
    required this.token,
    required this.cliente,
    this.codigosRecuperacion,
  });

  factory MfaSessionResult.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    final clienteJson = json['cliente'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty || clienteJson == null) {
      throw const FormatException(
          'Respuesta de sesión MFA incompleta: falta token o cliente.');
    }
    final codigosRaw = json['codigosRecuperacion'] as List<dynamic>?;
    return MfaSessionResult(
      mensaje: json['mensaje'] as String? ?? '',
      token: token,
      cliente: ClienteSummary.fromJson(clienteJson),
      codigosRecuperacion:
          codigosRaw?.map((e) => e as String).toList(growable: false),
    );
  }
}
