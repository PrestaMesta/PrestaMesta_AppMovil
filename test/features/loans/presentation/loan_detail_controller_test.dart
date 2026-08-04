import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/errors/app_exception.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_detail_controller.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_detail_state.dart';

import '../../../support/fake_http_client_adapter.dart';

final _detailJson = {
  'id': 1,
  'credito': {'id': 1, 'nombre': 'Crédito Personal Express'},
  'monto_solicitado': '10000.00',
  'monto_total_a_pagar': '13000.00',
  'saldo_pendiente': '13000.00',
  'estado': 'PENDIENTE',
  'fecha_solicitud': '2026-08-02T20:46:06.000Z',
  'fecha_decision': null,
  'aval': null,
};

LoansRepository _repository(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return LoansRepository(dio);
}

// Plain `test()` (not `testWidgets()`) runs in a real async zone, but
// `LoanDetailController`'s constructor fires `_fetch()` without exposing the
// future — a fixed `Future.delayed` can race Dio's own internal timer under
// load (flaky in a full suite run even though fine in isolation). Poll the
// controller's own state instead of guessing a delay.
Future<void> _pump(LoanDetailController controller) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (controller.state.status == LoanDetailStatus.loading &&
      DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('starts in loading, then transitions to data on success', () async {
    final controller = LoanDetailController(
        _repository((options) => jsonResponseBody(_detailJson, 200)), 1);

    expect(controller.state.status, LoanDetailStatus.loading);

    await _pump(controller);

    expect(controller.state.status, LoanDetailStatus.data);
    expect(controller.state.detail!.id, 1);
  });

  test('fetches by the exact loan id passed to the constructor', () async {
    late RequestOptions captured;
    final controller = LoanDetailController(_repository((options) {
      captured = options;
      return jsonResponseBody(_detailJson, 200);
    }), 42);

    await _pump(controller);

    expect(captured.path, '/client/prestamos/42');
  });

  test('a 404 transitions to error, not a crash', () async {
    final controller = LoanDetailController(
      _repository((options) => jsonResponseBody(
          {'mensaje': 'Prestamo no encontrado.', 'codigo': 'LOAN_NOT_FOUND'},
          404)),
      999,
    );

    await _pump(controller);

    expect(controller.state.status, LoanDetailStatus.error);
    expect(controller.state.error!.type, AppExceptionType.noEncontrado);
  });

  test('retry after an error can succeed', () async {
    var attempt = 0;
    final controller = LoanDetailController(
      _repository((options) {
        attempt++;
        if (attempt == 1) {
          return jsonResponseBody({'mensaje': 'Error interno'}, 500);
        }
        return jsonResponseBody(_detailJson, 200);
      }),
      1,
    );
    await _pump(controller);
    expect(controller.state.status, LoanDetailStatus.error);

    await controller.retry();

    expect(controller.state.status, LoanDetailStatus.data);
  });

  test('does not throw when disposed while a fetch is still in flight',
      () async {
    final completer = Completer<ResponseBody>();
    final controller =
        LoanDetailController(_repository((options) => completer.future), 1);

    controller.dispose();
    completer.complete(jsonResponseBody(_detailJson, 200));

    // Deliberately not polling `controller.state` here — `StateNotifier`
    // asserts on reading `.state` after `dispose()`, so this only waits for
    // the pending future to actually resolve and run past the `mounted`
    // guard without throwing.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
}
