import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/presentation/register_controller.dart';

import '../../../support/fake_http_client_adapter.dart';

AuthRepository _repositoryRespondingWith(
    ResponseBody Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return AuthRepository(dio);
}

void main() {
  test('starts idle', () {
    final controller = RegisterController(
        _repositoryRespondingWith((_) => throw StateError('unused')));
    expect(controller.state.status, RegisterStatus.idle);
  });

  test('submit success: transitions to success with the clienteId', () async {
    final controller = RegisterController(
      _repositoryRespondingWith(
        (options) => jsonResponseBody(
            {'mensaje': 'Cliente registrado exitosamente', 'clienteId': 7},
            201),
      ),
    );

    await controller.submit(
        nombre: 'Juan', email: 'juan@example.com', password: 'ClaveSegura123');

    expect(controller.state.status, RegisterStatus.success);
    expect(controller.state.clienteId, 7);
  });

  test('submit failure (EMAIL_ALREADY_EXISTS): transitions to error', () async {
    final controller = RegisterController(
      _repositoryRespondingWith(
        (options) => jsonResponseBody(
          {
            'mensaje': 'El correo ya esta registrado.',
            'codigo': 'EMAIL_ALREADY_EXISTS'
          },
          409,
        ),
      ),
    );

    await controller.submit(
        nombre: 'Juan', email: 'juan@example.com', password: 'ClaveSegura123');

    expect(controller.state.status, RegisterStatus.error);
    expect(controller.state.error?.codigo, 'EMAIL_ALREADY_EXISTS');
  });

  test(
      'a second concurrent submit while submitting is ignored (no double submit)',
      () async {
    var callCount = 0;
    final controller = RegisterController(
      _repositoryRespondingWith((options) {
        callCount++;
        return jsonResponseBody({'mensaje': 'ok', 'clienteId': 1}, 201);
      }),
    );

    final first = controller.submit(
        nombre: 'Juan', email: 'juan@example.com', password: 'ClaveSegura123');
    final second = controller.submit(
        nombre: 'Juan', email: 'juan@example.com', password: 'ClaveSegura123');
    await Future.wait([first, second]);

    expect(callCount, 1);
  });

  test('reset returns to idle', () async {
    final controller = RegisterController(
      _repositoryRespondingWith(
        (options) => jsonResponseBody(
            {'mensaje': 'x', 'codigo': 'EMAIL_ALREADY_EXISTS'}, 409),
      ),
    );
    await controller.submit(
        nombre: 'Juan', email: 'juan@example.com', password: 'ClaveSegura123');
    expect(controller.state.status, RegisterStatus.error);

    controller.reset();

    expect(controller.state.status, RegisterStatus.idle);
  });
}
