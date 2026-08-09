import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/app/router.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_state.dart';
import 'package:prestamesta_app/features/auth/presentation/mfa_state.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_state.dart';

void main() {
  group('authRedirect: restoring', () {
    test('splash stays put', () {
      expect(authRedirect(AuthStatus.restoring, splashPath), isNull);
    });

    test('any other location bounces to splash', () {
      expect(authRedirect(AuthStatus.restoring, loginPath), splashPath);
      expect(authRedirect(AuthStatus.restoring, appHomePath), splashPath);
      expect(authRedirect(AuthStatus.restoring, '/app/perfil'), splashPath);
      expect(authRedirect(AuthStatus.restoring, mfaEnrollmentPath), splashPath);
    });
  });

  group('authRedirect: unauthenticated', () {
    test('login/register/mfa screens stay put', () {
      expect(authRedirect(AuthStatus.unauthenticated, loginPath), isNull);
      expect(authRedirect(AuthStatus.unauthenticated, registerPath), isNull);
      expect(
          authRedirect(AuthStatus.unauthenticated, mfaEnrollmentPath), isNull);
      expect(
          authRedirect(AuthStatus.unauthenticated, mfaChallengePath), isNull);
    });

    test('a direct /app deep link bounces to login', () {
      expect(authRedirect(AuthStatus.unauthenticated, appHomePath), loginPath);
      expect(
          authRedirect(AuthStatus.unauthenticated, '/app/perfil'), loginPath);
    });

    test('splash bounces to login (restore just finished, no session)', () {
      expect(authRedirect(AuthStatus.unauthenticated, splashPath), loginPath);
    });
  });

  group('authRedirect: authenticated', () {
    test('login bounces to the app home', () {
      expect(authRedirect(AuthStatus.authenticated, loginPath), appHomePath);
    });

    test('register bounces to the app home', () {
      expect(authRedirect(AuthStatus.authenticated, registerPath), appHomePath);
    });

    test(
        'the MFA screens bounce to the app home too — "una sesión normal no '
        'debe volver a MFA"', () {
      expect(authRedirect(AuthStatus.authenticated, mfaEnrollmentPath),
          appHomePath);
      expect(authRedirect(AuthStatus.authenticated, mfaChallengePath),
          appHomePath);
    });

    test('splash bounces to the app home', () {
      expect(authRedirect(AuthStatus.authenticated, splashPath), appHomePath);
    });

    test('an /app/* location stays put (no redirect loop)', () {
      expect(authRedirect(AuthStatus.authenticated, appHomePath), isNull);
      expect(authRedirect(AuthStatus.authenticated, '/app/perfil'), isNull);
      expect(authRedirect(AuthStatus.authenticated, '/app/simulacion'), isNull);
    });
  });

  group('mfaRedirect: authenticated status always wins (bails out early)', () {
    test(
        'never redirects into an MFA screen once authenticated, regardless '
        'of a stale/leftover phase', () {
      for (final phase in MfaPhase.values) {
        expect(
          mfaRedirect(phase, AuthStatus.authenticated, appHomePath),
          isNull,
          reason: 'phase=$phase',
        );
      }
    });

    test(
        'never sends an authenticated status back into /mfa/enrolamiento or '
        '/mfa/verificacion either, even if that is the current location and '
        'the phase is still (stale-)active — authenticated must never enter '
        'any /mfa/* route', () {
      for (final phase in MfaPhase.values) {
        expect(
          mfaRedirect(phase, AuthStatus.authenticated, mfaEnrollmentPath),
          isNull,
          reason: 'phase=$phase at mfaEnrollmentPath',
        );
        expect(
          mfaRedirect(phase, AuthStatus.authenticated, mfaChallengePath),
          isNull,
          reason: 'phase=$phase at mfaChallengePath',
        );
      }
    });
  });

  group('mfaRedirect: idle phase (no active flow)', () {
    test('bounces off both MFA screens back to login', () {
      expect(
        mfaRedirect(
            MfaPhase.idle, AuthStatus.unauthenticated, mfaEnrollmentPath),
        loginPath,
      );
      expect(
        mfaRedirect(
            MfaPhase.idle, AuthStatus.unauthenticated, mfaChallengePath),
        loginPath,
      );
    });

    test('never touches unrelated locations (login, register, /app/*)', () {
      expect(mfaRedirect(MfaPhase.idle, AuthStatus.unauthenticated, loginPath),
          isNull);
      expect(
          mfaRedirect(MfaPhase.idle, AuthStatus.unauthenticated, registerPath),
          isNull);
    });
  });

  group('mfaRedirect: enrollment-family phases', () {
    for (final phase in [
      MfaPhase.enrollmentStarting,
      MfaPhase.enrollmentReady,
      MfaPhase.enrollmentConfirming,
      MfaPhase.recoveryCodesPendingAck,
    ]) {
      test(
          '$phase: pins the user to the enrollment screen from anywhere '
          'else, including /login itself', () {
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, loginPath),
          mfaEnrollmentPath,
        );
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, mfaChallengePath),
          mfaEnrollmentPath,
        );
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, appHomePath),
          mfaEnrollmentPath,
        );
      });

      test('$phase: stays put on the enrollment screen (no redirect loop)', () {
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, mfaEnrollmentPath),
          isNull,
        );
      });
    }
  });

  group('mfaRedirect: challenge-family phases', () {
    for (final phase in [
      MfaPhase.challengeReady,
      MfaPhase.challengeVerifying,
    ]) {
      test(
          '$phase: pins the user to the challenge screen from anywhere '
          'else, including /login itself', () {
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, loginPath),
          mfaChallengePath,
        );
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, mfaEnrollmentPath),
          mfaChallengePath,
        );
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, appHomePath),
          mfaChallengePath,
        );
      });

      test('$phase: stays put on the challenge screen (no redirect loop)', () {
        expect(
          mfaRedirect(phase, AuthStatus.unauthenticated, mfaChallengePath),
          isNull,
        );
      });
    }

    test(
        'loggingIn (the password-check phase) is treated as enrollment-'
        'family by _isMfaScreen\'s complement — actually pins to the '
        'enrollment target, since only the two challenge phases route to '
        'mfaChallengePath', () {
      // loggingIn only ever happens while sitting on /login itself (see
      // authRedirect, which keeps /login reachable while unauthenticated);
      // by the time MfaController leaves loggingIn it has already decided
      // enrollment vs challenge, so this phase is never actually observed by
      // the router redirecting *away* from /login. This test just pins down
      // the (harmless) enrollment-target behavior so a future refactor of
      // the phase list doesn't silently change it unnoticed.
      expect(
        mfaRedirect(
            MfaPhase.loggingIn, AuthStatus.unauthenticated, appHomePath),
        mfaEnrollmentPath,
      );
    });
  });

  group('authRedirect + mfaRedirect: no redirect loops', () {
    /// Mirrors exactly what `routerProvider`'s `redirect:` callback does:
    /// `authRedirect` first, then (only if it stays put) `mfaRedirect`. A
    /// bare `null` from both means the location is a stable fixed point —
    /// go_router stops chaining. Fails loudly (instead of hanging) if either
    /// function ever redirects a location to itself, or if the chain hasn't
    /// converged within [maxHops] — which would otherwise surface at
    /// runtime as go_router's own "too many redirects" error.
    String resolve(
      AuthStatus status,
      MfaPhase phase,
      String start, {
      int maxHops = 5,
    }) {
      var location = start;
      for (var hop = 0; hop < maxHops; hop++) {
        final authResult = authRedirect(status, location);
        if (authResult != null) {
          expect(authResult, isNot(location),
              reason: 'authRedirect redirected $location to itself');
          location = authResult;
          continue;
        }
        final mfaResult = mfaRedirect(phase, status, location);
        if (mfaResult != null) {
          expect(mfaResult, isNot(location),
              reason: 'mfaRedirect redirected $location to itself');
          location = mfaResult;
          continue;
        }
        return location;
      }
      fail('redirect chain from $start (status=$status, phase=$phase) did '
          'not converge within $maxHops hops');
    }

    const startingLocations = [
      splashPath,
      loginPath,
      registerPath,
      mfaEnrollmentPath,
      mfaChallengePath,
      appHomePath,
      '/app/perfil',
    ];

    for (final phase in MfaPhase.values) {
      for (final start in startingLocations) {
        test(
            'unauthenticated, phase=$phase, starting at $start: converges to '
            'a stable location', () {
          final resolved = resolve(AuthStatus.unauthenticated, phase, start);

          // The resolved location must itself be a true fixed point: running
          // both functions on it again must return null.
          expect(authRedirect(AuthStatus.unauthenticated, resolved), isNull,
              reason: 'resolved location $resolved is not stable');
          expect(
              mfaRedirect(phase, AuthStatus.unauthenticated, resolved), isNull,
              reason: 'resolved location $resolved is not stable');
        });
      }

      test(
          'authenticated, phase=$phase, starting at each MFA screen: always '
          'converges to appHomePath, never lingers on /mfa/*', () {
        expect(
          resolve(AuthStatus.authenticated, phase, mfaEnrollmentPath),
          appHomePath,
        );
        expect(
          resolve(AuthStatus.authenticated, phase, mfaChallengePath),
          appHomePath,
        );
      });
    }
  });

  group('loanFlowRedirect: review screen (loanReviewPath)', () {
    test('bounces to simulation when there is no draft', () {
      expect(
        loanFlowRedirect(
          location: loanReviewPath,
          hasDraft: false,
          submissionStatus: LoanSubmissionStatus.idle,
        ),
        simulationPath,
      );
    });

    test('stays put when a draft exists (no redirect loop)', () {
      expect(
        loanFlowRedirect(
          location: loanReviewPath,
          hasDraft: true,
          submissionStatus: LoanSubmissionStatus.idle,
        ),
        isNull,
      );
    });

    test('stays put while submitting', () {
      expect(
        loanFlowRedirect(
          location: loanReviewPath,
          hasDraft: true,
          submissionStatus: LoanSubmissionStatus.submitting,
        ),
        isNull,
      );
    });
  });

  group('loanFlowRedirect: confirmation screen (loanConfirmationPath)', () {
    for (final status in [
      LoanSubmissionStatus.idle,
      LoanSubmissionStatus.submitting,
      LoanSubmissionStatus.failure,
      LoanSubmissionStatus.outcomeUnknown,
    ]) {
      test(
          'bounces to simulation when submission status is $status (no successful response yet)',
          () {
        expect(
          loanFlowRedirect(
              location: loanConfirmationPath,
              hasDraft: false,
              submissionStatus: status),
          simulationPath,
        );
      });
    }

    test('stays put once submission succeeded (no redirect loop)', () {
      expect(
        loanFlowRedirect(
          location: loanConfirmationPath,
          hasDraft: false,
          submissionStatus: LoanSubmissionStatus.success,
        ),
        isNull,
      );
    });
  });

  group('loanFlowRedirect: unrelated locations', () {
    test('never redirects locations outside the loan flow', () {
      expect(
        loanFlowRedirect(
            location: appHomePath,
            hasDraft: false,
            submissionStatus: LoanSubmissionStatus.idle),
        isNull,
      );
      expect(
        loanFlowRedirect(
            location: simulationPath,
            hasDraft: false,
            submissionStatus: LoanSubmissionStatus.idle),
        isNull,
      );
      expect(
        loanFlowRedirect(
            location: '/app/perfil',
            hasDraft: false,
            submissionStatus: LoanSubmissionStatus.idle),
        isNull,
      );
    });
  });
}
