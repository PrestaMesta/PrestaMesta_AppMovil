import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/app/router.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_state.dart';
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
    });
  });

  group(
      'authRedirect: not authenticated (unauthenticated/authenticating/error)',
      () {
    for (final status in [
      AuthStatus.unauthenticated,
      AuthStatus.authenticating,
      AuthStatus.error
    ]) {
      test('$status: login/register stay put', () {
        expect(authRedirect(status, loginPath), isNull);
        expect(authRedirect(status, registerPath), isNull);
      });

      test('$status: a direct /app deep link bounces to login', () {
        expect(authRedirect(status, appHomePath), loginPath);
        expect(authRedirect(status, '/app/perfil'), loginPath);
      });

      test(
          '$status: splash bounces to login (restore just finished, no session)',
          () {
        expect(authRedirect(status, splashPath), loginPath);
      });
    }
  });

  group('authRedirect: authenticated', () {
    test('login bounces to the app home', () {
      expect(authRedirect(AuthStatus.authenticated, loginPath), appHomePath);
    });

    test('register bounces to the app home', () {
      expect(authRedirect(AuthStatus.authenticated, registerPath), appHomePath);
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
