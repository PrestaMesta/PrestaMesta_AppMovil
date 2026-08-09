/// Body for `POST /client/auth/register` — exactly `ClienteRegistroInput`
/// (`PrestaMesta_Server/openapi.yaml`). `telefono` is genuinely optional on
/// the server (`.optional()` in `validators/clienteAuthValidators.js`); never
/// send it as an empty string, omit the key entirely when not provided.
class RegisterRequest {
  final String nombre;
  final String email;
  final String password;
  final String? telefono;

  const RegisterRequest({
    required this.nombre,
    required this.email,
    required this.password,
    this.telefono,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'email': email,
      'password': password,
      if (telefono != null && telefono!.isNotEmpty) 'telefono': telefono,
    };
  }
}

/// The `201` body of `POST /client/auth/register`. Deliberately has no token
/// and no session — the server does not log a client in on registration.
class RegisterResult {
  final String mensaje;
  final int clienteId;

  const RegisterResult({required this.mensaje, required this.clienteId});

  factory RegisterResult.fromJson(Map<String, dynamic> json) {
    return RegisterResult(
      mensaje: json['mensaje'] as String? ?? '',
      clienteId: json['clienteId'] as int,
    );
  }
}

/// Body for `POST /client/auth/login` — exactly `LoginInput`. Since
/// Checkpoint 6B-2 the `200` response is no longer a usable session (see
/// `LoginPreMfaResult` in `mfa_models.dart`) — a correct password only ever
/// starts the mandatory MFA flow now.
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}
