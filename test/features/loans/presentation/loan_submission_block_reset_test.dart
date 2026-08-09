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
import 'package:prestamesta_app/features/loans/presentation/loan_submission_state.dart';

import '../../../support/fake_http_client_adapter.dart';

/// Checkpoint 6 review of the ambiguous-outcome guarantees: confirms, at the
/// provider level (not just the bare `LoanSubmissionController` class),
/// that the permanent post-`outcomeUnknown` block is scoped to the
/// client-id-keyed controller instance — so logout (client id -> null)
/// really does lift it, via the same provider-recreation mechanism as the
/// draft and the session summary, not via any explicit "unblock" method
/// (there still isn't one, and there shouldn't be).
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

AuthRepository _authRepository({required int clienteId}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(
      (options) => jsonResponseBody({
        'mensaje': 'ok',
        'token': _token(clienteId),
        'cliente': {'id': clienteId, 'nombre': 'Juan', 'email': 'juan@x.com'},
      }, 200),
    );
  return AuthRepository(dio);
}

LoanRequest _request() =>
    LoanRequest(creditoId: 1, montoSolicitado: Decimal.parse('10000'));

/// `AuthController._restore()` is async (reads token/cliente from storage);
/// letting it finish *before* calling `completeMfaLogin` avoids a race where
/// restore's own (later-resolving) unauthenticated result would otherwise
/// stomp on the session `completeMfaLogin` just established.
Future<void> _pump([int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
      'after an outcomeUnknown, logging out and back in yields a fresh, '
      'unblocked controller — same mechanism that resets the draft and the '
      'session summary, not a dedicated "unblock" method', () async {
    var callCount = 0;
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_authRepository(clienteId: 1)),
      sessionLocalStorageProvider
          .overrideWithValue(SessionLocalStorage(_FakeSecureStorage())),
      loansRepositoryProvider.overrideWithValue(
        LoansRepository(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = FakeHttpClientAdapter((options) {
              callCount++;
              throw DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout);
            }),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await _pump();

    await container.read(authControllerProvider.notifier).completeMfaLogin(
        token: _token(1),
        cliente:
            const ClienteSummary(id: 1, nombre: 'Juan', email: 'juan@x.com'));
    await container
        .read(loanSubmissionControllerProvider.notifier)
        .submit(_request());
    expect(container.read(loanSubmissionControllerProvider).status,
        LoanSubmissionStatus.outcomeUnknown);

    // Still blocked while the same client id is authenticated — no local
    // "try again" is ever allowed for this same attempt.
    await container
        .read(loanSubmissionControllerProvider.notifier)
        .submit(_request());
    expect(callCount, 1, reason: 'blocked: no second network call');

    await container.read(authControllerProvider.notifier).logout();
    await container.read(authControllerProvider.notifier).completeMfaLogin(
        token: _token(1),
        cliente:
            const ClienteSummary(id: 1, nombre: 'Juan', email: 'juan@x.com'));

    // A fresh controller for the (re-)authenticated client id — idle again,
    // not outcomeUnknown, and able to submit.
    expect(container.read(loanSubmissionControllerProvider).status,
        LoanSubmissionStatus.idle);
  });
}
