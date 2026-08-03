import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../data/credits_repository.dart';
import 'credits_state.dart';

final Provider<CreditsRepository> creditsRepositoryProvider =
    Provider<CreditsRepository>((ref) {
  return CreditsRepository(ref.watch(apiClientProvider).dio);
});

/// Recreated whenever the authenticated client's id changes (login,
/// logout, or a different client logging in) — see the `select` below.
/// This is what satisfies "only load with a session" *and* "never leak one
/// session's catalog into the next": on logout the id becomes `null` and a
/// fresh controller (idle, no data) replaces this one; nothing above this
/// provider needs to manually clear anything.
final StateNotifierProvider<CreditsController, CreditsState>
    creditsControllerProvider =
    StateNotifierProvider<CreditsController, CreditsState>((ref) {
  final clienteId =
      ref.watch(authControllerProvider.select((state) => state.cliente?.id));
  final controller = CreditsController(ref.watch(creditsRepositoryProvider));
  if (clienteId != null) {
    controller.loadInitial();
  }
  return controller;
});

/// Single source of truth for the credit catalog. The presentation layer
/// only ever calls [loadInitial]/[retry]/[refresh] — never `Dio` or
/// `CreditsRepository` directly, and never navigates.
class CreditsController extends StateNotifier<CreditsState> {
  final CreditsRepository _repository;
  int _requestSeq = 0;
  bool _hasStartedInitialLoad = false;

  CreditsController(this._repository)
      : super(const CreditsState.initialLoading());

  /// Fires at most once per controller instance — calling it again while
  /// (or after) the first load is in flight is a no-op. A new instance (see
  /// [creditsControllerProvider]) gets a fresh flag, so a genuinely new
  /// session does still load.
  Future<void> loadInitial() async {
    if (_hasStartedInitialLoad) return;
    _hasStartedInitialLoad = true;
    await _fetch();
  }

  /// User-triggered retry from an initial-error state. Same underlying
  /// operation as [refresh]; kept as a distinct name for call-site clarity.
  Future<void> retry() => _fetch();

  /// User-triggered manual refresh from a successful (or refresh-failed)
  /// state. Not blocked from running while another fetch is in flight —
  /// instead, whichever fetch was *started* last wins: see the sequence
  /// check in [_fetch]. Mashing the button repeatedly issues repeated
  /// requests, but only the most recently started one is ever applied to
  /// state, regardless of the order responses arrive in.
  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final mySeq = ++_requestSeq;
    final hasExistingData = state.hasCreditos;
    final previousCreditos = state.creditos;

    state = hasExistingData
        ? CreditsState.refreshing(previousCreditos)
        : const CreditsState.initialLoading();

    try {
      final creditos = await _repository.fetchCreditos();
      if (mySeq != _requestSeq) return; // superseded by a request started later
      state = CreditsState.data(creditos);
    } on AppException catch (error) {
      if (mySeq != _requestSeq) return;
      state = hasExistingData
          ? CreditsState.refreshError(previousCreditos, error)
          : CreditsState.initialError(error);
    }
  }
}
