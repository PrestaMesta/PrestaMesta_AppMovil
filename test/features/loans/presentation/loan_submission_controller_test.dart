import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/loans/data/loan_request.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_controller.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_state.dart';

import '../../../support/fake_http_client_adapter.dart';

final _successJson = {
  'mensaje': 'Solicitud de préstamo enviada con éxito',
  'prestamoId': 1,
  'fechaSolicitud': '2026-08-02T20:46:06.000Z',
  'montoSolicitado': 10000,
  'montoTotalAPagar': '12400.00',
  'estado': 'PENDIENTE',
};

LoanRequest _request() =>
    LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000'));

LoansRepository _repository(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return LoansRepository(dio);
}

void main() {
  test('starts idle', () {
    final controller = LoanSubmissionController(
      _repository((_) => throw StateError('unused')),
    );
    expect(controller.state.status, LoanSubmissionStatus.idle);
  });

  group('successful submission', () {
    test('goes idle -> submitting -> success with the server response',
        () async {
      final statuses = <LoanSubmissionStatus>[];
      final controller = LoanSubmissionController(
          _repository((options) => jsonResponseBody(_successJson, 201)))
        ..addListener((state) => statuses.add(state.status));

      await controller.submit(_request());

      // `addListener` fires once immediately with the current state (idle)
      // when registered, then again for each real transition.
      expect(statuses, [
        LoanSubmissionStatus.idle,
        LoanSubmissionStatus.submitting,
        LoanSubmissionStatus.success,
      ]);
      expect(controller.state.response?.prestamoId, 1);
    });
  });

  group('recoverable failure', () {
    test('transitions to failure, not success', () async {
      final controller = LoanSubmissionController(
        _repository(
          (options) => jsonResponseBody({
            'mensaje': 'Los datos enviados no son válidos.',
            'codigo': 'VALIDATION_ERROR'
          }, 400),
        ),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.failure);
      expect(controller.state.error?.codigo, 'VALIDATION_ERROR');
    });

    test(
        'a subsequent submit() after a recoverable failure is allowed (manual retry, never automatic)',
        () async {
      var attempt = 0;
      final controller = LoanSubmissionController(
        _repository((options) {
          attempt++;
          if (attempt == 1) {
            return jsonResponseBody(
                {'mensaje': 'x', 'codigo': 'VALIDATION_ERROR'}, 400);
          }
          return jsonResponseBody(_successJson, 201);
        }),
      );

      await controller.submit(_request());
      expect(controller.state.status, LoanSubmissionStatus.failure);

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.success);
      expect(attempt, 2);
    });
  });

  group('ambiguous outcome', () {
    test('transitions to outcomeUnknown, not failure and not success',
        () async {
      final controller = LoanSubmissionController(
        _repository((options) => throw DioException(
            requestOptions: options, type: DioExceptionType.receiveTimeout)),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.outcomeUnknown);
    });

    test(
        'permanently blocks further submit() calls on the same controller — no reintento inmediato',
        () async {
      var callCount = 0;
      final controller = LoanSubmissionController(
        _repository((options) {
          callCount++;
          throw DioException(
              requestOptions: options, type: DioExceptionType.receiveTimeout);
        }),
      );

      await controller.submit(_request());
      expect(controller.state.status, LoanSubmissionStatus.outcomeUnknown);

      // Even if the caller tries again (accidentally or otherwise), no
      // second network call is ever made for this controller instance.
      await controller.submit(_request());
      await controller.submit(_request());

      expect(callCount, 1);
    });

    test(
        'connectionError transitions to outcomeUnknown — a socket drop can '
        'happen after the server already received the request', () async {
      final controller = LoanSubmissionController(
        _repository((options) => throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError)),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.outcomeUnknown);
    });

    test(
        'cancel after the send had started transitions to outcomeUnknown, '
        'not failure — Dio gives no proof the server never received it',
        () async {
      final controller = LoanSubmissionController(
        _repository((options) => throw DioException(
            requestOptions: options, type: DioExceptionType.cancel)),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.outcomeUnknown);
    });

    test(
        'cancel with no further information about the send state also '
        'transitions to outcomeUnknown (insufficient information is never '
        'treated as proof of non-delivery)', () async {
      final controller = LoanSubmissionController(
        _repository((options) => throw DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: null,
              message: null,
            )),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.outcomeUnknown);
    });
  });

  group('confirmed local-only failures (proven pre-send)', () {
    test(
        'connectionTimeout before any data was sent transitions to a recoverable '
        'failure, not outcomeUnknown — the TCP handshake never completed',
        () async {
      final controller = LoanSubmissionController(
        _repository((options) => throw DioException(
            requestOptions: options, type: DioExceptionType.connectionTimeout)),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.failure);
    });

    test(
        'badCertificate during the TLS handshake (before any HTTP request was '
        'written) transitions to a recoverable failure, not outcomeUnknown',
        () async {
      final controller = LoanSubmissionController(
        _repository((options) => throw DioException(
            requestOptions: options, type: DioExceptionType.badCertificate)),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.failure);
    });
  });

  group('double/triple submit protection', () {
    test('two rapid submit() calls issue exactly one request', () async {
      var callCount = 0;
      final controller = LoanSubmissionController(
        _repository((options) {
          callCount++;
          return jsonResponseBody(_successJson, 201);
        }),
      );

      await Future.wait(
          [controller.submit(_request()), controller.submit(_request())]);

      expect(callCount, 1);
    });

    test('three rapid submit() calls issue exactly one request', () async {
      var callCount = 0;
      final controller = LoanSubmissionController(
        _repository((options) {
          callCount++;
          return jsonResponseBody(_successJson, 201);
        }),
      );

      await Future.wait([
        controller.submit(_request()),
        controller.submit(_request()),
        controller.submit(_request()),
      ]);

      expect(callCount, 1);
    });

    test(
        'submit() after success is a no-op — a completed submission can never be repeated',
        () async {
      var callCount = 0;
      final controller = LoanSubmissionController(
        _repository((options) {
          callCount++;
          return jsonResponseBody(_successJson, 201);
        }),
      );

      await controller.submit(_request());
      await controller.submit(_request());

      expect(callCount, 1);
      expect(controller.state.status, LoanSubmissionStatus.success);
    });
  });

  group('403/429 do not clear the session', () {
    // This controller has no knowledge of the session at all — it only ever
    // throws/holds an AppException. The actual "don't clear session on
    // 403/429" guarantee lives in core/network/auth_interceptor.dart
    // (isSessionRejection), already covered by
    // test/core/network/auth_interceptor_test.dart and
    // test/features/auth/presentation/auth_session_rejection_integration_test.dart.
    // These two tests just confirm this controller reports them as ordinary
    // recoverable failures, not anything session-related.
    test('403 is reported as an ordinary failure', () async {
      final controller = LoanSubmissionController(
        _repository((options) => jsonResponseBody(
            {'mensaje': 'Prohibido', 'codigo': 'FORBIDDEN'}, 403)),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.failure);
    });

    test('429 is reported as an ordinary failure', () async {
      final controller = LoanSubmissionController(
        _repository(
          (options) => ResponseBody.fromString(
              'Too many requests, please try again later.', 429,
              headers: {
                'content-type': ['text/html'],
              }),
        ),
      );

      await controller.submit(_request());

      expect(controller.state.status, LoanSubmissionStatus.failure);
    });
  });
}
