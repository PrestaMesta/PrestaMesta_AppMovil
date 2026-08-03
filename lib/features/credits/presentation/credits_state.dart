import '../../../core/errors/app_exception.dart';
import '../data/credit_model.dart';

/// Explicit catalog states — not a handful of independent booleans, which
/// could otherwise represent nonsensical combinations (e.g. "loading" and
/// "has an error" at once). `refreshing`/`refreshError` both retain
/// [creditos] from the last successful load — a background refresh must
/// never blank out data the user is already looking at.
///
/// "Empty catalog" is deliberately **not** a separate status: it's
/// `data` with an empty [creditos] list — fully derivable from the data
/// itself, and not a distinct case the state machine needs to track. See
/// [isEmpty].
enum CreditsStatus {
  initialLoading,
  data,
  initialError,
  refreshing,
  refreshError
}

class CreditsState {
  final CreditsStatus status;
  final List<Credito> creditos;
  final AppException? error;

  const CreditsState._(
      {required this.status, this.creditos = const [], this.error});

  const CreditsState.initialLoading()
      : this._(status: CreditsStatus.initialLoading);

  const CreditsState.data(List<Credito> creditos)
      : this._(status: CreditsStatus.data, creditos: creditos);

  const CreditsState.initialError(AppException error)
      : this._(status: CreditsStatus.initialError, error: error);

  const CreditsState.refreshing(List<Credito> creditos)
      : this._(status: CreditsStatus.refreshing, creditos: creditos);

  const CreditsState.refreshError(List<Credito> creditos, AppException error)
      : this._(
            status: CreditsStatus.refreshError,
            creditos: creditos,
            error: error);

  bool get isEmpty => status == CreditsStatus.data && creditos.isEmpty;

  /// True whenever there's a last-known-good list to show (data itself, or
  /// a refresh in progress/failed on top of it) — used by the UI to decide
  /// whether to render cards-plus-banner instead of a full-screen state.
  bool get hasCreditos =>
      status == CreditsStatus.data ||
      status == CreditsStatus.refreshing ||
      status == CreditsStatus.refreshError;
}
