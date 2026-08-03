import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/app/providers.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_controller.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_state.dart';
import 'package:prestamesta_app/features/credits/data/credits_repository.dart';
import 'package:prestamesta_app/features/credits/presentation/credits_controller.dart';

import '../../../support/fake_http_client_adapter.dart';

/// These tests exercise the *real* provider graph
/// (`authControllerProvider` ↔ `creditsControllerProvider`), overriding only
/// the network-facing repositories and secure storage — proving the actual
/// wiring in `app/providers.dart`/`credits_controller.dart`, not a
/// hand-simplified stand-in for it.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

String _validJwt() {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  return '${encode({'alg': 'HS256'})}.${encode({'sub': 1, 'exp': exp})}.sig';
}

AuthRepository _loginSucceedsRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(
      (options) => jsonResponseBody({
        'mensaje': 'ok',
        'token': _validJwt(),
        'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
      }, 200),
    );
  return AuthRepository(dio);
}

CreditsRepository _countingCreditsRepository(void Function() onFetch) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      onFetch();
      return jsonResponseBody([
        {
          'id': 1,
          'nombre': 'Crédito Personal Express',
          'monto_minimo': '1000.00',
          'monto_maximo': '20000.00',
          'tasa_interes_anual': '24.00',
          'plazo_meses': 12,
          'creado_en': '2026-08-02T02:43:54.000Z',
        },
      ], 200);
    });
  return CreditsRepository(dio);
}

/// A single `Future.delayed(Duration.zero)` only drains one microtask
/// generation. A real `Dio` request (even with zero interceptors) resumes
/// across several chained `Completer`s internally — the interceptor queue's
/// `RequestInterceptorHandler`, the adapter call, the response transformer —
/// so waiting for one to fully settle needs several such ticks, not one.
Future<void> _pump([int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('does not fetch the catalog while there is no authenticated session',
      () async {
    var fetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
        // authControllerProvider always needs authRepositoryProvider to
        // build itself, even in a test that never calls login().
        authRepositoryProvider.overrideWithValue(_loginSucceedsRepository()),
        creditsRepositoryProvider
            .overrideWithValue(_countingCreditsRepository(() => fetchCount++)),
      ],
    );
    addTearDown(container.dispose);

    // Force creation, then let AuthController's local restore finish
    // (empty storage -> unauthenticated) *before* touching anything else.
    container.read(authControllerProvider);
    await _pump();
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);

    container
        .read(creditsControllerProvider); // first read, while unauthenticated
    await _pump();

    expect(fetchCount, 0);
  });

  test('fetches the catalog once a session becomes authenticated', () async {
    var fetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
        authRepositoryProvider.overrideWithValue(_loginSucceedsRepository()),
        creditsRepositoryProvider
            .overrideWithValue(_countingCreditsRepository(() => fetchCount++)),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await _pump();
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'x');
    expect(container.read(authControllerProvider).status,
        AuthStatus.authenticated);

    container.read(creditsControllerProvider);
    await _pump();

    expect(fetchCount, 1);
  });

  test(
      'logging out replaces the credits controller instead of keeping stale data',
      () async {
    var fetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
        authRepositoryProvider.overrideWithValue(_loginSucceedsRepository()),
        creditsRepositoryProvider
            .overrideWithValue(_countingCreditsRepository(() => fetchCount++)),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await _pump();
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);

    await container
        .read(authControllerProvider.notifier)
        .login(email: 'juan@example.com', password: 'x');
    container.read(creditsControllerProvider);
    await _pump();
    expect(container.read(creditsControllerProvider).creditos, hasLength(1));

    await container.read(authControllerProvider.notifier).logout();
    await _pump();

    final afterLogout = container.read(creditsControllerProvider);
    expect(afterLogout.creditos, isEmpty,
        reason: "previous session's catalog must not leak into the next");
  });
}
