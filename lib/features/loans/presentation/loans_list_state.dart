import '../../../core/errors/app_exception.dart';
import '../data/loan_list_item.dart';
import '../data/pagination.dart';

/// Explicit states for `GET /client/prestamos`, same shape as
/// `features/credits/presentation/credits_state.dart#CreditsStatus`:
/// `refreshing`/`refreshError` retain the last page's [loans]/[pagination]
/// instead of blanking the screen while a manual refresh or page change is
/// in flight. "Empty" is deliberately not a separate status — see [isEmpty].
enum LoansListStatus {
  initialLoading,
  data,
  initialError,
  refreshing,
  refreshError
}

class LoansListState {
  final LoansListStatus status;
  final List<PrestamoListItem> loans;
  final Pagination? pagination;
  final AppException? error;

  const LoansListState._({
    required this.status,
    this.loans = const [],
    this.pagination,
    this.error,
  });

  const LoansListState.initialLoading()
      : this._(status: LoansListStatus.initialLoading);

  const LoansListState.data(List<PrestamoListItem> loans, Pagination pagination)
      : this._(
            status: LoansListStatus.data, loans: loans, pagination: pagination);

  const LoansListState.initialError(AppException error)
      : this._(status: LoansListStatus.initialError, error: error);

  const LoansListState.refreshing(
      List<PrestamoListItem> loans, Pagination? pagination)
      : this._(
            status: LoansListStatus.refreshing,
            loans: loans,
            pagination: pagination);

  const LoansListState.refreshError(
      List<PrestamoListItem> loans, Pagination? pagination, AppException error)
      : this._(
            status: LoansListStatus.refreshError,
            loans: loans,
            pagination: pagination,
            error: error);

  bool get isEmpty => status == LoansListStatus.data && loans.isEmpty;

  bool get hasLoans =>
      status == LoansListStatus.data ||
      status == LoansListStatus.refreshing ||
      status == LoansListStatus.refreshError;

  bool get isBusy =>
      status == LoansListStatus.initialLoading ||
      status == LoansListStatus.refreshing;

  bool get hasNextPage =>
      pagination != null && pagination!.page < pagination!.totalPages;

  bool get hasPreviousPage => pagination != null && pagination!.page > 1;

  /// The most recently submitted loan on the current page — server-sorted
  /// (`fecha_solicitud DESC, id DESC`), so this is exactly `loans.first` on
  /// page 1. `null` while loading/erroring or once loans genuinely is empty.
  PrestamoListItem? get mostRecent => loans.isEmpty ? null : loans.first;
}
