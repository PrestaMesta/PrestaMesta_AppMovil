import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/network/logging_interceptor.dart';

/// `ErrorInterceptorHandler.next` completes an internal `Completer` with an
/// error; if nothing ever listens to it, `package:test` reports that as an
/// unhandled async error. This override drops the propagation instead, since
/// these tests only care about what got logged, not about the handler chain.
class _NoopErrorHandler extends ErrorInterceptorHandler {
  @override
  void next(DioException error) {}
}

void main() {
  group('SanitizingLoggingInterceptor', () {
    test(
        'redacts Authorization header and password/token/email body fields on request',
        () async {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);

      final options = RequestOptions(
        path: '/client/auth/login',
        headers: {
          'Authorization': 'Bearer super-secret-jwt',
          'Accept': 'application/json'
        },
        data: {'email': 'juan@example.com', 'password': 'miPasswordSeguro123'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(logged, hasLength(1));
      expect(logged.single, isNot(contains('super-secret-jwt')));
      expect(logged.single, isNot(contains('miPasswordSeguro123')));
      expect(logged.single, isNot(contains('juan@example.com')));
      expect(logged.single, contains('***'));
    });

    test(
        'never logs the full login request body (email+password both redacted)',
        () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(
        path: '/client/auth/login',
        data: {'email': 'ana.lopez@example.com', 'password': 'ClaveReal123'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(logged.single, isNot(contains('ana.lopez@example.com')));
      expect(logged.single, isNot(contains('ClaveReal123')));
    });

    test(
        'never logs the full register request body (nombre/email/telefono/password redacted)',
        () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(
        path: '/client/auth/register',
        data: {
          'nombre': 'Ana López',
          'email': 'ana.lopez@example.com',
          'password': 'ClaveReal123',
          'telefono': '8711234567',
        },
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(logged.single, isNot(contains('Ana López')));
      expect(logged.single, isNot(contains('ana.lopez@example.com')));
      expect(logged.single, isNot(contains('ClaveReal123')));
      expect(logged.single, isNot(contains('8711234567')));
    });

    test(
        'redacts token and nested cliente.nombre/email in a login response body',
        () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(path: '/client/auth/login');

      interceptor.onResponse(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'mensaje': 'Autenticacion exitosa',
            'token': 'eyJhbGciOiJIUzI1NiJ9.secret.sig',
            'cliente': {
              'id': 1,
              'nombre': 'Juan Pérez',
              'email': 'juan@example.com'
            },
          },
        ),
        ResponseInterceptorHandler(),
      );

      expect(logged, hasLength(1));
      expect(logged.single, isNot(contains('eyJhbGciOiJIUzI1NiJ9.secret.sig')));
      expect(logged.single, isNot(contains('Juan Pérez')));
      expect(logged.single, isNot(contains('juan@example.com')));
      // Non-sensitive fields are still visible — this isn't a blanket body ban.
      expect(logged.single, contains('Autenticacion exitosa'));
      expect(logged.single, contains('1'));
    });

    test(
        'redacts sensitive fields in an error response body, keeps the error codigo visible',
        () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(path: '/client/auth/login');

      interceptor.onError(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 401,
            data: {
              'mensaje': 'Credenciales inválidas.',
              'codigo': 'INVALID_CREDENTIALS'
            },
          ),
        ),
        _NoopErrorHandler(),
      );

      expect(logged, hasLength(1));
      expect(logged.single, contains('INVALID_CREDENTIALS'));
    });

    test('never logs a Cookie/Set-Cookie header value', () async {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(
        path: '/prestamos/creditos',
        headers: {'Cookie': 'sessionid=super-secret-cookie-value'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(logged.single, isNot(contains('super-secret-cookie-value')));
    });

    test('never logs a telefono field', () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(
        path: '/client/auth/register',
        data: {'telefono': '8711234567'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      expect(logged.single, isNot(contains('8711234567')));
    });

    test(
        'logsEnabled: false produces no output at all, regardless of kDebugMode',
        () {
      final logged = <String>[];
      final interceptor =
          SanitizingLoggingInterceptor(log: logged.add, logsEnabled: false);
      final options = RequestOptions(
        path: '/client/auth/login',
        data: {'email': 'juan@example.com', 'password': 'x'},
      );

      interceptor.onRequest(options, RequestInterceptorHandler());
      interceptor.onResponse(
        Response(
            requestOptions: options, statusCode: 200, data: {'mensaje': 'ok'}),
        ResponseInterceptorHandler(),
      );
      interceptor.onError(
        DioException(
            requestOptions: options, type: DioExceptionType.connectionError),
        _NoopErrorHandler(),
      );

      expect(logged, isEmpty);
    });

    test('logsEnabled defaults to true under flutter test (kDebugMode)', () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      expect(interceptor.logsEnabled, isTrue);
    });

    test(
        'never logs a loan request body (monto_solicitado, aval nombre/telefono/direccion/ingreso)',
        () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(
        path: '/prestamos/solicitar',
        data: {
          'credito_id': 1,
          'monto_solicitado': 10000,
          'aval': {
            'nombre': 'Roberto Gómez',
            'telefono': '8711234567',
            'direccion': 'Av. Morelos #450, Centro',
            'ingreso_mensual': 15000,
          },
        },
      );

      interceptor.onRequest(options, RequestInterceptorHandler());

      final line = logged.single;
      expect(line, isNot(contains('10000')));
      expect(line, isNot(contains('Roberto Gómez')));
      expect(line, isNot(contains('8711234567')));
      expect(line, isNot(contains('Av. Morelos')));
      expect(line, isNot(contains('15000')));
      // credito_id alone is just a catalog reference, not personal/financial
      // data — still visible, since this isn't a blanket body ban.
      expect(line, contains('credito_id'));
    });

    test('never logs a loan response body (montoSolicitado, montoTotalAPagar)',
        () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(path: '/prestamos/solicitar');

      interceptor.onResponse(
        Response(
          requestOptions: options,
          statusCode: 201,
          data: {
            'mensaje': 'Solicitud de préstamo enviada con éxito',
            'prestamoId': 1,
            'fechaSolicitud': '2026-08-02T20:46:06.000Z',
            'montoSolicitado': 10000,
            'montoTotalAPagar': '12400.00',
            'estado': 'PENDIENTE',
          },
        ),
        ResponseInterceptorHandler(),
      );

      final line = logged.single;
      expect(line, isNot(contains('10000')));
      expect(line, isNot(contains('12400.00')));
      // Non-financial fields are still visible.
      expect(line, contains('PENDIENTE'));
      expect(line, contains('prestamoId'));
    });

    test(
        'never logs the credit catalog\'s monto_minimo/monto_maximo/tasa fields',
        () {
      final logged = <String>[];
      final interceptor = SanitizingLoggingInterceptor(log: logged.add);
      final options = RequestOptions(path: '/prestamos/creditos');

      interceptor.onResponse(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: [
            {
              'id': 1,
              'nombre': 'Crédito Personal Express',
              'monto_minimo': '1000.00',
              'monto_maximo': '20000.00',
              'tasa_interes_anual': '24.00',
              'plazo_meses': 12,
            },
          ],
        ),
        ResponseInterceptorHandler(),
      );

      final line = logged.single;
      expect(line, isNot(contains('1000.00')));
      expect(line, isNot(contains('20000.00')));
    });
  });
}
