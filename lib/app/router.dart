import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/mfa_challenge_screen.dart';
import '../features/auth/presentation/mfa_controller.dart';
import '../features/auth/presentation/mfa_enrollment_screen.dart';
import '../features/auth/presentation/mfa_state.dart';
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
const mfaEnrollmentPath = '/mfa/enrolamiento';
const mfaChallengePath = '/mfa/verificacion';
const appHomePath = '/app/inicio';
const simulationPath = '/app/simulacion';
const loanReviewPath = '/app/simulacion/solicitud';
const loanConfirmationPath = '/app/simulacion/confirmacion';

bool _isMfaScreen(String location) =>
    location == mfaEnrollmentPath || location == mfaChallengePath;

/// Pure redirect decision, extracted from `GoRouter.redirect` so the whole
/// state × location matrix is unit-testable without pumping a widget tree.
///
/// Returning `null` means "stay where you are" — critical for avoiding
/// redirect loops (go_router calls this again after every redirect, so
/// returning a location that itself redirects elsewhere would loop).
///
/// The two MFA screens (`mfaEnrollmentPath`/`mfaChallengePath`) are grouped
/// with login/register as "public-like" locations here: reachable while
/// unauthenticated, bounced away from once authenticated. [mfaRedirect]
/// below is what then pins an unauthenticated user to *exactly* the right
/// one of the two while a flow is active, and bounces them off both back to
/// `/login` once it isn't — this function only decides the coarse
/// authenticated-vs-not split, same as before MFA existed.
String? authRedirect(AuthStatus status, String location) {
  final isPublicScreen = location == loginPath ||
      location == registerPath ||
      _isMfaScreen(location);

  if (status == AuthStatus.restoring) {
    return location == splashPath ? null : splashPath;
  }

  if (status == AuthStatus.authenticated) {
    return (isPublicScreen || location == splashPath) ? appHomePath : null;
  }

  // unauthenticated: none of these are an authenticated session, so any
  // non-public route (including a direct deep link into /app or leftover
  // /splash) bounces to /login — mfaRedirect (run right after this, only
  // when this returns null) then decides whether /login itself is really
  // reachable, or whether an active MFA flow pins the user to /mfa/* instead.
  return isPublicScreen ? null : loginPath;
}

/// Guards the two MFA screens, and — while a flow is active — every other
/// unauthenticated location too, including `/login` itself. Only ever
/// consulted once [authRedirect] has already returned `null` (i.e. [status]
/// is `authenticated` and [location] is inside `/app`, or [status] isn't
/// authenticated and [location] is one of login/register/mfa).
///
/// Deliberately takes [authStatus] (not just [phase]) and bails out
/// immediately when it's `authenticated`: `MfaController` resets its phase
/// to idle in the same synchronous call that hands the finished session to
/// `AuthController`, but nothing here should ever risk bouncing a real,
/// authenticated session back into an MFA screen on account of a stale
/// phase read — "una sesión normal no debe volver a MFA" holds
/// unconditionally, not just once the reset has propagated.
String? mfaRedirect(MfaPhase phase, AuthStatus authStatus, String location) {
  if (authStatus == AuthStatus.authenticated) return null;

  if (phase == MfaPhase.idle) {
    return _isMfaScreen(location) ? loginPath : null;
  }

  final target =
      phase == MfaPhase.challengeReady || phase == MfaPhase.challengeVerifying
          ? mfaChallengePath
          : mfaEnrollmentPath;
  return location == target ? null : target;
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
  ref.listen<MfaState>(
      mfaControllerProvider, (previous, next) => refreshNotifier.ping());
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
      final authStatus = ref.read(authControllerProvider).status;
      final authResult = authRedirect(authStatus, location);
      if (authResult != null) return authResult;

      final mfaResult = mfaRedirect(
          ref.read(mfaControllerProvider).phase, authStatus, location);
      if (mfaResult != null) return mfaResult;

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
      GoRoute(
          path: mfaEnrollmentPath,
          builder: (context, state) => const MfaEnrollmentScreen()),
      GoRoute(
          path: mfaChallengePath,
          builder: (context, state) => const MfaChallengeScreen()),
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
