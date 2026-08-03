import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/errors/app_exception.dart';
import 'package:prestamesta_app/core/network/error_mapper.dart';

RequestOptions _options() => RequestOptions(path: '/client/auth/login');

DioException _badResponse(int statusCode, dynamic data,
    {Map<String, List<String>>? headers}) {
  return DioException(
    requestOptions: _options(),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: _options(),
      statusCode: statusCode,
      data: data,
      headers: Headers.fromMap(headers ?? const {}),
    ),
  );
}

void main() {
  group('mapDioExceptionToAppException', () {
    test('maps connectionError to sinConexion', () {
      final result = mapDioExceptionToAppException(
        DioException(
            requestOptions: _options(), type: DioExceptionType.connectionError),
      );
      expect(result.type, AppExceptionType.sinConexion);
    });

    test('maps connection/send/receive timeouts to tiempoAgotado', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final result = mapDioExceptionToAppException(
          DioException(requestOptions: _options(), type: type),
        );
        expect(result.type, AppExceptionType.tiempoAgotado,
            reason: 'for $type');
      }
    });

    test(
        'maps a 400 with the server envelope to validacion, preserving codigo/requestId',
        () {
      final result = mapDioExceptionToAppException(
        _badResponse(400, {
          'mensaje': 'Los datos enviados no son válidos.',
          'codigo': 'VALIDATION_ERROR',
          'requestId': 'req-1',
          'detalles': [
            {'campo': 'email', 'mensaje': 'Invalid email address'},
          ],
        }),
      );
      expect(result.type, AppExceptionType.validacion);
      expect(result.codigo, 'VALIDATION_ERROR');
      expect(result.requestId, 'req-1');
      expect(result.detalles, hasLength(1));
      expect(result.detalles.single.campo, 'email');
    });

    test('maps 401 to noAutenticado', () {
      final result = mapDioExceptionToAppException(
        _badResponse(401, {
          'mensaje': 'Credenciales inválidas.',
          'codigo': 'INVALID_CREDENTIALS'
        }),
      );
      expect(result.type, AppExceptionType.noAutenticado);
      expect(result.codigo, 'INVALID_CREDENTIALS');
    });

    test('maps 403 to prohibido', () {
      final result = mapDioExceptionToAppException(
          _badResponse(403, {'mensaje': 'Prohibido'}));
      expect(result.type, AppExceptionType.prohibido);
    });

    test('maps 404 to noEncontrado', () {
      final result = mapDioExceptionToAppException(
        _badResponse(
            404, {'mensaje': 'No encontrado', 'codigo': 'CREDIT_NOT_FOUND'}),
      );
      expect(result.type, AppExceptionType.noEncontrado);
      expect(result.codigo, 'CREDIT_NOT_FOUND');
    });

    test('maps 409 to conflicto', () {
      final result = mapDioExceptionToAppException(
        _badResponse(
            409, {'mensaje': 'Conflicto', 'codigo': 'INVALID_TRANSITION'}),
      );
      expect(result.type, AppExceptionType.conflicto);
    });

    test('maps 429 to demasiadasSolicitudes even without a JSON body', () {
      final result = mapDioExceptionToAppException(_badResponse(429, null));
      expect(result.type, AppExceptionType.demasiadasSolicitudes);
      expect(result.mensaje, isNotEmpty);
    });

    group(
        '429 discrepancy: express-rate-limit responds outside the documented '
        '{mensaje,codigo,requestId} envelope for /prestamos/solicitar and '
        '/client/auth/login — the app must tolerate every shape defensively, '
        'never crash, never fabricate codigo/requestId, and never surface '
        'the raw body or auto-retry from Retry-After', () {
      test('429 with the proper JSON envelope is used as-is', () {
        final result = mapDioExceptionToAppException(_badResponse(429, {
          'mensaje': 'Demasiadas solicitudes, intenta más tarde.',
          'codigo': 'RATE_LIMITED',
          'requestId': 'req-429',
        }));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
        expect(result.codigo, 'RATE_LIMITED');
        expect(result.requestId, 'req-429');
      });

      test(
          'a plain-text 429 body (express-rate-limit default) never leaks the '
          'raw text and never fabricates codigo/requestId', () {
        final result = mapDioExceptionToAppException(_badResponse(
          429,
          'Too many requests, please try again later.',
        ));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
        expect(result.mensaje, isNot(contains('Too many requests')));
        expect(result.codigo, isNull);
        expect(result.requestId, isNull);
      });

      test('an empty-body 429 (null data) is handled without crashing', () {
        final result = mapDioExceptionToAppException(_badResponse(429, null));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
        expect(result.codigo, isNull);
        expect(result.requestId, isNull);
      });

      test('an empty-string-body 429 is handled without crashing', () {
        final result = mapDioExceptionToAppException(_badResponse(429, ''));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
        expect(result.mensaje, isNotEmpty);
      });

      test('Retry-After expressed in seconds does not affect mapping', () {
        final result = mapDioExceptionToAppException(_badResponse(
          429,
          'Too many requests, please try again later.',
          headers: {
            'retry-after': ['3600'],
          },
        ));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
      });

      test('Retry-After expressed as an HTTP-date does not affect mapping', () {
        final result = mapDioExceptionToAppException(_badResponse(
          429,
          'Too many requests, please try again later.',
          headers: {
            'retry-after': ['Wed, 21 Oct 2026 07:28:00 GMT'],
          },
        ));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
      });

      test('a missing Retry-After header does not affect mapping', () {
        final result = mapDioExceptionToAppException(_badResponse(
          429,
          'Too many requests, please try again later.',
        ));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
      });

      test('an invalid/garbage Retry-After header does not crash the mapper',
          () {
        final result = mapDioExceptionToAppException(_badResponse(
          429,
          'Too many requests, please try again later.',
          headers: {
            'retry-after': ['not-a-valid-value'],
          },
        ));
        expect(result.type, AppExceptionType.demasiadasSolicitudes);
      });
    });

    test('maps 500 to errorServidor without leaking server internals', () {
      final result = mapDioExceptionToAppException(
        _badResponse(500, {'mensaje': 'Internal error: stack trace leaked'}),
      );
      expect(result.type, AppExceptionType.errorServidor);
    });

    test(
        'falls back to a safe generic message when the body is not the expected envelope',
        () {
      final result = mapDioExceptionToAppException(
          _badResponse(400, 'plain text, not JSON'));
      expect(result.type, AppExceptionType.validacion);
      expect(result.mensaje, 'Los datos enviados no son válidos.');
      expect(result.codigo, isNull);
    });

    test('maps cancel to desconocido', () {
      final result = mapDioExceptionToAppException(
        DioException(requestOptions: _options(), type: DioExceptionType.cancel),
      );
      expect(result.type, AppExceptionType.desconocido);
    });
  });
}
