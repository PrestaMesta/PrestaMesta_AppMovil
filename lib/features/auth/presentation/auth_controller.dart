import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/session_local_storage.dart';
import '../../../core/utils/jwt_utils.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    sessionStorage: ref.watch(sessionLocalStorageProvider),
  );
});

/// Owns the app's one session state machine. The presentation layer only
/// ever talks to this controller — never to `Dio`/`SecureStorage` directly.
///
/// Restoration is **local-only** by design (no `GET /client/me` exists to
/// call): it trusts a stored token until either the JWT's own `exp` claim
/// looks expired, or the server itself later rejects it with
/// `TOKEN_EXPIRED`/`TOKEN_INVALID` (see [sessionRejectedByServer]). A network
/// failure, a 403, or a 500 must never clear a locally-plausible session —
/// this class never does that.
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final SessionLocalStorage _sessionStorage;
  bool _isHandlingSessionRejection = false;

  AuthController(
      {required AuthRepository authRepository,
      required SessionLocalStorage sessionStorage})
      : _authRepository = authRepository,
        _sessionStorage = sessionStorage,
        super(const AuthState.restoring()) {
    _restore();
  }

  Future<void> _restore() async {
    final token = await _sessionStorage.readToken();
    final cliente = await _sessionStorage.readCliente();

    if (token == null || cliente == null) {
      await _sessionStorage.clear();
      state = const AuthState.unauthenticated();
      return;
    }

    if (isJwtExpired(token)) {
      await _sessionStorage.clear();
      state = const AuthState.unauthenticated();
      return;
    }

    state = AuthState.authenticated(cliente);
  }

  Future<void> login({required String email, required String password}) async {
    if (state.status == AuthStatus.authenticating) {
      return; // defense in depth; the UI also disables the button
    }

    state = const AuthState.authenticating();
    try {
      final result = await _authRepository
          .login(LoginRequest(email: email, password: password));
      await _sessionStorage.saveSession(
          token: result.token, cliente: result.cliente);
      state = AuthState.authenticated(result.cliente);
    } on AppException catch (error) {
      state = AuthState.error(error);
    }
  }

  Future<void> logout() async {
    await _sessionStorage.clear();
    state = const AuthState.unauthenticated();
  }

  /// Called by `core/network/auth_interceptor.dart` (wired in
  /// `app/providers.dart`) whenever any authenticated request comes back 401
  /// with `codigo` `TOKEN_EXPIRED` or `TOKEN_INVALID`. Guarded so that
  /// several such requests failing at once (e.g. two concurrent authenticated
  /// calls both rejected around the same time) only clear the session once —
  /// the boolean flag is set synchronously, before any `await`, so two
  /// same-tick calls can't both pass the guard.
  void sessionRejectedByServer() {
    if (_isHandlingSessionRejection) return;
    if (state.status != AuthStatus.authenticated) return;

    _isHandlingSessionRejection = true;
    _sessionStorage.clear().then((_) {
      state = const AuthState.unauthenticated();
    }).whenComplete(() => _isHandlingSessionRejection = false);
  }
}
