import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/loans_repository.dart';
import 'loan_detail_state.dart';
import 'loan_submission_controller.dart';

/// One instance per loan id, disposed as soon as nothing watches it anymore
/// (`autoDispose`) — a loan's detail is fetched fresh every time its screen
/// is opened, never cached across visits. `family<..., int>` keys purely on
/// the numeric loan id from the route; there is no cliente-id keying here
/// (unlike `loansListControllerProvider`) because [LoanDetailController]
/// never survives a navigation away from its screen in the first place.
final loanDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<LoanDetailController, LoanDetailState, int>((ref, loanId) {
  return LoanDetailController(ref.watch(loansRepositoryProvider), loanId);
});

/// Fetches `GET /client/prestamos/:id` once on creation. The presentation
/// layer only ever calls [retry] — never `Dio`/`LoansRepository` directly.
class LoanDetailController extends StateNotifier<LoanDetailState> {
  final LoansRepository _repository;
  final int loanId;

  LoanDetailController(this._repository, this.loanId)
      : super(const LoanDetailState.loading()) {
    _fetch();
  }

  Future<void> retry() => _fetch();

  Future<void> _fetch() async {
    state = const LoanDetailState.loading();
    try {
      final detail = await _repository.fetchLoanById(loanId);
      if (!mounted) return;
      state = LoanDetailState.data(detail);
    } on AppException catch (error) {
      if (!mounted) return;
      state = LoanDetailState.error(error);
    }
  }
}
