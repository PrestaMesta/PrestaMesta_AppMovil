import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../credits/data/credit_model.dart';
import '../data/guarantor.dart';

/// In-memory-only draft of a loan request being reviewed — **not** a
/// request, not persisted anywhere (no `flutter_secure_storage`, no disk, no
/// logs). Holds the selected [Credito] itself (not just its id) so the
/// review screen can show name/rate/term without re-fetching, alongside the
/// validated amount carried over from `SimulationScreen` and an optional
/// [Guarantor] being filled in.
class LoanDraft {
  final Credito credito;
  final Decimal montoSolicitado;
  final Guarantor? aval;

  const LoanDraft(
      {required this.credito, required this.montoSolicitado, this.aval});

  LoanDraft withAval(Guarantor? aval) {
    return LoanDraft(
        credito: credito, montoSolicitado: montoSolicitado, aval: aval);
  }
}

/// Null means "no draft" — every screen that depends on a draft treats null
/// as "go back to simulation", never as an empty-but-valid draft.
class LoanDraftController extends StateNotifier<LoanDraft?> {
  LoanDraftController() : super(null);

  void start({required Credito credito, required Decimal montoSolicitado}) {
    state = LoanDraft(credito: credito, montoSolicitado: montoSolicitado);
  }

  void setAval(Guarantor? aval) {
    final current = state;
    if (current == null) return;
    state = current.withAval(aval);
  }

  /// Explicit cancel, successful submission, or session change — see
  /// [loanDraftControllerProvider] for the session-change path, which
  /// recreates this controller entirely rather than calling this method.
  void clear() => state = null;
}

/// Recreated (fresh, `null` draft) whenever the authenticated client
/// changes — same pattern as `creditsControllerProvider`, so a draft can
/// never survive a logout or a different client logging in.
final StateNotifierProvider<LoanDraftController, LoanDraft?>
    loanDraftControllerProvider =
    StateNotifierProvider<LoanDraftController, LoanDraft?>((ref) {
  ref.watch(authControllerProvider.select((state) => state.cliente?.id));
  return LoanDraftController();
});
