import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/storage/session_local_storage.dart';
import '../../../core/utils/jwt_utils.dart';
import 'auth_state.dart';
import 'mfa_controller.dart';

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    sessionStorage: ref.watch(sessionLocalStorageProvider),
    clearMfaFlow: () => ref.read(mfaControllerProvider.notifier).abandon(),
  );
});

/// Owns the app's one session state machine. Checking a password and
/// completing MFA are `MfaController`'s job now (`mfa_controller.dart`) —
/// this class only ever knows about a *finished* session: restoring one on
/// launch, adopting one once MFA succeeds ([completeMfaLogin]), and ending
/// one (explicit [logout] or a server-side rejection).
///
/// Restoration is **local-only** by design (no `GET /client/me` exists to
/// call): it trusts a stored token until either the JWT's own `exp` claim
/// looks expired, or the server itself later rejects it with
/// `TOKEN_EXPIRED`/`TOKEN_INVALID` (see [sessionRejectedByServer]). A network
/// failure, a 403, or a 500 must never clear a locally-plausible session —
/// this class never does that.
class AuthController extends StateNotifier<AuthState> {
  final SessionLocalStorage _sessionStorage;
  final void Function() _clearMfaFlow;
  bool _isHandlingSessionRejection = false;

  AuthController({
    required SessionLocalStorage sessionStorage,
    required void Function() clearMfaFlow,
  })  : _sessionStorage = sessionStorage,
        _clearMfaFlow = clearMfaFlow,
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

  /// Called by `MfaController` once `mfa/enroll/confirm` or `mfa/verify`
  /// returns a real session token — this is the **only** place a session
  /// gets created outside restoration. Persists it via the existing
  /// `SessionLocalStorage` exactly like the pre-MFA login used to.
  Future<void> completeMfaLogin(
      {required String token, required ClienteSummary cliente}) async {
    await _sessionStorage.saveSession(token: token, cliente: cliente);
    state = AuthState.authenticated(cliente);
  }

  Future<void> logout() async {
    await _sessionStorage.clear();
    state = const AuthState.unauthenticated();
    // Defensive: a normal logout only ever happens from an already-idle MFA
    // flow (MfaController resets itself right after completeMfaLogin), but
    // this guarantees no pending pre-MFA token/recovery codes can ever
    // survive a logout regardless of how it was triggered.
    _clearMfaFlow();
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
