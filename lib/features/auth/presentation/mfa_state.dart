import '../../../core/errors/app_exception.dart';
import '../../../core/storage/session_local_storage.dart';

/// One-dimensional status for the whole pre-session MFA flow — same
/// convention as `AuthStatus`/`LoansListStatus` elsewhere in this app: a
/// single enum the screens/router switch on, never a handful of booleans
/// layered on top of each other. Each in-flight phase (`loggingIn`,
/// `enrollmentStarting`, `enrollmentConfirming`, `challengeVerifying`) is its
/// own value specifically so `MfaController`'s double-submit guards and the
/// screens' "show a spinner, disable the button" logic can both just check
/// `phase`, without a second orthogonal `isSubmitting` flag.
enum MfaPhase {
  /// No MFA flow in progress: either nothing has happened yet, or the last
  /// one finished (success, abandoned, or the `preMfaToken` expired).
  idle,

  /// `POST /client/auth/login` in flight (checking the password).
  loggingIn,

  /// `POST /client/auth/mfa/enroll` in flight, auto-triggered right after a
  /// login response says `siguientePaso: MFA_ENROLLMENT_REQUIRED` — there is
  /// nothing for the user to decide before this call, so it isn't gated on a
  /// button tap.
  enrollmentStarting,

  /// `secreto`/`otpauthUri` received; waiting for the user's first 6-digit
  /// TOTP code.
  enrollmentReady,

  /// `POST /client/auth/mfa/enroll/confirm` in flight.
  enrollmentConfirming,

  /// Enrollment confirmed — the server already returned the session token
  /// and the one-time recovery codes, but neither is persisted or handed to
  /// `AuthController` yet. The user must explicitly acknowledge the codes
  /// were saved (see [MfaState.recoveryCodes]) before this app will ever
  /// call `AuthController.completeMfaLogin` and let the router into `/app`.
  recoveryCodesPendingAck,

  /// `siguientePaso: MFA_CHALLENGE_REQUIRED` — waiting for a TOTP or a
  /// recovery code.
  challengeReady,

  /// `POST /client/auth/mfa/verify` in flight.
  challengeVerifying,
}

/// Temporary, pre-session MFA state — deliberately separate from
/// [AuthState] (`auth_state.dart`), which only ever describes a *finished*
/// session. Everything here is discarded the moment the flow ends one way or
/// another (success, abandonment, or `preMfaToken` expiry); nothing in this
/// class is ever written to `SessionLocalStorage` or any other disk-backed
/// storage.
///
/// **Storage decision — in-memory only, not secure storage:**
/// `preMfaToken` and the recovery codes never leave process memory, the same
/// choice already made for `LoanDraft`
/// (`features/loans/presentation/loan_draft.dart`). The alternative — a
/// short-lived secure-storage entry so an Android process recreation (a rare
/// low-memory kill, not a normal backgrounding) could resume mid-flow — was
/// deliberately rejected:
/// - The server's own `preMfaToken` lifetime is short (`PRE_MFA_EXPIRES_IN`,
///   default 5 minutes), so losing it to a process recreation just forces a
///   fresh login — an acceptable, safe fallback, not a broken flow.
/// - The recovery codes are explicitly required (by this checkpoint's own
///   spec) to be memory-only and shown exactly once; persisting them
///   anywhere, even briefly, even encrypted, works against that guarantee
///   and adds cleanup logic that can fail open.
/// - `preMfaToken` cannot reach any business route (`mfa/enroll(/confirm)`
///   and `mfa/verify` only) and expires quickly, so the attack surface added
///   by persisting it would outweigh the UX benefit of surviving a rare
///   process kill.
class MfaState {
  final MfaPhase phase;
  final String? preMfaToken;
  final String? secreto;
  final String? otpauthUri;
  final List<String>? recoveryCodes;
  final AppException? error;

  /// Set only when a `TOKEN_EXPIRED`/`TOKEN_INVALID` response is received for
  /// the `preMfaToken` (i.e. the flow can no longer continue and must start
  /// over from login) — read once by `LoginScreen` and cleared via
  /// `MfaController.dismissExpiredNotice()`.
  final String? sessionExpiredNotice;

  /// Session data already returned by `mfa/enroll/confirm`, held here (never
  /// persisted) until [MfaController.acknowledgeRecoveryCodesSaved] confirms
  /// the user saved [recoveryCodes] — only then is it hand off to
  /// `AuthController.completeMfaLogin`.
  final String? _pendingToken;
  final ClienteSummary? _pendingCliente;

  const MfaState._({
    required this.phase,
    this.preMfaToken,
    this.secreto,
    this.otpauthUri,
    this.recoveryCodes,
    this.error,
    this.sessionExpiredNotice,
    String? pendingToken,
    ClienteSummary? pendingCliente,
  })  : _pendingToken = pendingToken,
        _pendingCliente = pendingCliente;

  const MfaState.idle({String? sessionExpiredNotice, AppException? error})
      : this._(
          phase: MfaPhase.idle,
          sessionExpiredNotice: sessionExpiredNotice,
          error: error,
        );

  const MfaState.loggingIn() : this._(phase: MfaPhase.loggingIn);

  const MfaState.enrollmentStarting(String preMfaToken)
      : this._(phase: MfaPhase.enrollmentStarting, preMfaToken: preMfaToken);

  const MfaState.enrollmentReady({
    required String preMfaToken,
    required String secreto,
    required String otpauthUri,
    AppException? error,
  }) : this._(
          phase: MfaPhase.enrollmentReady,
          preMfaToken: preMfaToken,
          secreto: secreto,
          otpauthUri: otpauthUri,
          error: error,
        );

  const MfaState.enrollmentConfirming({
    required String preMfaToken,
    required String secreto,
    required String otpauthUri,
  }) : this._(
          phase: MfaPhase.enrollmentConfirming,
          preMfaToken: preMfaToken,
          secreto: secreto,
          otpauthUri: otpauthUri,
        );

  const MfaState.recoveryCodesPendingAck({
    required List<String> recoveryCodes,
    required String pendingToken,
    required ClienteSummary pendingCliente,
  }) : this._(
          phase: MfaPhase.recoveryCodesPendingAck,
          recoveryCodes: recoveryCodes,
          pendingToken: pendingToken,
          pendingCliente: pendingCliente,
        );

  const MfaState.challengeReady({
    required String preMfaToken,
    AppException? error,
  }) : this._(
          phase: MfaPhase.challengeReady,
          preMfaToken: preMfaToken,
          error: error,
        );

  const MfaState.challengeVerifying(String preMfaToken)
      : this._(phase: MfaPhase.challengeVerifying, preMfaToken: preMfaToken);

  String? get pendingTokenForAck => _pendingToken;
  ClienteSummary? get pendingClienteForAck => _pendingCliente;

  bool get isEnrollmentPhase =>
      phase == MfaPhase.enrollmentStarting ||
      phase == MfaPhase.enrollmentReady ||
      phase == MfaPhase.enrollmentConfirming ||
      phase == MfaPhase.recoveryCodesPendingAck;

  bool get isChallengePhase =>
      phase == MfaPhase.challengeReady || phase == MfaPhase.challengeVerifying;

  bool get isActive => phase != MfaPhase.idle;

  bool get isBusy =>
      phase == MfaPhase.loggingIn ||
      phase == MfaPhase.enrollmentStarting ||
      phase == MfaPhase.enrollmentConfirming ||
      phase == MfaPhase.challengeVerifying;
}
