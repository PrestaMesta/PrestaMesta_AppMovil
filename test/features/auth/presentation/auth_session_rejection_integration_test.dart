import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/config/env_config.dart';
import 'package:prestamesta_app/core/network/api_client.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_controller.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_state.dart';

import '../../../support/fake_http_client_adapter.dart';

/// Wires a real [ApiClient] (with its real `AuthInterceptor`) to a real
/// [AuthController] — exactly the way `app/providers.dart` connects them in
/// the actual app — so these tests prove the *end-to-end* wiring, not just
/// the isolated `isSessionRejection` unit tested in Checkpoint 1.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

String _fakeJwt() {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  return '${encode({'alg': 'HS256'})}.${encode({'sub': 1, 'exp': exp})}.sig';
}

const _cliente =
    ClienteSummary(id: 1, nombre: 'Juan', email: 'juan@example.com');

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late SessionLocalStorage sessionStorage;
  late AuthController authController;
  late FakeHttpClientAdapter adapter;
  late Dio protectedDio;

  setUp(() async {
    sessionStorage = SessionLocalStorage(FakeSecureStorage());
    await sessionStorage.saveSession(token: _fakeJwt(), cliente: _cliente);

    authController = AuthController(
      sessionStorage: sessionStorage,
      clearMfaFlow: () {},
    );
    await _pump();
    expect(authController.state.status, AuthStatus.authenticated,
        reason: 'test setup sanity check');

    final config = EnvConfig.parse(
        appEnvRaw: 'local', apiBaseUrlRaw: 'http://10.0.2.2:3000');
    final apiClient = ApiClient.create(
      config: config,
      readToken: sessionStorage.readToken,
      onSessionRejected: authController.sessionRejectedByServer,
    );
    adapter = FakeHttpClientAdapter((options) => jsonResponseBody({}, 500));
    apiClient.dio.httpClientAdapter = adapter;
    protectedDio = apiClient.dio;
  });

  test(
      'a 401 TOKEN_EXPIRED on a protected request clears the session end-to-end',
      () async {
    adapter.responder = (options) => jsonResponseBody(
        {'mensaje': 'Token expirado', 'codigo': 'TOKEN_EXPIRED'}, 401);

    await expectLater(
      protectedDio.get('/prestamos/creditos',
          options: Options(extra: const {'requiresAuth': true})),
      throwsA(anything),
    );

    expect(authController.state.status, AuthStatus.unauthenticated);
  });

  test('a 403 on a protected request does not clear the session', () async {
    adapter.responder = (options) =>
        jsonResponseBody({'mensaje': 'Prohibido', 'codigo': 'FORBIDDEN'}, 403);

    await expectLater(
      protectedDio.get('/prestamos/creditos',
          options: Options(extra: const {'requiresAuth': true})),
      throwsA(anything),
    );

    expect(authController.state.status, AuthStatus.authenticated);
  });

  test('a 500 on a protected request does not clear the session', () async {
    adapter.responder =
        (options) => jsonResponseBody({'mensaje': 'Error interno'}, 500);

    await expectLater(
      protectedDio.get('/prestamos/creditos',
          options: Options(extra: const {'requiresAuth': true})),
      throwsA(anything),
    );

    expect(authController.state.status, AuthStatus.authenticated);
  });

  test('a connection timeout does not clear the session', () async {
    adapter.responder = (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );

    await expectLater(
      protectedDio.get('/prestamos/creditos',
          options: Options(extra: const {'requiresAuth': true})),
      throwsA(anything),
    );

    expect(authController.state.status, AuthStatus.authenticated);
  });
}
