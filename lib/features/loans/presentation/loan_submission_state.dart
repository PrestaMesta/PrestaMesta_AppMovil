import '../../../core/errors/app_exception.dart';
import '../data/loan_submission_response.dart';

/// Explicit statuses — not independent booleans, so "submitting and success
/// at once" simply cannot be represented.
enum LoanSubmissionStatus { idle, submitting, success, failure, outcomeUnknown }

class LoanSubmissionState {
  final LoanSubmissionStatus status;
  final LoanSubmissionResponse? response; // only for success
  final AppException? error; // only for failure
  final String?
      ambiguousRequestId; // only for outcomeUnknown, usually null (see LoanSubmissionAmbiguousException)

  const LoanSubmissionState._({
    required this.status,
    this.response,
    this.error,
    this.ambiguousRequestId,
  });

  const LoanSubmissionState.idle() : this._(status: LoanSubmissionStatus.idle);

  const LoanSubmissionState.submitting()
      : this._(status: LoanSubmissionStatus.submitting);

  const LoanSubmissionState.success(LoanSubmissionResponse response)
      : this._(status: LoanSubmissionStatus.success, response: response);

  const LoanSubmissionState.failure(AppException error)
      : this._(status: LoanSubmissionStatus.failure, error: error);

  const LoanSubmissionState.outcomeUnknown({String? requestId})
      : this._(
            status: LoanSubmissionStatus.outcomeUnknown,
            ambiguousRequestId: requestId);
}
