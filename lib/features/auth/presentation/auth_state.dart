import '../../../core/errors/app_exception.dart';
import '../../../core/storage/session_local_storage.dart';

/// The five session states this app distinguishes — deliberately a single
/// enum plus payload, not a handful of independent booleans (which could
/// otherwise represent nonsensical combinations like "authenticated and
/// restoring at the same time").
enum AuthStatus {
  restoring,
  unauthenticated,
  authenticating,
  authenticated,
  error
}

class AuthState {
  final AuthStatus status;
  final ClienteSummary? cliente;
  final AppException? error;

  const AuthState._({required this.status, this.cliente, this.error});

  const AuthState.restoring() : this._(status: AuthStatus.restoring);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  const AuthState.authenticating() : this._(status: AuthStatus.authenticating);

  const AuthState.authenticated(ClienteSummary cliente)
      : this._(status: AuthStatus.authenticated, cliente: cliente);

  const AuthState.error(AppException error)
      : this._(status: AuthStatus.error, error: error);

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  String toString() =>
      'AuthState(status: $status, cliente: ${cliente?.id}, error: ${error?.type})';
}
