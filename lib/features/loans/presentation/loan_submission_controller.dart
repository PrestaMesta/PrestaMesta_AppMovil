import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/loan_request.dart';
import '../data/loans_repository.dart';
import 'loan_submission_state.dart';

final Provider<LoansRepository> loansRepositoryProvider =
    Provider<LoansRepository>((ref) {
  return LoansRepository(ref.watch(apiClientProvider).dio);
});

/// Recreated whenever the authenticated client changes — same reasoning as
/// `loanDraftControllerProvider`/`creditsControllerProvider`: an
/// `outcomeUnknown` block or a stale `success` from a previous session must
/// never carry over into a new one.
final StateNotifierProvider<LoanSubmissionController, LoanSubmissionState>
    loanSubmissionControllerProvider =
    StateNotifierProvider<LoanSubmissionController, LoanSubmissionState>((ref) {
  ref.watch(authControllerProvider.select((state) => state.cliente?.id));
  return LoanSubmissionController(ref.watch(loansRepositoryProvider));
});

/// One submission attempt per controller instance, end to end. The
/// presentation layer only ever calls [submit] — never `Dio`/
/// `LoansRepository` directly, and this class never navigates
/// (`BuildContext` never appears here).
class LoanSubmissionController extends StateNotifier<LoanSubmissionState> {
  final LoansRepository _repository;

  /// Set once, permanently, the first time a submission's outcome is
  /// ambiguous. There is no "unblock" method: the backend has no
  /// idempotency support, so the only safe way to try again is a
  /// deliberate, conscious new attempt — which in this app means going back
  /// to simulation and starting a fresh review (a fresh `LoanDraft`, and
  /// because of the `authControllerProvider`-keyed provider above, a fresh
  /// controller too, in practice, on the next real navigation cycle).
  bool _permanentlyBlockedAfterAmbiguousOutcome = false;

  LoanSubmissionController(this._repository)
      : super(const LoanSubmissionState.idle());

  Future<void> submit(LoanRequest request) async {
    if (state.status == LoanSubmissionStatus.submitting) return;
    if (state.status == LoanSubmissionStatus.success) return;
    if (_permanentlyBlockedAfterAmbiguousOutcome) return;

    state = const LoanSubmissionState.submitting();
    try {
      final response = await _repository.submit(request);
      // A TOKEN_EXPIRED/TOKEN_INVALID on *this same request* clears the
      // session concurrently (core/network/auth_interceptor.dart ->
      // AuthController.sessionRejectedByServer), and this controller is
      // keyed off the authenticated client id — so it can already be
      // disposed by the time this line runs. There's nothing meaningful
      // left to update in that case (the router is already sending the user
      // to /login), so this just avoids crashing instead of pretending a
      // disposed controller's state still matters.
      if (!mounted) return;
      state = LoanSubmissionState.success(response);
    } on LoanSubmissionAmbiguousException catch (error) {
      if (!mounted) return;
      _permanentlyBlockedAfterAmbiguousOutcome = true;
      state = LoanSubmissionState.outcomeUnknown(requestId: error.requestId);
    } on AppException catch (error) {
      if (!mounted) return;
      state = LoanSubmissionState.failure(error);
    }
  }
}
