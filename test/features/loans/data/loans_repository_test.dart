import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/errors/app_exception.dart';
import 'package:prestamesta_app/features/loans/data/guarantor.dart';
import 'package:prestamesta_app/features/loans/data/loan_request.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';

import '../../../support/fake_http_client_adapter.dart';

final _successJson = {
  'mensaje': 'Solicitud de préstamo enviada con éxito',
  'prestamoId': 1,
  'fechaSolicitud': '2026-08-02T20:46:06.000Z',
  'montoSolicitado': 10000,
  'montoTotalAPagar': '12400.00',
  'estado': 'PENDIENTE',
};

LoanRequest _request({Guarantor? aval}) {
  return LoanRequest(
      creditoId: 1, montoSolicitado: Decimal.parse('10000'), aval: aval);
}

LoansRepository _repository(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return LoansRepository(dio);
}

void main() {
  group('LoansRepository.submit — request shape', () {
    test('uses POST on the exact route', () async {
      late RequestOptions captured;
      final repository = _repository((options) {
        captured = options;
        return jsonResponseBody(_successJson, 201);
      });

      await repository.submit(_request());

      expect(captured.method, 'POST');
      expect(captured.path, '/prestamos/solicitar');
    });

    test('marks the request as requiring auth', () async {
      late RequestOptions captured;
      final repository = _repository((options) {
        captured = options;
        return jsonResponseBody(_successJson, 201);
      });

      await repository.submit(_request());

      expect(captured.extra['requiresAuth'], isTrue);
    });

    test('sends the exact body without aval', () async {
      late RequestOptions captured;
      final repository = _repository((options) {
        captured = options;
        return jsonResponseBody(_successJson, 201);
      });

      await repository.submit(_request());

      final body = captured.data as Map;
      expect(body.keys.toSet(), {'credito_id', 'monto_solicitado'});
    });

    test('sends the exact body with aval', () async {
      late RequestOptions captured;
      final repository = _repository((options) {
        captured = options;
        return jsonResponseBody(_successJson, 201);
      });

      await repository.submit(
        _request(
            aval: const Guarantor(
                nombre: 'Roberto Gómez', telefono: '8711234567')),
      );

      final body = captured.data as Map;
      expect(body.keys.toSet(), {'credito_id', 'monto_solicitado', 'aval'});
    });

    test('never sends a forbidden field', () async {
      late RequestOptions captured;
      final repository = _repository((options) {
        captured = options;
        return jsonResponseBody(_successJson, 201);
      });

      await repository.submit(
        _request(
            aval: const Guarantor(
                nombre: 'Roberto Gómez', telefono: '8711234567')),
      );

      final body = captured.data as Map;
      const forbidden = {
        'cliente_id',
        'administrador_id',
        'monto_total_a_pagar',
        'saldo_pendiente',
        'estado',
        'fecha_solicitud',
      };
      expect(body.keys.toSet().intersection(forbidden), isEmpty);
    });
  });

  group('LoansRepository.submit — success', () {
    test('parses the 201 response', () async {
      final repository =
          _repository((options) => jsonResponseBody(_successJson, 201));

      final response = await repository.submit(_request());

      expect(response.prestamoId, 1);
      expect(response.montoTotalAPagar, Decimal.parse('12400.00'));
    });
  });

  group('LoansRepository.submit — definite server errors', () {
    test('maps 400 VALIDATION_ERROR', () async {
      final repository = _repository(
        (options) => jsonResponseBody({
          'mensaje': 'Los datos enviados no son válidos.',
          'codigo': 'VALIDATION_ERROR',
          'detalles': [
            {'campo': 'monto_solicitado', 'mensaje': 'debe ser mayor a 0'},
          ],
        }, 400),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppExceptionType.validacion)
              .having((e) => e.codigo, 'codigo', 'VALIDATION_ERROR'),
        ),
      );
    });

    test('maps 404 CREDIT_NOT_FOUND', () async {
      final repository = _repository(
        (options) => jsonResponseBody({
          'mensaje': 'Tipo de credito no encontrado.',
          'codigo': 'CREDIT_NOT_FOUND'
        }, 404),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppExceptionType.noEncontrado)
              .having((e) => e.codigo, 'codigo', 'CREDIT_NOT_FOUND'),
        ),
      );
    });

    test('maps 401 TOKEN_EXPIRED', () async {
      final repository = _repository(
        (options) => jsonResponseBody(
            {'mensaje': 'Token expirado', 'codigo': 'TOKEN_EXPIRED'}, 401),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppExceptionType.noAutenticado)
              .having((e) => e.codigo, 'codigo', 'TOKEN_EXPIRED'),
        ),
      );
    });

    test('maps 401 TOKEN_INVALID', () async {
      final repository = _repository(
        (options) => jsonResponseBody(
            {'mensaje': 'Token invalido', 'codigo': 'TOKEN_INVALID'}, 401),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having((e) => e.codigo, 'codigo', 'TOKEN_INVALID')),
      );
    });

    test(
        'an admin-audience token (structurally valid JWT, wrong audience) is '
        'rejected exactly like the real server: 401 TOKEN_INVALID, never '
        '403 FORBIDDEN, never worded as invalid credentials — '
        '`POST /prestamos/solicitar` uses `verificarTokenCliente`, not '
        '`verificarTokenClienteOAdmin`, so an admin JWT fails purely on '
        'audience mismatch (confirmed against '
        'PrestaMesta_Server/middleware/authMiddleware.js + utils/jwt.js)',
        () async {
      final repository = _repository(
        (options) => jsonResponseBody(
            {'mensaje': 'Token invalido.', 'codigo': 'TOKEN_INVALID'}, 401),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having((e) => e.codigo, 'codigo', 'TOKEN_INVALID')
            .having((e) => e.type, 'type', AppExceptionType.noAutenticado)
            .having(
              (e) => e.mensaje.toLowerCase(),
              'mensaje never claims wrong credentials',
              isNot(contains('credencial')),
            )),
      );
    });

    test('maps 403 FORBIDDEN', () async {
      final repository = _repository(
        (options) => jsonResponseBody(
            {'mensaje': 'Prohibido', 'codigo': 'FORBIDDEN'}, 403),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.prohibido)),
      );
    });

    test(
        'maps 429 (plain-text body from express-rate-limit, not the JSON envelope) — '
        'this is a documented implementation discrepancy, never surfaced raw to the user',
        () async {
      final repository = _repository(
        (options) => ResponseBody.fromString(
          'Too many requests, please try again later.',
          429,
          headers: {
            'content-type': ['text/html; charset=utf-8'],
            'retry-after': ['3600'],
          },
        ),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having(
                (e) => e.type, 'type', AppExceptionType.demasiadasSolicitudes)
            .having((e) => e.mensaje, 'mensaje',
                isNot(contains('Too many requests')))
            .having((e) => e.codigo, 'codigo', isNull)),
      );
    });

    test(
        'also tolerates a 429 with the proper JSON envelope, in case the '
        'backend normalizes this route to go through errorHandler.js later',
        () async {
      final repository = _repository(
        (options) => jsonResponseBody({
          'mensaje': 'Demasiadas solicitudes de préstamo. Intenta más tarde.',
          'codigo': 'RATE_LIMITED',
          'requestId': 'req-429',
        }, 429),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having(
                (e) => e.type, 'type', AppExceptionType.demasiadasSolicitudes)
            .having((e) => e.codigo, 'codigo', 'RATE_LIMITED')),
      );
    });

    test('tolerates a 429 with an empty body (no crash, no fabricated fields)',
        () async {
      final repository = _repository(
        (options) => ResponseBody.fromString('', 429, headers: {
          'content-type': ['text/plain'],
        }),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having(
                (e) => e.type, 'type', AppExceptionType.demasiadasSolicitudes)
            .having((e) => e.codigo, 'codigo', isNull)
            .having((e) => e.requestId, 'requestId', isNull)),
      );
    });

    test('maps 500 INTERNAL_ERROR without leaking internals', () async {
      final repository = _repository(
        (options) => jsonResponseBody({
          'mensaje': 'No fue posible procesar la solicitud.',
          'codigo': 'INTERNAL_ERROR'
        }, 500),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.errorServidor)),
      );
    });

    test('rejects a malformed 201 response as a controlled data error',
        () async {
      final repository = _repository(
        (options) =>
            jsonResponseBody({'mensaje': 'ok'}, 201), // missing everything else
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.respuestaInvalida)),
      );
    });
  });

  group('LoansRepository.submit — ambiguous outcome', () {
    test(
        'connectionTimeout is NOT ambiguous (handshake never completed, nothing was sent)',
        () async {
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.connectionTimeout),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.tiempoAgotado)),
      );
    });

    test('sendTimeout is ambiguous', () async {
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.sendTimeout),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<LoanSubmissionAmbiguousException>()),
      );
    });

    test('receiveTimeout is ambiguous (the request was very likely fully sent)',
        () async {
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.receiveTimeout),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<LoanSubmissionAmbiguousException>()),
      );
    });

    test('a dropped connection (connectionError) is ambiguous', () async {
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<LoanSubmissionAmbiguousException>()),
      );
    });

    test('an unknown Dio error is treated as ambiguous (conservative default)',
        () async {
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.unknown),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<LoanSubmissionAmbiguousException>()),
      );
    });

    test(
        'transformTimeout (decoding the response body itself timed out) is ambiguous — '
        'a response almost certainly already arrived', () async {
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.transformTimeout),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<LoanSubmissionAmbiguousException>()),
      );
    });

    test(
        'cancel after the send had already started is ambiguous — Dio never tells '
        'us how much (if any) of the request the server already received',
        () async {
      // Simulated by a bare `cancel` DioException with no response — this
      // app has no CancelToken wired into submit() at all, so a `cancel`
      // reaching here always means "no proof of pre-send," never a proven
      // preflight cancellation.
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.cancel),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<LoanSubmissionAmbiguousException>()),
      );
    });

    test(
        'cancel with no further information is ambiguous (same case as above, '
        'named separately to make the "insufficient information" scenario explicit)',
        () async {
      final repository = _repository(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: null,
          message: null,
        ),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<LoanSubmissionAmbiguousException>()),
      );
    });

    test(
        'badCertificate (TLS handshake failed before any HTTP request was sent) is NOT ambiguous',
        () async {
      final repository = _repository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.badCertificate),
      );

      await expectLater(
        repository.submit(_request()),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.sinConexion)),
      );
    });

    test('a real HTTP response (badResponse) is never ambiguous, even for 5xx',
        () async {
      final repository =
          _repository((options) => jsonResponseBody({'mensaje': 'boom'}, 500));

      await expectLater(
          repository.submit(_request()), throwsA(isA<AppException>()));
    });
  });

  test(
      'never retries automatically: exactly one request per submit() call, even on ambiguous failure',
      () async {
    var callCount = 0;
    final repository = _repository((options) {
      callCount++;
      throw DioException(
          requestOptions: options, type: DioExceptionType.receiveTimeout);
    });

    try {
      await repository.submit(_request());
    } catch (_) {
      // expected: this responder always throws.
    }

    expect(callCount, 1);
  });
}
