import '../../../core/errors/app_exception.dart';
import '../data/loan_detail.dart';

enum LoanDetailStatus { loading, data, error }

class LoanDetailState {
  final LoanDetailStatus status;
  final PrestamoDetalle? detail;
  final AppException? error;

  const LoanDetailState._({required this.status, this.detail, this.error});

  const LoanDetailState.loading() : this._(status: LoanDetailStatus.loading);

  const LoanDetailState.data(PrestamoDetalle detail)
      : this._(status: LoanDetailStatus.data, detail: detail);

  const LoanDetailState.error(AppException error)
      : this._(status: LoanDetailStatus.error, error: error);
}
