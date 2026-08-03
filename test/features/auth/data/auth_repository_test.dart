import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/config/env_config.dart';
import 'package:prestamesta_app/core/errors/app_exception.dart';
import 'package:prestamesta_app/core/network/api_client.dart';
import 'package:prestamesta_app/features/auth/data/auth_models.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  group('AuthRepository.login', () {
    test('returns a LoginResult on a 200 with the real envelope shape',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Autenticación exitosa',
          'token': 'eyJhbGciOiJIUzI1NiJ9.abc.def',
          'cliente': {
            'id': 1,
            'nombre': 'Juan Pérez',
            'email': 'juan@example.com'
          },
        }, 200),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepository(dio);

      final result = await repository.login(
        const LoginRequest(
            email: 'juan@example.com', password: 'ClaveSegura123'),
      );

      expect(result.token, 'eyJhbGciOiJIUzI1NiJ9.abc.def');
      expect(result.cliente.email, 'juan@example.com');
    });

    test('throws AppException(noAutenticado) on 401 INVALID_CREDENTIALS',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Credenciales inválidas.',
          'codigo': 'INVALID_CREDENTIALS'
        }, 401),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepository(dio);

      await expectLater(
        repository.login(
            const LoginRequest(email: 'x@example.com', password: 'wrong')),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppExceptionType.noAutenticado)
              .having((e) => e.codigo, 'codigo', 'INVALID_CREDENTIALS'),
        ),
      );
    });

    test('throws AppException(demasiadasSolicitudes) on 429', () async {
      final adapter =
          FakeHttpClientAdapter((options) => jsonResponseBody({}, 429));
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepository(dio);

      await expectLater(
        repository
            .login(const LoginRequest(email: 'x@example.com', password: 'x')),
        throwsA(isA<AppException>().having(
            (e) => e.type, 'type', AppExceptionType.demasiadasSolicitudes)),
      );
    });

    test(
        'never sends Authorization even through the real ApiClient with a stale token stored',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'ok',
          'token': 'new-token',
          'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
        }, 200),
      );
      final config = EnvConfig.parse(
          appEnvRaw: 'local', apiBaseUrlRaw: 'http://10.0.2.2:3000');
      final apiClient = ApiClient.create(
        config: config,
        readToken: () async => 'stale-token-from-a-previous-session',
        onSessionRejected: () {},
      );
      apiClient.dio.httpClientAdapter = adapter;
      final repository = AuthRepository(apiClient.dio);

      await repository
          .login(const LoginRequest(email: 'juan@example.com', password: 'x'));

      expect(adapter.capturedRequests, hasLength(1));
      expect(
          adapter.capturedRequests.single.headers.containsKey('Authorization'),
          isFalse);
    });
  });

  group('AuthRepository.register', () {
    test('returns a RegisterResult (no token, no session) on 201', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody(
            {'mensaje': 'Cliente registrado exitosamente', 'clienteId': 42},
            201),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepository(dio);

      final result = await repository.register(
        const RegisterRequest(
            nombre: 'Juan',
            email: 'juan@example.com',
            password: 'ClaveSegura123'),
      );

      expect(result.clienteId, 42);
    });

    test('throws AppException(conflicto) on 409 EMAIL_ALREADY_EXISTS',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'El correo ya esta registrado.',
          'codigo': 'EMAIL_ALREADY_EXISTS'
        }, 409),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepository(dio);

      await expectLater(
        repository.register(
          const RegisterRequest(
              nombre: 'Juan',
              email: 'juan@example.com',
              password: 'ClaveSegura123'),
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppExceptionType.conflicto)
              .having((e) => e.codigo, 'codigo', 'EMAIL_ALREADY_EXISTS'),
        ),
      );
    });

    test(
        'throws AppException(validacion) on 400 VALIDATION_ERROR with detalles',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Los datos enviados no son válidos.',
          'codigo': 'VALIDATION_ERROR',
          'detalles': [
            {'campo': 'password', 'mensaje': 'Contrasena invalida'},
          ],
        }, 400),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepository(dio);

      await expectLater(
        repository.register(
          const RegisterRequest(
              nombre: 'Juan', email: 'juan@example.com', password: 'weak'),
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppExceptionType.validacion)
              .having((e) => e.detalles, 'detalles', hasLength(1)),
        ),
      );
    });

    test('never sends telefono when not provided', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({'mensaje': 'ok', 'clienteId': 1}, 201),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepository(dio);

      await repository.register(
        const RegisterRequest(
            nombre: 'Juan',
            email: 'juan@example.com',
            password: 'ClaveSegura123'),
      );

      final sentBody = adapter.capturedRequests.single.data as Map;
      expect(sentBody.containsKey('telefono'), isFalse);
    });
  });
}
