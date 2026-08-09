import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/auth/data/auth_models.dart';

void main() {
  group('RegisterRequest.toJson', () {
    test('includes telefono when provided', () {
      const request = RegisterRequest(
        nombre: 'Juan Pérez',
        email: 'juan@example.com',
        password: 'ClaveSegura123',
        telefono: '8711234567',
      );
      expect(request.toJson(), {
        'nombre': 'Juan Pérez',
        'email': 'juan@example.com',
        'password': 'ClaveSegura123',
        'telefono': '8711234567',
      });
    });

    test(
        'omits telefono entirely when not provided (server treats it as optional)',
        () {
      const request = RegisterRequest(
        nombre: 'Juan Pérez',
        email: 'juan@example.com',
        password: 'ClaveSegura123',
      );
      final json = request.toJson();
      expect(json.containsKey('telefono'), isFalse);
    });

    test('omits telefono when it is an empty string rather than sending ""',
        () {
      const request = RegisterRequest(
        nombre: 'Juan Pérez',
        email: 'juan@example.com',
        password: 'ClaveSegura123',
        telefono: '',
      );
      expect(request.toJson().containsKey('telefono'), isFalse);
    });
  });

  group('LoginRequest.toJson', () {
    test('serializes exactly email and password', () {
      const request =
          LoginRequest(email: 'juan@example.com', password: 'ClaveSegura123');
      expect(request.toJson(),
          {'email': 'juan@example.com', 'password': 'ClaveSegura123'});
    });
  });

  group('RegisterResult.fromJson', () {
    test('parses mensaje and clienteId', () {
      final result = RegisterResult.fromJson({
        'mensaje': 'Cliente registrado exitosamente',
        'clienteId': 1,
      });
      expect(result.mensaje, 'Cliente registrado exitosamente');
      expect(result.clienteId, 1);
    });
  });
}
