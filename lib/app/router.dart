import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/loans/presentation/loan_confirmation_screen.dart';
import '../features/loans/presentation/loan_detail_screen.dart';
import '../features/loans/presentation/loan_draft.dart';
import '../features/loans/presentation/loan_review_screen.dart';
import '../features/loans/presentation/loan_submission_controller.dart';
import '../features/loans/presentation/loan_submission_state.dart';
import '../screens/calendar_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/root_shell.dart';
import '../screens/simulation_screen.dart';
import '../screens/status_screen.dart';
import 'splash_screen.dart';

const splashPath = '/splash';
const loginPath = '/login';
const registerPath = '/register';
const appHomePath = '/app/inicio';
const simulationPath = '/app/simulacion';
const loanReviewPath = '/app/simulacion/solicitud';
const loanConfirmationPath = '/app/simulacion/confirmacion';

/// Pure redirect decision, extracted from `GoRouter.redirect` so the whole
/// state × location matrix is unit-testable without pumping a widget tree.
///
/// Returning `null` means "stay where you are" — critical for avoiding
/// redirect loops (go_router calls this again after every redirect, so
/// returning a location that itself redirects elsewhere would loop).
String? authRedirect(AuthStatus status, String location) {
  final isAuthScreen = location == loginPath || location == registerPath;

  if (status == AuthStatus.restoring) {
    return location == splashPath ? null : splashPath;
  }

  if (status == AuthStatus.authenticated) {
    return (isAuthScreen || location == splashPath) ? appHomePath : null;
  }

  // unauthenticated, authenticating (mid-submit, still on the login screen)
  // or error (a failed login attempt, still on the login screen): none of
  // these are an authenticated session, so any non-auth route (including a
  // direct deep link into /app or leftover /splash) bounces to /login.
  return isAuthScreen ? null : loginPath;
}

/// Guards the two loan sub-routes. Only ever consulted once [authRedirect]
/// has already returned `null` (i.e. the session itself is fine) — this
/// function doesn't need to know about auth at all.
///
/// Pure and unit-tested in isolation
/// (`test/app/router_redirect_test.dart`), same reasoning as [authRedirect]:
/// a direct deep link or a draft/response that disappeared out from under
/// the user (logout, explicit cancel, a fresh client) must never leave
/// either screen reachable without the data it needs.
String? loanFlowRedirect({
  required String location,
  required bool hasDraft,
  required LoanSubmissionStatus submissionStatus,
}) {
  if (location == loanReviewPath && !hasDraft) {
    return simulationPath;
  }
  if (location == loanConfirmationPath &&
      submissionStatus != LoanSubmissionStatus.success) {
    return simulationPath;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen<AuthState>(
      authControllerProvider, (previous, next) => refreshNotifier.ping());
  ref.listen(
      loanDraftControllerProvider, (previous, next) => refreshNotifier.ping());
  ref.listen<LoanSubmissionState>(
    loanSubmissionControllerProvider,
    (previous, next) => refreshNotifier.ping(),
  );

  return GoRouter(
    initialLocation: splashPath,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authResult =
          authRedirect(ref.read(authControllerProvider).status, location);
      if (authResult != null) return authResult;

      return loanFlowRedirect(
        location: location,
        hasDraft: ref.read(loanDraftControllerProvider) != null,
        submissionStatus: ref.read(loanSubmissionControllerProvider).status,
      );
    },
    routes: [
      GoRoute(
          path: splashPath, builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: loginPath,
        builder: (context, state) =>
            LoginScreen(prefillEmail: state.uri.queryParameters['email']),
      ),
      GoRoute(
          path: registerPath,
          builder: (context, state) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RootShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: appHomePath, builder: (_, __) => const HomeScreen())
          ]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: simulationPath,
                builder: (_, __) => const SimulationScreen(),
                routes: [
                  GoRoute(
                      path: 'solicitud',
                      builder: (_, __) => const LoanReviewScreen()),
                  GoRoute(
                      path: 'confirmacion',
                      builder: (_, __) => const LoanConfirmationScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/app/calendario',
                  builder: (_, __) => const CalendarScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/app/estado',
                builder: (_, __) => const StatusScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => LoanDetailScreen(
                      loanId: int.tryParse(state.pathParameters['id'] ?? ''),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                  path: '/app/perfil',
                  builder: (_, __) => const ProfileScreen())
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod state (auth session, loan draft, loan submission) to
/// go_router's `Listenable`-based `refreshListenable`. Deliberately carries
/// no data of its own — every redirect decision re-reads the current
/// provider state via `ref.read` at redirect time; this only signals "one of
/// the things redirect cares about changed, please re-run it".
class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
