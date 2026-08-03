import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_controller.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_state.dart';

import '../../../support/fake_http_client_adapter.dart';

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

AuthRepository _repositoryRespondingWith(
    ResponseBody Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return AuthRepository(dio);
}

const _cliente =
    ClienteSummary(id: 1, nombre: 'Juan Pérez', email: 'juan@example.com');

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('AuthController restoration', () {
    test('starts as restoring, then unauthenticated when storage is empty',
        () async {
      final controller = AuthController(
        authRepository:
            _repositoryRespondingWith((_) => throw StateError('unused')),
        sessionStorage: SessionLocalStorage(FakeSecureStorage()),
      );
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

      final controller = AuthController(
        authRepository:
            _repositoryRespondingWith((_) => throw StateError('unused')),
        sessionStorage: storage,
      );
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

      final controller = AuthController(
        authRepository:
            _repositoryRespondingWith((_) => throw StateError('unused')),
        sessionStorage: storage,
      );
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

      final controller = AuthController(
        authRepository:
            _repositoryRespondingWith((_) => throw StateError('unused')),
        sessionStorage: storage,
      );
      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.readToken(), isNull);
    });
  });

  group('AuthController.login', () {
    test('success: transitions to authenticated and persists the session',
        () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      final controller = AuthController(
        authRepository: _repositoryRespondingWith(
          (options) => jsonResponseBody({
            'mensaje': 'ok',
            'token': _fakeJwt(
              expEpochSeconds: DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            ),
            'cliente': {
              'id': 1,
              'nombre': 'Juan Pérez',
              'email': 'juan@example.com'
            },
          }, 200),
        ),
        sessionStorage: storage,
      );
      await _pump();

      await controller.login(
          email: 'juan@example.com', password: 'ClaveSegura123');

      expect(controller.state.status, AuthStatus.authenticated);
      expect(await storage.readToken(), isNotNull);
      expect((await storage.readCliente())?.email, 'juan@example.com');
    });

    test(
        'failure (INVALID_CREDENTIALS): transitions to error, not authenticated',
        () async {
      final storage = SessionLocalStorage(FakeSecureStorage());
      final controller = AuthController(
        authRepository: _repositoryRespondingWith(
          (options) => jsonResponseBody(
            {
              'mensaje': 'Credenciales inválidas.',
              'codigo': 'INVALID_CREDENTIALS'
            },
            401,
          ),
        ),
        sessionStorage: storage,
      );
      await _pump();

      await controller.login(email: 'juan@example.com', password: 'wrong');

      expect(controller.state.status, AuthStatus.error);
      expect(controller.state.error?.codigo, 'INVALID_CREDENTIALS');
      expect(await storage.readToken(), isNull);
    });

    test(
        'a second concurrent login call while authenticating is ignored (no double submit)',
        () async {
      var callCount = 0;
      final storage = SessionLocalStorage(FakeSecureStorage());
      final controller = AuthController(
        authRepository: _repositoryRespondingWith((options) {
          callCount++;
          return jsonResponseBody({
            'mensaje': 'ok',
            'token': _fakeJwt(
              expEpochSeconds: DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            ),
            'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
          }, 200);
        }),
        sessionStorage: storage,
      );
      await _pump();

      final first = controller.login(
          email: 'juan@example.com', password: 'ClaveSegura123');
      final second = controller.login(
          email: 'juan@example.com', password: 'ClaveSegura123');
      await Future.wait([first, second]);

      expect(callCount, 1);
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
      final controller = AuthController(
        authRepository:
            _repositoryRespondingWith((_) => throw StateError('unused')),
        sessionStorage: storage,
      );
      await _pump();
      expect(controller.state.status, AuthStatus.authenticated);

      await controller.logout();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(await storage.readToken(), isNull);
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
      final controller = AuthController(
        authRepository:
            _repositoryRespondingWith((_) => throw StateError('unused')),
        sessionStorage: storage,
      );
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
      final controller = AuthController(
        authRepository:
            _repositoryRespondingWith((_) => throw StateError('unused')),
        sessionStorage: storage,
      );
      await _pump();
      expect(controller.state.status, AuthStatus.unauthenticated);

      controller.sessionRejectedByServer();
      await _pump();

      expect(controller.state.status, AuthStatus.unauthenticated);
    });
  });
}
