import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loans_list_controller.dart';
import 'package:prestamesta_app/features/loans/presentation/loans_list_state.dart';

import '../../../support/fake_http_client_adapter.dart';

Map<String, dynamic> _loan(int id, {String estado = 'PENDIENTE'}) => {
      'id': id,
      'credito': {'id': 1, 'nombre': 'Crédito Personal Express'},
      'monto_solicitado': '10000.00',
      'monto_total_a_pagar': '13000.00',
      'saldo_pendiente': '13000.00',
      'estado': estado,
      'fecha_solicitud': '2026-08-02T20:46:06.000Z',
      'fecha_decision': null,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> loans,
        {int page = 1, int limit = 20, int? total}) =>
    {
      'data': loans,
      'pagination': {
        'page': page,
        'limit': limit,
        'total': total ?? loans.length,
        'totalPages':
            loans.isEmpty ? 0 : ((total ?? loans.length) / limit).ceil(),
      },
    };

LoansRepository _repository(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return LoansRepository(dio);
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('LoansListController.loadInitial', () {
    test('successful initial load transitions to data', () async {
      var callCount = 0;
      final controller = LoansListController(_repository((options) {
        callCount++;
        return jsonResponseBody(_page([_loan(1)]), 200);
      }));

      await controller.loadInitial();

      expect(controller.state.status, LoansListStatus.data);
      expect(controller.state.loans, hasLength(1));
      expect(callCount, 1);
    });

    test('an empty list is data with an empty list, not an error', () async {
      final controller = LoansListController(
          _repository((options) => jsonResponseBody(_page(const []), 200)));

      await controller.loadInitial();

      expect(controller.state.status, LoansListStatus.data);
      expect(controller.state.isEmpty, isTrue);
      expect(controller.state.mostRecent, isNull);
    });

    test('mostRecent is the first row (server sorts newest first)', () async {
      final controller = LoansListController(_repository(
          (options) => jsonResponseBody(_page([_loan(2), _loan(1)]), 200)));

      await controller.loadInitial();

      expect(controller.state.mostRecent!.id, 2);
    });

    test('a failed initial load transitions to initialError', () async {
      final controller = LoansListController(_repository(
          (options) => jsonResponseBody({'mensaje': 'Error interno'}, 500)));

      await controller.loadInitial();

      expect(controller.state.status, LoansListStatus.initialError);
      expect(controller.state.error, isNotNull);
    });

    test(
        'calling loadInitial twice only issues one request (no duplicate load)',
        () async {
      var callCount = 0;
      final controller = LoansListController(_repository((options) {
        callCount++;
        return jsonResponseBody(_page([_loan(1)]), 200);
      }));

      await Future.wait([controller.loadInitial(), controller.loadInitial()]);

      expect(callCount, 1);
    });
  });

  group('LoansListController.retry', () {
    test('retry after an initial error can succeed', () async {
      var attempt = 0;
      final controller = LoansListController(_repository((options) {
        attempt++;
        if (attempt == 1) return jsonResponseBody({'mensaje': 'x'}, 500);
        return jsonResponseBody(_page([_loan(1)]), 200);
      }));

      await controller.loadInitial();
      expect(controller.state.status, LoansListStatus.initialError);

      await controller.retry();

      expect(controller.state.status, LoansListStatus.data);
      expect(controller.state.loans, hasLength(1));
    });
  });

  group('LoansListController.refresh', () {
    test('a successful refresh replaces the list and keeps the same page',
        () async {
      late RequestOptions lastRequest;
      var attempt = 0;
      final controller = LoansListController(_repository((options) {
        attempt++;
        lastRequest = options;
        return jsonResponseBody(
            _page(attempt == 1 ? [_loan(1)] : [_loan(2), _loan(1)]), 200);
      }));
      await controller.loadInitial();
      expect(controller.state.loans, hasLength(1));

      await controller.refresh();

      expect(controller.state.status, LoansListStatus.data);
      expect(controller.state.loans, hasLength(2));
      expect(lastRequest.queryParameters['page'], 1);
    });

    test('a failed refresh keeps the previous data visible (refreshError)',
        () async {
      var attempt = 0;
      final controller = LoansListController(_repository((options) {
        attempt++;
        if (attempt == 1) return jsonResponseBody(_page([_loan(1)]), 200);
        return jsonResponseBody({'mensaje': 'Error interno'}, 500);
      }));
      await controller.loadInitial();

      await controller.refresh();

      expect(controller.state.status, LoansListStatus.refreshError);
      expect(controller.state.loans, hasLength(1)); // previous data retained
      expect(controller.state.error, isNotNull);
    });

    test(
        'a later-started request wins over an earlier one that resolves after it',
        () async {
      final firstCompleter = Completer<ResponseBody>();
      var callIndex = 0;
      final controller = LoansListController(_repository((options) {
        callIndex++;
        if (callIndex == 1) return firstCompleter.future;
        return jsonResponseBody(_page([_loan(2), _loan(1)]), 200);
      }));

      final firstLoad = controller.loadInitial();
      await Future<void>.delayed(Duration.zero);
      await controller.refresh();

      expect(controller.state.loans, hasLength(2));

      firstCompleter.complete(jsonResponseBody(_page([_loan(1)]), 200));
      await firstLoad;
      await _pump();

      expect(controller.state.loans, hasLength(2),
          reason: 'stale response must not overwrite newer data');
    });
  });

  group('LoansListController pagination', () {
    test('nextPage/previousPage request the correct page numbers', () async {
      final requestedPages = <int>[];
      final controller = LoansListController(_repository((options) {
        final page = int.parse(options.queryParameters['page'].toString());
        requestedPages.add(page);
        return jsonResponseBody(
            _page([_loan(page)], page: page, total: 60), 200);
      }));

      await controller.loadInitial();
      expect(controller.state.hasNextPage, isTrue);
      expect(controller.state.hasPreviousPage, isFalse);

      await controller.nextPage();
      expect(controller.state.pagination!.page, 2);
      expect(controller.state.hasPreviousPage, isTrue);

      await controller.previousPage();
      expect(controller.state.pagination!.page, 1);

      expect(requestedPages, [1, 2, 1]);
    });

    test('nextPage is a no-op on the last page (no extra request)', () async {
      var callCount = 0;
      final controller = LoansListController(_repository((options) {
        callCount++;
        return jsonResponseBody(_page([_loan(1)], page: 1, total: 1), 200);
      }));

      await controller.loadInitial();
      await controller.nextPage();

      expect(callCount, 1);
    });

    test('previousPage is a no-op on page 1 (no extra request)', () async {
      var callCount = 0;
      final controller = LoansListController(_repository((options) {
        callCount++;
        return jsonResponseBody(_page([_loan(1)], page: 1, total: 1), 200);
      }));

      await controller.loadInitial();
      await controller.previousPage();

      expect(callCount, 1);
    });
  });

  group('LoansListController.refreshAfterSubmission', () {
    test('always jumps to page 1, even when viewing a later page', () async {
      final requestedPages = <int>[];
      final controller = LoansListController(_repository((options) {
        final page = int.parse(options.queryParameters['page'].toString());
        requestedPages.add(page);
        return jsonResponseBody(
            _page([_loan(page)], page: page, total: 60), 200);
      }));

      await controller.loadInitial();
      await controller.nextPage();
      expect(controller.state.pagination!.page, 2);

      await controller.refreshAfterSubmission();

      expect(controller.state.pagination!.page, 1);
      expect(requestedPages, [1, 2, 1]);
    });
  });
}
