import '../../../core/storage/session_local_storage.dart';

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

/// Body for `POST /client/auth/login` — exactly `LoginInput`.
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

/// The `200` body of `POST /client/auth/login`: `{mensaje, token, cliente}`.
/// [cliente] reuses [ClienteSummary] — it's the exact same shape
/// (`{id, nombre, email}`) that gets persisted locally after login.
class LoginResult {
  final String mensaje;
  final String token;
  final ClienteSummary cliente;

  const LoginResult(
      {required this.mensaje, required this.token, required this.cliente});

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String?;
    final clienteJson = json['cliente'] as Map<String, dynamic>?;
    if (token == null || token.isEmpty || clienteJson == null) {
      throw const FormatException(
          'Respuesta de login incompleta: falta token o cliente.');
    }
    return LoginResult(
      mensaje: json['mensaje'] as String? ?? '',
      token: token,
      cliente: ClienteSummary.fromJson(clienteJson),
    );
  }
}
