import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum RegisterStatus { idle, submitting, success, error }

class RegisterState {
  final RegisterStatus status;
  final int? clienteId;
  final AppException? error;

  const RegisterState._({required this.status, this.clienteId, this.error});

  const RegisterState.idle() : this._(status: RegisterStatus.idle);
  const RegisterState.submitting() : this._(status: RegisterStatus.submitting);
  const RegisterState.success(int clienteId)
      : this._(status: RegisterStatus.success, clienteId: clienteId);
  const RegisterState.error(AppException error)
      : this._(status: RegisterStatus.error, error: error);
}

/// Registration never touches the session (no token comes back from
/// `POST /client/auth/register`), so this is intentionally a separate,
/// disposable notifier — not another branch of [AuthState], which is only
/// about the logged-in session.
final registerControllerProvider =
    StateNotifierProvider.autoDispose<RegisterController, RegisterState>((ref) {
  return RegisterController(ref.watch(authRepositoryProvider));
});

class RegisterController extends StateNotifier<RegisterState> {
  final AuthRepository _authRepository;

  RegisterController(this._authRepository) : super(const RegisterState.idle());

  Future<void> submit({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    if (state.status == RegisterStatus.submitting) return;

    state = const RegisterState.submitting();
    try {
      final result = await _authRepository.register(
        RegisterRequest(
            nombre: nombre,
            email: email,
            password: password,
            telefono: telefono),
      );
      state = RegisterState.success(result.clienteId);
    } on AppException catch (error) {
      state = RegisterState.error(error);
    }
  }

  void reset() => state = const RegisterState.idle();
}
