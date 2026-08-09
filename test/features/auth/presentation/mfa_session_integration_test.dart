import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/app/providers.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_controller.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_state.dart';
import 'package:prestamesta_app/features/auth/presentation/mfa_controller.dart';
import 'package:prestamesta_app/features/auth/presentation/mfa_state.dart';

import '../../../support/fake_http_client_adapter.dart';

/// These tests exercise the *real* provider graph
/// (`authControllerProvider` ↔ `mfaControllerProvider`), overriding only the
/// network-facing repository and secure storage — same pattern as
/// `test/features/credits/presentation/credits_session_integration_test.dart`.
/// They prove the checkpoint's core storage guarantees end to end, not just
/// at the bare-controller level `mfa_controller_test.dart` covers:
///   - the preMfaToken and recovery codes are never written to
///     `SecureStorage` (or anywhere else) at any point;
///   - the real session token is written to `SecureStorage` only once the
///     flow actually finishes (after the recovery-codes ack, or after a
///     successful challenge).
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  final List<String> writtenValues = [];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    writtenValues.add(value);
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

const _enrollmentLoginJson = {
  'mensaje': 'Verifica tu identidad para continuar.',
  'preMfaToken': 'super-secret-pre-mfa-token',
  'siguientePaso': 'MFA_ENROLLMENT_REQUIRED',
};

const _challengeLoginJson = {
  'mensaje': 'Verifica tu identidad para continuar.',
  'preMfaToken': 'super-secret-pre-mfa-token',
  'siguientePaso': 'MFA_CHALLENGE_REQUIRED',
};

const _enrollJson = {
  'mensaje': 'Escanea el codigo QR.',
  'secreto': 'JBSWY3DPEHPK3PXP',
  'otpauthUri': 'otpauth://totp/Prestamesta:juan?secret=JBSWY3DPEHPK3PXP',
};

final _recoveryCodes = List.generate(10, (i) => 'RECOVERY-CODE-$i');

Map<String, dynamic> _sessionJson({List<String>? codigosRecuperacion}) => {
      'mensaje': 'Autenticacion exitosa.',
      'token': 'the-real-session-jwt',
      'cliente': {'id': 1, 'nombre': 'Juan Pérez', 'email': 'juan@example.com'},
      if (codigosRecuperacion != null)
        'codigosRecuperacion': codigosRecuperacion,
    };

AuthRepository _enrollmentAuthRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      if (options.path == '/client/auth/mfa/enroll') {
        return jsonResponseBody(_enrollJson, 201);
      }
      if (options.path == '/client/auth/mfa/enroll/confirm') {
        return jsonResponseBody(
            _sessionJson(codigosRecuperacion: _recoveryCodes), 200);
      }
      return jsonResponseBody(_enrollmentLoginJson, 200);
    });
  return AuthRepository(dio);
}

AuthRepository _challengeAuthRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      if (options.path == '/client/auth/mfa/verify') {
        return jsonResponseBody(_sessionJson(), 200);
      }
      return jsonResponseBody(_challengeLoginJson, 200);
    });
  return AuthRepository(dio);
}

Future<void> _pump([int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('enrollment flow: storage guarantees', () {
    test(
        'preMfaToken and recovery codes are never written to secure storage '
        'at any point in the flow — only the final session token is, and '
        'only after the recovery-codes acknowledgement', () async {
      final fakeStorage = FakeSecureStorage();
      final container = ProviderContainer(overrides: [
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(fakeStorage)),
        authRepositoryProvider.overrideWithValue(_enrollmentAuthRepository()),
      ]);
      addTearDown(container.dispose);

      // Let AuthController's local restore finish (empty storage ->
      // unauthenticated) before touching anything else — otherwise its
      // later-resolving result can race and overwrite a session
      // `completeMfaLogin` establishes in the meantime.
      container.read(authControllerProvider);
      await _pump();

      final mfa = container.read(mfaControllerProvider.notifier);
      await mfa.loginWithPassword(email: 'juan@example.com', password: 'x');
      expect(container.read(mfaControllerProvider).phase,
          MfaPhase.enrollmentReady);
      expect(fakeStorage.writtenValues, isEmpty,
          reason: 'preMfaToken must not be persisted');

      await mfa.confirmEnrollment('123456');
      expect(container.read(mfaControllerProvider).phase,
          MfaPhase.recoveryCodesPendingAck);
      expect(fakeStorage.writtenValues, isEmpty,
          reason: 'recovery codes must not be persisted, and the session '
              'must not be saved before the user acknowledges them');
      expect(container.read(authControllerProvider).status,
          AuthStatus.unauthenticated,
          reason: 'no session yet — the ack has not happened');
      // The real token/cliente already came back from mfa/enroll/confirm —
      // confirm they're sitting only in MfaState's in-memory pending fields
      // (never in SecureStorage) until the ack below.
      expect(container.read(mfaControllerProvider).pendingTokenForAck,
          'the-real-session-jwt');
      expect(container.read(mfaControllerProvider).pendingClienteForAck?.email,
          'juan@example.com');
      expect(await SessionLocalStorage(fakeStorage).readToken(), isNull);

      await mfa.acknowledgeRecoveryCodesSaved();
      await _pump();

      // Only now does the real session token show up in storage — and none
      // of the values ever written contain the preMfaToken or any recovery
      // code string.
      expect(await fakeStorage.read('session_token'), 'the-real-session-jwt');
      for (final value in fakeStorage.writtenValues) {
        expect(value, isNot(contains('super-secret-pre-mfa-token')));
        for (final code in _recoveryCodes) {
          expect(value, isNot(contains(code)));
        }
      }
      expect(container.read(authControllerProvider).status,
          AuthStatus.authenticated);
      expect(container.read(mfaControllerProvider).phase, MfaPhase.idle);
      expect(container.read(mfaControllerProvider).recoveryCodes, isNull);
    });
  });

  group('challenge flow: storage guarantees', () {
    test(
        'the session is saved only after a successful verify — never '
        'before, and the preMfaToken never appears in storage', () async {
      final fakeStorage = FakeSecureStorage();
      final container = ProviderContainer(overrides: [
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(fakeStorage)),
        authRepositoryProvider.overrideWithValue(_challengeAuthRepository()),
      ]);
      addTearDown(container.dispose);

      // Let AuthController's local restore finish (empty storage ->
      // unauthenticated) before touching anything else — otherwise its
      // later-resolving result can race and overwrite a session
      // `completeMfaLogin` establishes in the meantime.
      container.read(authControllerProvider);
      await _pump();

      final mfa = container.read(mfaControllerProvider.notifier);
      await mfa.loginWithPassword(email: 'juan@example.com', password: 'x');
      expect(fakeStorage.writtenValues, isEmpty);
      expect(container.read(authControllerProvider).status,
          AuthStatus.unauthenticated);

      await mfa.verifyChallenge(totp: '123456');
      await _pump();

      expect(await fakeStorage.read('session_token'), 'the-real-session-jwt');
      expect(fakeStorage.writtenValues,
          isNot(contains('super-secret-pre-mfa-token')));
      expect(container.read(authControllerProvider).status,
          AuthStatus.authenticated);
    });
  });

  group('logout clears any pending MFA flow', () {
    test(
        'logging out while authenticated resets mfaControllerProvider to '
        'idle too', () async {
      final fakeStorage = FakeSecureStorage();
      final container = ProviderContainer(overrides: [
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(fakeStorage)),
        authRepositoryProvider.overrideWithValue(_challengeAuthRepository()),
      ]);
      addTearDown(container.dispose);

      // Let AuthController's local restore finish (empty storage ->
      // unauthenticated) before touching anything else — otherwise its
      // later-resolving result can race and overwrite a session
      // `completeMfaLogin` establishes in the meantime.
      container.read(authControllerProvider);
      await _pump();

      final mfa = container.read(mfaControllerProvider.notifier);
      await mfa.loginWithPassword(email: 'juan@example.com', password: 'x');
      await mfa.verifyChallenge(totp: '123456');
      await _pump();
      expect(container.read(authControllerProvider).status,
          AuthStatus.authenticated);

      await container.read(authControllerProvider.notifier).logout();

      expect(container.read(authControllerProvider).status,
          AuthStatus.unauthenticated);
      expect(container.read(mfaControllerProvider).phase, MfaPhase.idle);
    });
  });
}
