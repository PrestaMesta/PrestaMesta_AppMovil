import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/credits/data/credits_repository.dart';
import 'package:prestamesta_app/features/credits/presentation/credits_controller.dart';
import 'package:prestamesta_app/features/credits/presentation/credits_state.dart';

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

final _otherCredito = {
  'id': 2,
  'nombre': 'Crédito Plus',
  'monto_minimo': '5000.00',
  'monto_maximo': '50000.00',
  'tasa_interes_anual': '18.00',
  'plazo_meses': 24,
  'creado_en': '2026-08-02T02:43:54.000Z',
};

CreditsRepository _repository(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return CreditsRepository(dio);
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('CreditsController.loadInitial', () {
    test('successful initial load transitions to data', () async {
      var callCount = 0;
      final controller = CreditsController(
        _repository((options) {
          callCount++;
          return jsonResponseBody([_oneCredito], 200);
        }),
      );

      await controller.loadInitial();

      expect(controller.state.status, CreditsStatus.data);
      expect(controller.state.creditos, hasLength(1));
      expect(callCount, 1);
    });

    test('an empty catalog is data with an empty list, not an error', () async {
      final controller = CreditsController(
          _repository((options) => jsonResponseBody([], 200)));

      await controller.loadInitial();

      expect(controller.state.status, CreditsStatus.data);
      expect(controller.state.isEmpty, isTrue);
    });

    test('a failed initial load transitions to initialError', () async {
      final controller = CreditsController(
        _repository(
            (options) => jsonResponseBody({'mensaje': 'Error interno'}, 500)),
      );

      await controller.loadInitial();

      expect(controller.state.status, CreditsStatus.initialError);
      expect(controller.state.error, isNotNull);
    });

    test('retry after an initial error can succeed', () async {
      var attempt = 0;
      final controller = CreditsController(
        _repository((options) {
          attempt++;
          if (attempt == 1) return jsonResponseBody({'mensaje': 'x'}, 500);
          return jsonResponseBody([_oneCredito], 200);
        }),
      );

      await controller.loadInitial();
      expect(controller.state.status, CreditsStatus.initialError);

      await controller.retry();

      expect(controller.state.status, CreditsStatus.data);
      expect(controller.state.creditos, hasLength(1));
    });

    test(
        'calling loadInitial twice only issues one request (no duplicate load)',
        () async {
      var callCount = 0;
      final controller = CreditsController(
        _repository((options) {
          callCount++;
          return jsonResponseBody([_oneCredito], 200);
        }),
      );

      await Future.wait([controller.loadInitial(), controller.loadInitial()]);

      expect(callCount, 1);
    });
  });

  group('CreditsController.refresh', () {
    test('a successful refresh replaces the catalog', () async {
      var attempt = 0;
      final controller = CreditsController(
        _repository((options) {
          attempt++;
          return jsonResponseBody(
              attempt == 1 ? [_oneCredito] : [_oneCredito, _otherCredito], 200);
        }),
      );
      await controller.loadInitial();
      expect(controller.state.creditos, hasLength(1));

      await controller.refresh();

      expect(controller.state.status, CreditsStatus.data);
      expect(controller.state.creditos, hasLength(2));
    });

    test('a failed refresh keeps the previous data visible (refreshError)',
        () async {
      var attempt = 0;
      final controller = CreditsController(
        _repository((options) {
          attempt++;
          if (attempt == 1) return jsonResponseBody([_oneCredito], 200);
          return jsonResponseBody({'mensaje': 'Error interno'}, 500);
        }),
      );
      await controller.loadInitial();

      await controller.refresh();

      expect(controller.state.status, CreditsStatus.refreshError);
      expect(controller.state.creditos, hasLength(1)); // previous data retained
      expect(controller.state.error, isNotNull);
    });

    test(
        'a later-started request wins over an earlier one that resolves after it',
        () async {
      final firstCompleter = Completer<ResponseBody>();
      var callIndex = 0;
      final controller = CreditsController(
        _repository((options) {
          callIndex++;
          if (callIndex == 1) {
            // The first (older) request never resolves until we say so below.
            return firstCompleter.future;
          }
          return jsonResponseBody([_oneCredito, _otherCredito], 200);
        }),
      );

      // Start an initial load (call #1, deliberately left pending) ...
      final firstLoad = controller.loadInitial();
      // ... then start a refresh (call #2) which resolves immediately.
      await Future<void>.delayed(Duration.zero);
      await controller.refresh();

      expect(controller.state.status, CreditsStatus.data);
      expect(controller.state.creditos, hasLength(2));

      // Now let the OLD, slower request finally resolve — it must be
      // ignored because a newer request (the refresh) already won.
      firstCompleter.complete(jsonResponseBody([_oneCredito], 200));
      await firstLoad;
      await _pump();

      expect(controller.state.creditos, hasLength(2),
          reason: 'stale response must not overwrite newer data');
    });
  });
}
