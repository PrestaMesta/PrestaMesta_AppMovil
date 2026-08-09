import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/session_local_storage.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../data/mfa_models.dart';
import 'auth_controller.dart';
import 'mfa_state.dart';

const _preMfaTokenInvalidCodes = {'TOKEN_EXPIRED', 'TOKEN_INVALID'};

/// Deliberate circular import, same shape and same reason as the documented
/// `app/providers.dart` ↔ `auth_controller.dart` cycle: `AuthController`
/// needs `mfaControllerProvider` (to clear any pending MFA flow on logout)
/// and `MfaController` needs `authControllerProvider` (to hand off the
/// finished session via `completeMfaLogin`). Both providers below carry an
/// explicit variable-level type annotation for the same reason documented on
/// the other cycle: without it, `flutter analyze` reports a `top_level_cycle`
/// error.
final StateNotifierProvider<MfaController, MfaState> mfaControllerProvider =
    StateNotifierProvider<MfaController, MfaState>((ref) {
  return MfaController(
    authRepository: ref.watch(authRepositoryProvider),
    completeMfaLogin: ({required token, required cliente}) => ref
        .read(authControllerProvider.notifier)
        .completeMfaLogin(token: token, cliente: cliente),
  );
});

/// Owns the whole pre-session flow: password check → (enrollment or
/// challenge) → real session. See `mfa_state.dart` for the state shape and
/// the storage decision (in-memory only, documented there).
///
/// Every method guards against double submission by checking [MfaState.phase]
/// before doing anything — the UI disabling its button is defense in depth,
/// not the only protection, same convention as `AuthController.login` (now
/// removed) and `LoanSubmissionController.submit` used.
class MfaController extends StateNotifier<MfaState> {
  final AuthRepository _authRepository;
  final Future<void> Function(
      {required String token,
      required ClienteSummary cliente}) _completeMfaLogin;

  MfaController({
    required AuthRepository authRepository,
    required Future<void> Function(
            {required String token, required ClienteSummary cliente})
        completeMfaLogin,
  })  : _authRepository = authRepository,
        _completeMfaLogin = completeMfaLogin,
        super(const MfaState.idle());

  Future<void> loginWithPassword(
      {required String email, required String password}) async {
    if (state.phase != MfaPhase.idle) return;

    state = const MfaState.loggingIn();
    try {
      final result = await _authRepository
          .login(LoginRequest(email: email, password: password));
      if (!mounted) return;
      if (result.siguientePaso == SiguientePasoMfa.enrollmentRequired) {
        await _startEnrollment(result.preMfaToken);
      } else {
        state = MfaState.challengeReady(preMfaToken: result.preMfaToken);
      }
    } on AppException catch (error) {
      if (!mounted) return;
      state = MfaState.idle(error: error);
    }
  }

  Future<void> _startEnrollment(String preMfaToken) async {
    state = MfaState.enrollmentStarting(preMfaToken);
    try {
      final result = await _authRepository.mfaEnroll(preMfaToken);
      if (!mounted) return;
      state = MfaState.enrollmentReady(
        preMfaToken: preMfaToken,
        secreto: result.secreto,
        otpauthUri: result.otpauthUri,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      if (_isPreMfaTokenInvalid(error)) {
        state = const MfaState.idle(sessionExpiredNotice: _expiredMessage);
        return;
      }
      // Self-heal per openapi.yaml: an ENROLLMENT_REQUIRED siguientePaso can
      // race an account whose MFA became ACTIVO in the meantime — the server
      // then answers 409 MFA_CHALLENGE_REQUIRED instead. Fall through to the
      // challenge screen with the same still-valid preMfaToken rather than
      // showing a dead-end error.
      if (error.codigo == 'MFA_CHALLENGE_REQUIRED') {
        state = MfaState.challengeReady(preMfaToken: preMfaToken);
        return;
      }
      state = MfaState.idle(error: error);
    }
  }

  Future<void> confirmEnrollment(String codigo) async {
    final current = state;
    if (current.phase != MfaPhase.enrollmentReady) return;
    final preMfaToken = current.preMfaToken!;
    final secreto = current.secreto!;
    final otpauthUri = current.otpauthUri!;

    state = MfaState.enrollmentConfirming(
        preMfaToken: preMfaToken, secreto: secreto, otpauthUri: otpauthUri);
    try {
      final result = await _authRepository.mfaEnrollConfirm(
          preMfaToken, MfaEnrollConfirmRequest(codigo: codigo));
      if (!mounted) return;
      final codes = result.codigosRecuperacion ?? const <String>[];
      state = MfaState.recoveryCodesPendingAck(
        recoveryCodes: codes,
        pendingToken: result.token,
        pendingCliente: result.cliente,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      if (_isPreMfaTokenInvalid(error)) {
        state = const MfaState.idle(sessionExpiredNotice: _expiredMessage);
        return;
      }
      state = MfaState.enrollmentReady(
        preMfaToken: preMfaToken,
        secreto: secreto,
        otpauthUri: otpauthUri,
        error: error,
      );
    }
  }

  /// The confirmation gate: only once the caller (the recovery-codes screen)
  /// has affirmatively confirmed the user saved [MfaState.recoveryCodes] does
  /// this hand the already-issued session off to `AuthController` — and only
  /// then does this app ever let the router into `/app`. The codes are gone
  /// from memory the instant this returns (a fresh `MfaState.idle()`), since
  /// they were never written anywhere else.
  Future<void> acknowledgeRecoveryCodesSaved() async {
    final current = state;
    if (current.phase != MfaPhase.recoveryCodesPendingAck) return;
    final token = current.pendingTokenForAck!;
    final cliente = current.pendingClienteForAck!;

    await _completeMfaLogin(token: token, cliente: cliente);
    if (!mounted) return;
    state = const MfaState.idle();
  }

  Future<void> verifyChallenge({String? totp, String? recoveryCode}) async {
    final current = state;
    if (current.phase != MfaPhase.challengeReady) return;
    assert((totp == null) != (recoveryCode == null),
        'exactly one of totp/recoveryCode must be provided');
    final preMfaToken = current.preMfaToken!;

    state = MfaState.challengeVerifying(preMfaToken);
    try {
      final request = totp != null
          ? MfaVerifyRequest.totp(totp)
          : MfaVerifyRequest.recoveryCode(recoveryCode!);
      final result = await _authRepository.mfaVerify(preMfaToken, request);
      if (!mounted) return;
      await _completeMfaLogin(token: result.token, cliente: result.cliente);
      if (!mounted) return;
      state = const MfaState.idle();
    } on AppException catch (error) {
      if (!mounted) return;
      if (_isPreMfaTokenInvalid(error)) {
        state = const MfaState.idle(sessionExpiredNotice: _expiredMessage);
        return;
      }
      state = MfaState.challengeReady(preMfaToken: preMfaToken, error: error);
    }
  }

  /// Cancels whatever step of the flow is in progress and returns to
  /// `/login` — used both by an explicit "cancelar" action on the MFA
  /// screens and by `AuthController.logout()` (defensive: a normal logout
  /// should never find an active MFA flow, since this controller already
  /// resets itself right after `completeMfaLogin`, but this guarantees it
  /// regardless).
  void abandon() {
    if (state.phase == MfaPhase.idle) return;
    state = const MfaState.idle();
  }

  void dismissExpiredNotice() {
    if (state.phase == MfaPhase.idle && state.sessionExpiredNotice != null) {
      state = const MfaState.idle();
    }
  }

  bool _isPreMfaTokenInvalid(AppException error) =>
      error.statusCode == 401 &&
      error.codigo != null &&
      _preMfaTokenInvalidCodes.contains(error.codigo);

  static const _expiredMessage =
      'Tu verificación expiró. Inicia sesión de nuevo.';
}
