import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/loans_repository.dart';
import 'loan_submission_controller.dart';
import 'loan_submission_state.dart';
import 'loans_list_state.dart';

const _pageLimit = 20;

/// Recreated whenever the authenticated client's id changes — same
/// session-keying pattern as `creditsControllerProvider`/
/// `loanDraftControllerProvider`: a previous client's loans (or a previous
/// session's) must never leak into a new login.
///
/// The `ref.listen` below is what satisfies "después de enviar una solicitud
/// exitosa, refresca la lista de préstamos": it observes
/// [loanSubmissionControllerProvider] and re-fetches page 1 only on a
/// transition into [LoanSubmissionStatus.success] — same reactive shape as
/// the (now-removed) `SessionLoanSummaryController`, except this refetches
/// from the server instead of caching the POST response locally, so the
/// server stays the single source of truth. Like that provider, this one
/// needs to stay *actively* watched (`ref.watch`, not a one-off `read`) for
/// its own client-id-keyed recreation to happen promptly — `HomeScreen`
/// watching it early (same as before) is what guarantees that in practice.
final StateNotifierProvider<LoansListController, LoansListState>
    loansListControllerProvider =
    StateNotifierProvider<LoansListController, LoansListState>((ref) {
  final clienteId =
      ref.watch(authControllerProvider.select((state) => state.cliente?.id));
  final controller = LoansListController(ref.watch(loansRepositoryProvider));
  if (clienteId != null) {
    controller.loadInitial();
  }
  ref.listen<LoanSubmissionState>(
    loanSubmissionControllerProvider,
    (previous, next) {
      if (next.status == LoanSubmissionStatus.success) {
        controller.refreshAfterSubmission();
      }
    },
  );
  return controller;
});

/// Single source of truth for the client's own loans
/// (`GET /client/prestamos`). The presentation layer only ever calls
/// [loadInitial]/[retry]/[refresh]/[nextPage]/[previousPage] — never `Dio`
/// or [LoansRepository] directly, and never navigates.
class LoansListController extends StateNotifier<LoansListState> {
  final LoansRepository _repository;
  int _requestSeq = 0;
  bool _hasStartedInitialLoad = false;

  LoansListController(this._repository)
      : super(const LoansListState.initialLoading());

  /// Fires at most once per controller instance — a new instance (a new
  /// client id) gets a fresh flag, so a genuinely new session still loads.
  Future<void> loadInitial() async {
    if (_hasStartedInitialLoad) return;
    _hasStartedInitialLoad = true;
    await _fetch(page: 1);
  }

  /// User-triggered retry from an initial-error state.
  Future<void> retry() => _fetch(page: 1);

  /// User-triggered manual refresh of whatever page is currently displayed —
  /// this app never auto-polls. Not blocked from running while another fetch
  /// is in flight: whichever fetch was *started* last wins (see [_fetch]).
  Future<void> refresh() => _fetch(page: state.pagination?.page ?? 1);

  /// Always jumps to page 1, regardless of the currently displayed page —
  /// called only by [loansListControllerProvider]'s `ref.listen` after a
  /// successful submission, so the just-created loan (sorted first by the
  /// server) is immediately visible.
  Future<void> refreshAfterSubmission() => _fetch(page: 1);

  Future<void> nextPage() async {
    final pagination = state.pagination;
    if (pagination == null || pagination.page >= pagination.totalPages) return;
    await _fetch(page: pagination.page + 1);
  }

  Future<void> previousPage() async {
    final pagination = state.pagination;
    if (pagination == null || pagination.page <= 1) return;
    await _fetch(page: pagination.page - 1);
  }

  Future<void> _fetch({required int page}) async {
    final mySeq = ++_requestSeq;
    final hasExistingData = state.hasLoans;
    final previousLoans = state.loans;
    final previousPagination = state.pagination;

    state = hasExistingData
        ? LoansListState.refreshing(previousLoans, previousPagination)
        : const LoansListState.initialLoading();

    try {
      final result =
          await _repository.fetchLoans(page: page, limit: _pageLimit);
      if (mySeq != _requestSeq) return; // superseded by a request started later
      state = LoansListState.data(result.data, result.pagination);
    } on AppException catch (error) {
      if (mySeq != _requestSeq) return;
      state = hasExistingData
          ? LoansListState.refreshError(
              previousLoans, previousPagination, error)
          : LoansListState.initialError(error);
    }
  }
}
