import '../../../core/storage/session_local_storage.dart';

/// The three session states this app distinguishes. Checking the password
/// and completing MFA no longer happen here — see `mfa_state.dart`/
/// `mfa_controller.dart` — so this class only ever describes whether a real,
/// finished session exists, never a password check or an MFA step in
/// progress.
enum AuthStatus { restoring, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final ClienteSummary? cliente;

  const AuthState._({required this.status, this.cliente});

  const AuthState.restoring() : this._(status: AuthStatus.restoring);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(ClienteSummary cliente)
      : this._(status: AuthStatus.authenticated, cliente: cliente);

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  String toString() => 'AuthState(status: $status, cliente: ${cliente?.id})';
}
