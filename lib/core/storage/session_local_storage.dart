import 'dart:convert';

import 'secure_storage.dart';

/// The minimal, non-financial client data the app keeps around locally after
/// login — exactly what `POST /client/auth/login` returns
/// (`cliente: {id, nombre, email}`, see `openapi.yaml`). Never extended with
/// fields the server doesn't actually send back; there is no `GET /client/me`
/// to refresh this from.
class ClienteSummary {
  final int id;
  final String nombre;
  final String email;

  const ClienteSummary(
      {required this.id, required this.nombre, required this.email});

  factory ClienteSummary.fromJson(Map<String, dynamic> json) {
    return ClienteSummary(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'email': email};
}

const _tokenKey = 'session_token';
const _clienteKey = 'session_cliente';

/// Persists the JWT and the minimal client profile as two separate secure
/// storage entries — not one blob — so the token (the only secret here) can
/// be read, replaced or wiped independently of the profile data, and so a
/// bug that logs one of them can never accidentally include the other.
///
/// This class only stores and retrieves; it never decides whether a session
/// is still valid (see `core/utils/jwt_utils.dart` for the local expiry
/// check) and never talks to the network.
class SessionLocalStorage {
  final SecureStorage _storage;

  SessionLocalStorage(this._storage);

  Future<void> saveSession(
      {required String token, required ClienteSummary cliente}) async {
    await _storage.write(_tokenKey, token);
    await _storage.write(_clienteKey, jsonEncode(cliente.toJson()));
  }

  Future<String?> readToken() => _storage.read(_tokenKey);

  Future<ClienteSummary?> readCliente() async {
    final raw = await _storage.read(_clienteKey);
    if (raw == null) return null;
    try {
      return ClienteSummary.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Wipes the local session. Called on explicit logout and whenever the
  /// server rejects the token (`TOKEN_EXPIRED`/`TOKEN_INVALID`) or the app
  /// notices the JWT is already expired on its own. There is no server-side
  /// revocation endpoint (stateless JWT, see `PrestaMesta_Server/CLAUDE.md`)
  /// — this is the only thing "logout" can actually do client-side.
  Future<void> clear() async {
    await _storage.delete(_tokenKey);
    await _storage.delete(_clienteKey);
  }
}
