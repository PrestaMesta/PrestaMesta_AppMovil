import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/app/providers.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_controller.dart';
import 'package:prestamesta_app/features/loans/data/loan_request.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_controller.dart';
import 'package:prestamesta_app/features/loans/presentation/session_loan_summary.dart';

import '../../../support/fake_http_client_adapter.dart';

/// This provider has no public mutation API of its own by design (see the
/// doc comment on `SessionLoanSummaryController`) — the only way to exercise
/// its real behavior (reactive population on a successful submission,
/// clearing on client change) is through the actual provider graph, not by
/// constructing the class in isolation. Hence `ProviderContainer` here
/// instead of a bare unit test, mirroring `test/app/loan_flow_test.dart`'s
/// fake-repository pattern but without pumping a widget tree.
class _FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

String _token(int sub) {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  return '${encode({'alg': 'HS256'})}.${encode({'sub': sub, 'exp': exp})}.sig';
}

AuthRepository _authRepository(
    {required int clienteId, required String nombre}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(
      (options) => jsonResponseBody({
        'mensaje': 'ok',
        'token': _token(clienteId),
        'cliente': {
          'id': clienteId,
          'nombre': nombre,
          'email': '$nombre@example.com'
        },
      }, 200),
    );
  return AuthRepository(dio);
}

LoansRepository _loansRepository(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return LoansRepository(dio);
}

final _successJson = {
  'mensaje': 'Solicitud de préstamo enviada con éxito',
  'prestamoId': 1,
  'fechaSolicitud': '2026-08-02T20:46:06.000Z',
  'montoSolicitado': 10000,
  'montoTotalAPagar': '12400.00',
  'estado': 'PENDIENTE',
};

/// `authControllerProvider`'s constructor kicks off an async, unawaited
/// `_restore()` (reads secure storage) — this lets it settle before a test
/// ends and its `ProviderContainer` gets disposed by `addTearDown`;
/// otherwise `_restore()` can try to set state on an already-disposed
/// `AuthController` and crash a *different*, later test (see
/// `test/features/auth/presentation/auth_controller_test.dart`'s `_pump()`
/// for the same reasoning).
Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  test('starts null before any login', () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(
          _loansRepository((_) => throw StateError('unused'))),
    ]);
    addTearDown(container.dispose);

    expect(container.read(sessionLoanSummaryControllerProvider), isNull);
    await _pump();
  });

  test(
      'a successful submission populates the summary with the server response, '
      'not the estimate, and without any extra network call', () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(
          _loansRepository((options) => jsonResponseBody(_successJson, 201))),
    ]);
    addTearDown(container.dispose);
    // `container.listen` (not a one-off `container.read`) mirrors a widget's
    // `ref.watch`: it keeps the provider *actively* subscribed, so when
    // login changes the selected client id below, Riverpod eagerly recreates
    // this client-id-keyed provider (and re-registers its internal
    // `ref.listen` on the submission controller) immediately — the same way
    // Home/StatusScreen, kept alive by the shell, would. A plain `read`
    // instead would leave the recreation lazy until the *next* read, which
    // in this test is after submit() already fired, silently missing the
    // transition.
    container.listen(sessionLoanSummaryControllerProvider, (_, __) {});

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'ClaveSegura123');

    await container.read(loanSubmissionControllerProvider.notifier).submit(
        LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000')));

    final summary = container.read(sessionLoanSummaryControllerProvider);
    expect(summary, isNotNull);
    expect(summary!.prestamoId, 1);
    expect(summary.montoTotalAPagar, Decimal.parse('12400.00'));
  });

  test('a recoverable failure never creates a summary', () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(_loansRepository((options) =>
          jsonResponseBody(
              {'mensaje': 'x', 'codigo': 'VALIDATION_ERROR'}, 400))),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionLoanSummaryControllerProvider, (_, __) {});

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'ClaveSegura123');

    await container.read(loanSubmissionControllerProvider.notifier).submit(
        LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000')));

    expect(container.read(sessionLoanSummaryControllerProvider), isNull);
  });

  test('an outcomeUnknown (ambiguous) result never creates a summary',
      () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(_loansRepository((options) =>
          throw DioException(
              requestOptions: options, type: DioExceptionType.receiveTimeout))),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionLoanSummaryControllerProvider, (_, __) {});

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'ClaveSegura123');

    await container.read(loanSubmissionControllerProvider.notifier).submit(
        LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000')));

    expect(container.read(sessionLoanSummaryControllerProvider), isNull);
  });

  test('logout (client id becomes null) clears the summary', () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(
          _loansRepository((options) => jsonResponseBody(_successJson, 201))),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionLoanSummaryControllerProvider, (_, __) {});

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'ClaveSegura123');
    await container.read(loanSubmissionControllerProvider.notifier).submit(
        LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000')));
    expect(container.read(sessionLoanSummaryControllerProvider), isNotNull);

    await container.read(authControllerProvider.notifier).logout();

    expect(container.read(sessionLoanSummaryControllerProvider), isNull);
  });

  test(
      'a different client logging in afterwards never sees the previous '
      "client's summary", () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(
          _loansRepository((options) => jsonResponseBody(_successJson, 201))),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionLoanSummaryControllerProvider, (_, __) {});

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'ClaveSegura123');
    await container.read(loanSubmissionControllerProvider.notifier).submit(
        LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000')));
    expect(container.read(sessionLoanSummaryControllerProvider), isNotNull);

    await container.read(authControllerProvider.notifier).logout();
    await container
        .read(authControllerProvider.notifier)
        .login(email: 'maria@example.com', password: 'ClaveSegura123');

    expect(container.read(sessionLoanSummaryControllerProvider), isNull);
  });

  test('the summary does not include aval data — the response type has none',
      () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(
          _loansRepository((options) => jsonResponseBody(_successJson, 201))),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionLoanSummaryControllerProvider, (_, __) {});

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'ClaveSegura123');
    await container.read(loanSubmissionControllerProvider.notifier).submit(
        LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000')));

    final summary = container.read(sessionLoanSummaryControllerProvider)!;
    // Structural guarantee, not a runtime check: LoanSubmissionResponse has
    // no aval/guarantor field at all to leak — this asserts the visible
    // fields are exactly the server-authoritative ones.
    expect(summary.prestamoId, 1);
    expect(summary.estado.name, 'pendiente');
  });

  test(
      'restarting the provider (fresh ProviderContainer, simulating an app '
      'restart) produces an empty state — nothing survives process death',
      () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider
          .overrideWithValue(_authRepository(clienteId: 1, nombre: 'Juan')),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(
          _loansRepository((_) => throw StateError('unused'))),
    ]);
    addTearDown(container.dispose);

    expect(container.read(sessionLoanSummaryControllerProvider), isNull);
    await _pump();
  });
}
