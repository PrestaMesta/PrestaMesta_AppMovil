import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/errors/app_exception.dart';
import 'package:prestamesta_app/features/credits/data/credits_repository.dart';

import '../../../support/fake_http_client_adapter.dart';

final _oneCredito = {
  'id': 1,
  'nombre': 'Crédito Personal Express',
  'monto_minimo': '1000.00',
  'monto_maximo': '20000.00',
  'tasa_interes_anual': '24.00',
  'plazo_meses': 12,
  'creado_en': '2026-08-02T02:43:54.000Z',
};

CreditsRepository _repositoryRespondingWith(
    ResponseBody Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return CreditsRepository(dio);
}

void main() {
  group('CreditsRepository.fetchCreditos', () {
    test('uses GET on the exact route with no body', () async {
      late RequestOptions captured;
      final repository = _repositoryRespondingWith((options) {
        captured = options;
        return jsonResponseBody([_oneCredito], 200);
      });

      await repository.fetchCreditos();

      expect(captured.method, 'GET');
      expect(captured.path, '/prestamos/creditos');
      expect(captured.data, isNull);
    });

    test(
        'marks the request as requiring auth (Authorization gets attached upstream)',
        () async {
      late RequestOptions captured;
      final repository = _repositoryRespondingWith((options) {
        captured = options;
        return jsonResponseBody([], 200);
      });

      await repository.fetchCreditos();

      expect(captured.extra['requiresAuth'], isTrue);
    });

    test('parses every field of a full response', () async {
      final repository = _repositoryRespondingWith(
        (options) => jsonResponseBody([_oneCredito], 200),
      );

      final creditos = await repository.fetchCreditos();

      expect(creditos, hasLength(1));
      expect(creditos.single.nombre, 'Crédito Personal Express');
      expect(creditos.single.plazoMeses, 12);
    });

    test('accepts an empty list as a valid, non-error response', () async {
      final repository =
          _repositoryRespondingWith((options) => jsonResponseBody([], 200));

      final creditos = await repository.fetchCreditos();

      expect(creditos, isEmpty);
    });

    test(
        'rejects an incomplete credit (missing field) as AppException(respuestaInvalida)',
        () async {
      final incomplete = Map<String, dynamic>.from(_oneCredito)
        ..remove('tasa_interes_anual');
      final repository = _repositoryRespondingWith(
        (options) => jsonResponseBody([incomplete], 200),
      );

      await expectLater(
        repository.fetchCreditos(),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.respuestaInvalida)),
      );
    });

    test('rejects an invalid decimal string in the response', () async {
      final broken = Map<String, dynamic>.from(_oneCredito)
        ..['monto_minimo'] = 'not-a-decimal';
      final repository = _repositoryRespondingWith(
        (options) => jsonResponseBody([broken], 200),
      );

      await expectLater(
        repository.fetchCreditos(),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.respuestaInvalida)),
      );
    });

    test(
        'rejects a response shaped as an object instead of the documented array',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = FakeHttpClientAdapter(
          (options) => ResponseBody.fromString(
            '{"creditos": []}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
      final repository = CreditsRepository(dio);

      await expectLater(
        repository.fetchCreditos(),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.respuestaInvalida)),
      );
    });

    test('maps a 401 to AppException(noAutenticado)', () async {
      final repository = _repositoryRespondingWith(
        (options) => jsonResponseBody(
            {'mensaje': 'Token invalido', 'codigo': 'TOKEN_INVALID'}, 401),
      );

      await expectLater(
        repository.fetchCreditos(),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.noAutenticado)),
      );
    });

    test('maps a 403 to AppException(prohibido)', () async {
      final repository = _repositoryRespondingWith(
        (options) => jsonResponseBody({'mensaje': 'Prohibido'}, 403),
      );

      await expectLater(
        repository.fetchCreditos(),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.prohibido)),
      );
    });

    test('maps a 500 to AppException(errorServidor) without leaking internals',
        () async {
      final repository = _repositoryRespondingWith(
        (options) =>
            jsonResponseBody({'mensaje': 'stack trace leaked here'}, 500),
      );

      await expectLater(
        repository.fetchCreditos(),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.errorServidor)),
      );
    });

    test('maps a connection timeout to AppException(tiempoAgotado)', () async {
      final repository = _repositoryRespondingWith(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.connectionTimeout),
      );

      await expectLater(
        repository.fetchCreditos(),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.tiempoAgotado)),
      );
    });
  });
}
