import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_controller.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_state.dart';

/// In-memory double — never touches the platform's real secure storage.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

String _fakeJwt({required int expEpochSeconds}) {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final payload = encode({'sub': 1, 'exp': expEpochSeconds});
  return '$header.$payload.sig';
}

const _cliente =
    ClienteSummary(id: 1, nombre: 'Juan Pérez', email: 'juan@example.com');

Future<void> _pump() => Future<void>.delayed(Duration.zero);

/// `AuthController` no longer owns the password check (see
/// `mfa_controller_test.dart` for that) — it only restores, adopts a
/// finished session via [AuthController.completeMfaLogin] (the same seam
/// `MfaController` calls once MFA succeeds), and ends one. [clearMfaFlow] is
/// counted so tests can prove `logout()` always calls it.
AuthController _controller({
  required SessionLocalStorage sessionStorage,
  void Function()? clearMfaFlow,
}) {
  return AuthController(
    sessionStorage: sessionStorage,
    clearMfaFlow: clearMfaFlow ?? () {},
  );
}

void main() {
  group('AuthController restoration', () {
    test('starts as restoring, then unauthenticated when storage is empty',
        () async {
      final controller =
          _controller(sessionStorage: SessionLocalStorage(FakeSecureStorage()));
      expect(controller.state.status, AuthStatus.restoring);

      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
    });

    test(
        'restores authenticated when a valid, non-expired token and cliente are stored',
        () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      final futureExp =
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000;
      await storage.saveSession(
          token: _fakeJwt(expEpochSeconds: futureExp), cliente: _cliente);

      final controller = _controller(sessionStorage: storage);
      await _pump();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.cliente?.email, 'juan@example.com');
    });

    test('clears an expired token and restores as unauthenticated', () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      final pastExp = DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      await storage.saveSession(
          token: _fakeJwt(expEpochSeconds: pastExp), cliente: _cliente);

      final controller = _controller(sessionStorage: storage);
      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.readToken(), isNull);
    });

    test(
        'treats an incomplete local session (token without cliente) as unauthenticated',
        () async {
      final fakeStorage = FakeSecureStorage();
      // Simulates only half of a session having been written.
      await fakeStorage.write('session_token', 'some-token');
      final storage = SessionLocalStorage(fakeStorage);

      final controller = _controller(sessionStorage: storage);
      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.readToken(), isNull);
    });
  });

  group('AuthController.completeMfaLogin', () {
    test(
        'transitions to authenticated and persists the session — the only '
        'way a session is created outside restoration', () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      final controller = _controller(sessionStorage: storage);
      await _pump();
      expect(controller.state.status, AuthStatus.unauthenticated);

      await controller.completeMfaLogin(
        token: _fakeJwt(
            expEpochSeconds: DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000),
        cliente: _cliente,
      );

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.cliente?.email, 'juan@example.com');
      expect(await storage.readToken(), isNotNull);
      expect((await storage.readCliente())?.email, 'juan@example.com');
    });
  });

  group('AuthController.logout', () {
    test('clears the session and returns to unauthenticated', () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      await storage.saveSession(
        token: _fakeJwt(
            expEpochSeconds: DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000),
        cliente: _cliente,
      );
      final controller = _controller(sessionStorage: storage);
      await _pump();
      expect(controller.state.status, AuthStatus.authenticated);

      await controller.logout();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.readToken(), isNull);
    });

    test(
        'also clears any pending MFA flow ("logout limpia también cualquier '
        'flujo MFA pendiente")', () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      await storage.saveSession(
        token: _fakeJwt(
            expEpochSeconds: DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000),
        cliente: _cliente,
      );
      var clearMfaFlowCalls = 0;
      final controller = _controller(
        sessionStorage: storage,
        clearMfaFlow: () => clearMfaFlowCalls++,
      );
      await _pump();

      await controller.logout();

      expect(clearMfaFlowCalls, 1);
    });
  });

  group('AuthController.sessionRejectedByServer', () {
    Future<AuthController> authenticatedController(
        SessionLocalStorage storage) async {
      await storage.saveSession(
        token: _fakeJwt(
            expEpochSeconds: DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000),
        cliente: _cliente,
      );
      final controller = _controller(sessionStorage: storage);
      await _pump();
      return controller;
    }

    test('clears the session when called on an authenticated controller',
        () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      final controller = await authenticatedController(storage);

      controller.sessionRejectedByServer();
      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.readToken(), isNull);
    });

    test(
        'is idempotent: calling it twice concurrently only clears storage once',
        () async {
      final fakeStorage = FakeSecureStorage();
      final storage = SessionLocalStorage(fakeStorage);
      final controller = await authenticatedController(storage);

      controller.sessionRejectedByServer();
      controller.sessionRejectedByServer();
      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
    });

    test('is a no-op when there is no authenticated session to reject',
        () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      final controller = _controller(sessionStorage: storage);
      await _pump();
      expect(controller.state.status, AuthStatus.unauthenticated);

      controller.sessionRejectedByServer();
      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
    });
  });
}
