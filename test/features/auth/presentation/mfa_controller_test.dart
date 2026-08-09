import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/presentation/mfa_controller.dart';
import 'package:prestamesta_app/features/auth/presentation/mfa_state.dart';

import '../../../support/fake_http_client_adapter.dart';

class _CompletedLogin {
  final String token;
  final ClienteSummary cliente;
  const _CompletedLogin(this.token, this.cliente);
}

/// A recording double for the seam `MfaController` uses to hand a finished
/// session off to `AuthController.completeMfaLogin` — kept separate from a
/// real `AuthController` so these tests only ever assert on *when* and
/// *with what* the hand-off happens, not on session-storage mechanics (see
/// `mfa_session_integration_test.dart` for that, with a real
/// `SessionLocalStorage`/`FakeSecureStorage`).
class _CompleteMfaLoginRecorder {
  final List<_CompletedLogin> calls = [];

  Future<void> call(
      {required String token, required ClienteSummary cliente}) async {
    calls.add(_CompletedLogin(token, cliente));
  }
}

MfaController _controller(
  FutureOr<ResponseBody> Function(RequestOptions) responder, {
  _CompleteMfaLoginRecorder? recorder,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return MfaController(
    authRepository: AuthRepository(dio),
    completeMfaLogin: (recorder ?? _CompleteMfaLoginRecorder()).call,
  );
}

const _enrollmentLoginJson = {
  'mensaje': 'Verifica tu identidad para continuar.',
  'preMfaToken': 'pre-mfa-token',
  'siguientePaso': 'MFA_ENROLLMENT_REQUIRED',
};

const _challengeLoginJson = {
  'mensaje': 'Verifica tu identidad para continuar.',
  'preMfaToken': 'pre-mfa-token',
  'siguientePaso': 'MFA_CHALLENGE_REQUIRED',
};

const _enrollJson = {
  'mensaje': 'Escanea el codigo QR.',
  'secreto': 'JBSWY3DPEHPK3PXP',
  'otpauthUri': 'otpauth://totp/Prestamesta:juan?secret=JBSWY3DPEHPK3PXP',
};

Map<String, dynamic> _sessionJson({List<String>? codigosRecuperacion}) => {
      'mensaje': 'Autenticacion exitosa.',
      'token': 'real-session-token',
      'cliente': {'id': 1, 'nombre': 'Juan Pérez', 'email': 'juan@example.com'},
      if (codigosRecuperacion != null)
        'codigosRecuperacion': codigosRecuperacion,
    };

void main() {
  group('login → enrollment', () {
    test(
        'MFA_ENROLLMENT_REQUIRED auto-starts enroll and lands on '
        'enrollmentReady with secreto/otpauthUri', () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody(_enrollJson, 201);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      });

      final future = controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');
      expect(controller.state.phase, MfaPhase.loggingIn);
      await future;

      expect(controller.state.phase, MfaPhase.enrollmentReady);
      expect(controller.state.preMfaToken, 'pre-mfa-token');
      expect(controller.state.secreto, 'JBSWY3DPEHPK3PXP');
      expect(controller.state.otpauthUri, startsWith('otpauth://'));
    });

    test(
        'a 409 MFA_CHALLENGE_REQUIRED from mfa/enroll self-heals onto the '
        'challenge screen instead of a dead-end error', () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody({
            'mensaje': 'El MFA ya esta activo.',
            'codigo': 'MFA_CHALLENGE_REQUIRED',
          }, 409);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      });

      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      expect(controller.state.phase, MfaPhase.challengeReady);
      expect(controller.state.preMfaToken, 'pre-mfa-token');
    });
  });

  group('login → challenge', () {
    test(
        'MFA_CHALLENGE_REQUIRED lands directly on challengeReady, no '
        'extra network call', () async {
      var callCount = 0;
      final controller = _controller((options) {
        callCount++;
        return jsonResponseBody(_challengeLoginJson, 200);
      });

      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      expect(controller.state.phase, MfaPhase.challengeReady);
      expect(controller.state.preMfaToken, 'pre-mfa-token');
      expect(callCount, 1);
    });

    test('INVALID_CREDENTIALS keeps phase idle and surfaces the error',
        () async {
      final controller = _controller((options) => jsonResponseBody({
            'mensaje': 'Credenciales inválidas.',
            'codigo': 'INVALID_CREDENTIALS'
          }, 401));

      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      expect(controller.state.phase, MfaPhase.idle);
      expect(controller.state.error?.codigo, 'INVALID_CREDENTIALS');
    });
  });

  group('preMfaToken is never interpreted as a session token', () {
    test(
        'MfaState never exposes a "session token" — only preMfaToken (pre) '
        'and pendingTokenForAck (post-confirm, pre-ack); AuthController is '
        'only ever reached via the completeMfaLogin callback', () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          return jsonResponseBody(_sessionJson(), 200);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      }, recorder: recorder);

      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');
      expect(controller.state.preMfaToken, 'pre-mfa-token');

      await controller.verifyChallenge(totp: '123456');

      // The real session token ('real-session-token') was only ever handed
      // to the recorder (standing in for AuthController.completeMfaLogin) —
      // never assigned to MfaState.preMfaToken, and the flow is idle again.
      expect(recorder.calls.single.token, 'real-session-token');
      expect(controller.state.phase, MfaPhase.idle);
      expect(controller.state.preMfaToken, isNull);
    });
  });

  group('enrollment confirmation', () {
    test(
        'confirmEnrollment success lands on recoveryCodesPendingAck and '
        'does NOT complete the session yet ("no entrar a /app antes de '
        'confirmar que se guardaron")', () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody(_enrollJson, 201);
        }
        if (options.path == '/client/auth/mfa/enroll/confirm') {
          return jsonResponseBody(
              _sessionJson(
                  codigosRecuperacion: List.generate(10, (i) => 'C$i')),
              200);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      }, recorder: recorder);
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.confirmEnrollment('123456');

      expect(controller.state.phase, MfaPhase.recoveryCodesPendingAck);
      expect(controller.state.recoveryCodes, hasLength(10));
      expect(recorder.calls, isEmpty,
          reason: 'session must not be established before the user '
              'acknowledges the recovery codes were saved');

      // The server already issued the real session token+cliente at this
      // point (mfa/enroll/confirm's response) — it must be sitting only in
      // MfaState's in-memory pending fields, not yet handed to
      // AuthController/SessionLocalStorage.
      expect(controller.state.pendingTokenForAck, 'real-session-token');
      expect(controller.state.pendingClienteForAck?.email, 'juan@example.com');
    });

    test(
        'acknowledgeRecoveryCodesSaved hands the session to AuthController '
        'exactly once, then resets to idle and drops the codes from memory',
        () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody(_enrollJson, 201);
        }
        if (options.path == '/client/auth/mfa/enroll/confirm') {
          return jsonResponseBody(
              _sessionJson(codigosRecuperacion: ['C0', 'C1']), 200);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      }, recorder: recorder);
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');
      await controller.confirmEnrollment('123456');

      await controller.acknowledgeRecoveryCodesSaved();

      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.token, 'real-session-token');
      expect(recorder.calls.single.cliente.email, 'juan@example.com');
      expect(controller.state.phase, MfaPhase.idle);
      expect(controller.state.recoveryCodes, isNull);
    });

    test(
        'acknowledgeRecoveryCodesSaved is a no-op outside '
        'recoveryCodesPendingAck (nothing to acknowledge yet)', () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller(
          (options) => jsonResponseBody(_challengeLoginJson, 200),
          recorder: recorder);
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.acknowledgeRecoveryCodesSaved();

      expect(recorder.calls, isEmpty);
      expect(controller.state.phase, MfaPhase.challengeReady);
    });

    test(
        'MFA_ENROLLMENT_INVALID (bad/reused confirmation code) returns to '
        'enrollmentReady with the error, keeping the same secreto/otpauthUri',
        () async {
      var confirmAttempts = 0;
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody(_enrollJson, 201);
        }
        if (options.path == '/client/auth/mfa/enroll/confirm') {
          confirmAttempts++;
          return jsonResponseBody({
            'mensaje': 'Codigo invalido o ya utilizado.',
            'codigo': 'MFA_ENROLLMENT_INVALID',
          }, 400);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.confirmEnrollment('000000');

      expect(controller.state.phase, MfaPhase.enrollmentReady);
      expect(controller.state.error?.codigo, 'MFA_ENROLLMENT_INVALID');
      expect(controller.state.secreto, 'JBSWY3DPEHPK3PXP',
          reason: 'the QR/secret must still be shown so the user can retry');
      expect(confirmAttempts, 1);
    });

    test(
        '429 MFA_RATE_LIMITED during confirm surfaces as an error, not an '
        'uncaught exception', () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody(_enrollJson, 201);
        }
        if (options.path == '/client/auth/mfa/enroll/confirm') {
          return jsonResponseBody({
            'mensaje': 'Demasiados intentos. Intenta de nuevo mas tarde.',
            'codigo': 'MFA_RATE_LIMITED',
          }, 429);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.confirmEnrollment('123456');

      expect(controller.state.phase, MfaPhase.enrollmentReady);
      expect(controller.state.error?.codigo, 'MFA_RATE_LIMITED');
    });
  });

  group('challenge: TOTP', () {
    test('a correct TOTP completes the session and returns to idle', () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          expect(options.data, {'codigo': '123456'});
          return jsonResponseBody(_sessionJson(), 200);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      }, recorder: recorder);
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.verifyChallenge(totp: '123456');

      expect(recorder.calls, hasLength(1));
      expect(controller.state.phase, MfaPhase.idle);
    });
  });

  group('challenge: recovery code', () {
    test('a correct recovery code completes the session', () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          expect(
              options.data, {'codigoRecuperacion': 'A1B2-C3D4-E5F6-0708-090A'});
          return jsonResponseBody(_sessionJson(), 200);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      }, recorder: recorder);
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.verifyChallenge(
          recoveryCode: 'A1B2-C3D4-E5F6-0708-090A');

      expect(recorder.calls, hasLength(1));
      expect(controller.state.phase, MfaPhase.idle);
    });
  });

  group('challenge: invalid/reused codes', () {
    test(
        'MFA_INVALID_CODE returns to challengeReady with the error, session '
        'never established', () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          return jsonResponseBody(
              {'mensaje': 'Codigo invalido.', 'codigo': 'MFA_INVALID_CODE'},
              401);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      }, recorder: recorder);
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.verifyChallenge(totp: '000000');

      expect(controller.state.phase, MfaPhase.challengeReady);
      expect(controller.state.error?.codigo, 'MFA_INVALID_CODE');
      expect(recorder.calls, isEmpty);
    });

    test(
        'MFA_CODE_REUSED (same TOTP submitted twice) is surfaced as an '
        'error, not treated as success', () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          return jsonResponseBody(
              {'mensaje': 'Codigo ya utilizado.', 'codigo': 'MFA_CODE_REUSED'},
              401);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.verifyChallenge(totp: '123456');

      expect(controller.state.error?.codigo, 'MFA_CODE_REUSED');
    });

    test('RECOVERY_CODE_ALREADY_USED is surfaced as an error', () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          return jsonResponseBody({
            'mensaje': 'Codigo de recuperacion ya utilizado.',
            'codigo': 'RECOVERY_CODE_ALREADY_USED',
          }, 401);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.verifyChallenge(recoveryCode: 'USED-CODE');

      expect(controller.state.error?.codigo, 'RECOVERY_CODE_ALREADY_USED');
    });
  });

  group('rate limiting', () {
    test(
        '429 MFA_RATE_LIMITED on verify surfaces a prudent error and stays '
        'on the challenge screen', () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          return jsonResponseBody({
            'mensaje': 'Demasiados intentos. Intenta de nuevo mas tarde.',
            'codigo': 'MFA_RATE_LIMITED',
          }, 429);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.verifyChallenge(totp: '123456');

      expect(controller.state.phase, MfaPhase.challengeReady);
      expect(controller.state.error?.codigo, 'MFA_RATE_LIMITED');
    });
  });

  group('expired/invalid pre-MFA token', () {
    test(
        'TOKEN_EXPIRED during mfa/verify aborts back to idle with a notice, '
        'never touching AuthController', () async {
      final recorder = _CompleteMfaLoginRecorder();
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          return jsonResponseBody(
              {'mensaje': 'Token expirado', 'codigo': 'TOKEN_EXPIRED'}, 401);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      }, recorder: recorder);
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.verifyChallenge(totp: '123456');

      expect(controller.state.phase, MfaPhase.idle);
      expect(controller.state.preMfaToken, isNull);
      expect(controller.state.sessionExpiredNotice, isNotNull);
      expect(recorder.calls, isEmpty);
    });

    test('TOKEN_INVALID during mfa/enroll/confirm also aborts to idle',
        () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody(_enrollJson, 201);
        }
        if (options.path == '/client/auth/mfa/enroll/confirm') {
          return jsonResponseBody(
              {'mensaje': 'Token invalido', 'codigo': 'TOKEN_INVALID'}, 401);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      await controller.confirmEnrollment('123456');

      expect(controller.state.phase, MfaPhase.idle);
      expect(controller.state.sessionExpiredNotice, isNotNull);
    });

    test('dismissExpiredNotice clears the notice once shown', () async {
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          return jsonResponseBody(
              {'mensaje': 'Token expirado', 'codigo': 'TOKEN_EXPIRED'}, 401);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');
      await controller.verifyChallenge(totp: '123456');
      expect(controller.state.sessionExpiredNotice, isNotNull);

      controller.dismissExpiredNotice();

      expect(controller.state.sessionExpiredNotice, isNull);
    });
  });

  group('double submit', () {
    test('two concurrent loginWithPassword calls only issue one network call',
        () async {
      var callCount = 0;
      final controller = _controller((options) {
        callCount++;
        return jsonResponseBody(_challengeLoginJson, 200);
      });

      final first = controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');
      final second = controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test('two concurrent confirmEnrollment calls only issue one network call',
        () async {
      var confirmCalls = 0;
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/enroll') {
          return jsonResponseBody(_enrollJson, 201);
        }
        if (options.path == '/client/auth/mfa/enroll/confirm') {
          confirmCalls++;
          return jsonResponseBody(
              _sessionJson(codigosRecuperacion: const []), 200);
        }
        return jsonResponseBody(_enrollmentLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      final first = controller.confirmEnrollment('123456');
      final second = controller.confirmEnrollment('123456');
      await Future.wait([first, second]);

      expect(confirmCalls, 1);
    });

    test('two concurrent verifyChallenge calls only issue one network call',
        () async {
      var verifyCalls = 0;
      final controller = _controller((options) {
        if (options.path == '/client/auth/mfa/verify') {
          verifyCalls++;
          return jsonResponseBody(_sessionJson(), 200);
        }
        return jsonResponseBody(_challengeLoginJson, 200);
      });
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      final first = controller.verifyChallenge(totp: '123456');
      final second = controller.verifyChallenge(totp: '123456');
      await Future.wait([first, second]);

      expect(verifyCalls, 1);
    });
  });

  group('abandon (cancel/logout)', () {
    test(
        'abandon() during enrollmentReady discards preMfaToken/secreto and '
        'returns to idle', () async {
      final controller = _controller((options) =>
          options.path == '/client/auth/mfa/enroll'
              ? jsonResponseBody(_enrollJson, 201)
              : jsonResponseBody(_enrollmentLoginJson, 200));
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');
      expect(controller.state.phase, MfaPhase.enrollmentReady);

      controller.abandon();

      expect(controller.state.phase, MfaPhase.idle);
      expect(controller.state.preMfaToken, isNull);
      expect(controller.state.secreto, isNull);
    });

    test('abandon() during challengeReady returns to idle', () async {
      final controller =
          _controller((options) => jsonResponseBody(_challengeLoginJson, 200));
      await controller.loginWithPassword(
          email: 'juan@example.com', password: 'x');

      controller.abandon();

      expect(controller.state.phase, MfaPhase.idle);
    });

    test('abandon() is a no-op when already idle', () {
      final controller = _controller((options) => throw StateError('unused'));

      controller.abandon();

      expect(controller.state.phase, MfaPhase.idle);
    });
  });
}
