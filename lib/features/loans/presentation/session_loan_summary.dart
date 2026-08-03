import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/loan_submission_response.dart';
import 'loan_submission_controller.dart';
import 'loan_submission_state.dart';

/// Holds only the most recent **successful** [LoanSubmissionResponse] from
/// this session — in memory only, never persisted (no secure storage, no
/// disk, no logs), never recalculated, never presented as a query against
/// the server (there is no `GET` for a client's own loans). `null` means "no
/// submission succeeded yet this session," the only state Home/StatusScreen
/// check.
///
/// This is populated reactively (see [sessionLoanSummaryControllerProvider])
/// by observing [loanSubmissionControllerProvider] rather than by any screen
/// explicitly pushing data into it — no additional network request is ever
/// made to build this state.
///
/// Like any Riverpod provider, this only observes transitions from the
/// moment something starts watching it — it has no way to retroactively
/// learn about a success that happened before it existed. In this app that
/// is never a real gap: `authRedirect` (`app/router.dart`) always lands an
/// authenticated session on `/app/inicio` first, and `HomeScreen` watches
/// this provider, so it (and therefore this listener) is alive well before
/// the user can reach Simulación and submit anything.
///
/// This also means the provider needs to stay *actively* watched (a
/// `ConsumerWidget`'s `ref.watch`, or `ProviderContainer.listen` in a test —
/// not a one-off `read`) for its own client-id-keyed recreation to happen
/// promptly: a passive `read` only rebuilds this provider lazily on the
/// *next* read, which could be after a submission already completed and was
/// missed. `HomeScreen`/`StatusScreen` being kept alive by the shell (see
/// `RootShell`) is what guarantees the active-watch condition in practice.
class SessionLoanSummaryController
    extends StateNotifier<LoanSubmissionResponse?> {
  SessionLoanSummaryController() : super(null);

  void _recordSuccess(LoanSubmissionResponse response) {
    state = response;
  }
}

/// Recreated (fresh, `null`) whenever the authenticated client changes —
/// same session-keying pattern as `loanDraftControllerProvider`/
/// `creditsControllerProvider`, so a previous client's (or a previous
/// session's) last submission can never leak into a new login. The `ref
/// .listen` below is what actually populates this controller: it observes
/// [loanSubmissionControllerProvider] and copies its response over only on a
/// transition into [LoanSubmissionStatus.success] — a failed or ambiguous
/// submission never touches this state at all.
final StateNotifierProvider<SessionLoanSummaryController,
        LoanSubmissionResponse?> sessionLoanSummaryControllerProvider =
    StateNotifierProvider<SessionLoanSummaryController,
        LoanSubmissionResponse?>((ref) {
  ref.watch(authControllerProvider.select((state) => state.cliente?.id));
  final controller = SessionLoanSummaryController();
  ref.listen<LoanSubmissionState>(
    loanSubmissionControllerProvider,
    (previous, next) {
      if (next.status == LoanSubmissionStatus.success &&
          next.response != null) {
        controller._recordSuccess(next.response!);
      }
    },
  );
  return controller;
});
