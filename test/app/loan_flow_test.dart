import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/app/app.dart';
import 'package:prestamesta_app/app/providers.dart';
import 'package:prestamesta_app/core/config/env_config.dart';
import 'package:prestamesta_app/core/network/api_client.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/presentation/auth_controller.dart';
import 'package:prestamesta_app/features/credits/data/credits_repository.dart';
import 'package:prestamesta_app/features/credits/presentation/credits_controller.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_controller.dart';

import '../support/fake_http_client_adapter.dart';

/// End-to-end Checkpoint 4 coverage: simulation → review → (optional aval) →
/// submit → confirmation, driven through the real [PrestaMestaApp]/router —
/// only the network-facing repositories and secure storage are swapped for
/// in-memory fakes.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

String _validToken() {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  return '${encode({'alg': 'HS256'})}.${encode({'sub': 1, 'exp': exp})}.sig';
}

AuthRepository _authRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(
      (options) => jsonResponseBody({
        'mensaje': 'ok',
        'token': _validToken(),
        'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
      }, 200),
    );
  return AuthRepository(dio);
}

final _creditoJson = {
  'id': 1,
  'nombre': 'Crédito Personal Express',
  'monto_minimo': '1000.00',
  'monto_maximo': '20000.00',
  'tasa_interes_anual': '24.00',
  'plazo_meses': 12,
  'creado_en': '2026-08-02T02:43:54.000Z',
};

CreditsRepository _creditsRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody([_creditoJson], 200));
  return CreditsRepository(dio);
}

final _successJson = {
  'mensaje': 'Solicitud de préstamo enviada con éxito',
  'prestamoId': 1,
  'fechaSolicitud': '2026-08-02T20:46:06.000Z',
  'montoSolicitado': 10000,
  // Deliberately different from what the local estimate would show for
  // 10000 @ 24%/12 (12400.00), so the "server value wins" test below can
  // prove the confirmation screen isn't just re-displaying the estimate.
  'montoTotalAPagar': '13000.00',
  'estado': 'PENDIENTE',
};

final _emptyLoansPage = {
  'data': <dynamic>[],
  'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 0},
};

/// [responder] only answers `POST /prestamos/solicitar` — this file's tests
/// care about that call specifically (double-submit guards, request bodies,
/// error handling). Every `GET /client/prestamos*` (issued automatically by
/// `HomeScreen`/`StatusScreen` now that both are backed by the real list/
/// detail endpoints) gets a benign empty page instead, so those don't affect
/// this file's POST-focused call counts/captured bodies.
LoansRepository _loansRepository(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      if (options.method == 'GET') {
        return jsonResponseBody(_emptyLoansPage, 200);
      }
      return responder(options);
    });
  return LoansRepository(dio);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required LoansRepository loansRepository,
  CreditsRepository? creditsRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_authRepository()),
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
        creditsRepositoryProvider
            .overrideWithValue(creditsRepository ?? _creditsRepository()),
        loansRepositoryProvider.overrideWithValue(loansRepository),
      ],
      child: const PrestaMestaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loginAndReachReview(WidgetTester tester,
    {String amount = '10000'}) async {
  await tester.enterText(find.byType(TextFormField).first, 'juan@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'ClaveSegura123');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Simulación'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Crédito Personal Express'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), amount);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Continuar con la solicitud'));
  await tester.tap(find.text('Continuar con la solicitud'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Continuar con la solicitud navigates to review without any POST',
      (tester) async {
    var loanCallCount = 0;
    await _pumpApp(
      tester,
      loansRepository: _loansRepository((options) {
        loanCallCount++;
        return jsonResponseBody(_successJson, 201);
      }),
    );

    await _loginAndReachReview(tester);

    expect(find.text('Revisar solicitud'), findsOneWidget);
    expect(loanCallCount, 0);
  });

  testWidgets('review screen shows the selected credit and amount',
      (tester) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));

    await _loginAndReachReview(tester);

    expect(find.text('Crédito Personal Express'), findsOneWidget);
    expect(find.textContaining('12,400.00'),
        findsWidgets); // local estimate, pre-submission
  });

  testWidgets(
      'aval is off by default; enabling it with invalid fields blocks Enviar solicitud',
      (tester) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Agregar aval (opcional)'));
    await tester.tap(find.text('Agregar aval (opcional)'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre del aval'), findsOneWidget);
    final enviarButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar solicitud'));
    expect(enviarButton.onPressed, isNull,
        reason: 'aval enabled but empty must block submit');
  });

  testWidgets(
      'a complete, valid aval enables Enviar solicitud and is included in the request',
      (tester) async {
    late Map<String, dynamic> capturedBody;
    await _pumpApp(
      tester,
      loansRepository: _loansRepository((options) {
        capturedBody = options.data as Map<String, dynamic>;
        return jsonResponseBody(_successJson, 201);
      }),
    );
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Agregar aval (opcional)'));
    await tester.tap(find.text('Agregar aval (opcional)'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del aval'), 'Roberto Gómez');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Teléfono del aval'), '8711234567');
    await tester.pumpAndSettle();

    final enviarButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar solicitud'));
    expect(enviarButton.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(capturedBody['aval'], isNotNull);
    expect(capturedBody['aval']['nombre'], 'Roberto Gómez');
  });

  testWidgets(
      'a masked aval summary is shown once the aval is valid (full phone not repeated)',
      (tester) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Agregar aval (opcional)'));
    await tester.tap(find.text('Agregar aval (opcional)'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del aval'), 'Roberto Gómez');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Teléfono del aval'), '8711234567');
    await tester.pumpAndSettle();

    expect(find.textContaining('****4567'), findsOneWidget);
  });

  testWidgets(
      'empty optional aval fields (no aval at all) submit without an aval key',
      (tester) async {
    late Map<String, dynamic> capturedBody;
    await _pumpApp(
      tester,
      loansRepository: _loansRepository((options) {
        capturedBody = options.data as Map<String, dynamic>;
        return jsonResponseBody(_successJson, 201);
      }),
    );
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(capturedBody.containsKey('aval'), isFalse);
  });

  testWidgets('double tap on Enviar solicitud only issues one POST',
      (tester) async {
    var callCount = 0;
    await _pumpApp(
      tester,
      loansRepository: _loansRepository((options) {
        callCount++;
        return jsonResponseBody(_successJson, 201);
      }),
    );
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('VALIDATION_ERROR is shown and the form stays editable',
      (tester) async {
    await _pumpApp(
      tester,
      loansRepository: _loansRepository(
        (options) => jsonResponseBody({
          'mensaje': 'Los datos enviados no son válidos.',
          'codigo': 'VALIDATION_ERROR'
        }, 400),
      ),
    );
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Los datos enviados no son válidos.'), findsOneWidget);
    expect(find.text('Enviar solicitud'),
        findsOneWidget); // still there, still tappable
  });

  testWidgets('429 is shown to the user', (tester) async {
    await _pumpApp(
      tester,
      loansRepository: _loansRepository(
        (options) => ResponseBody.fromString(
            'Too many requests, please try again later.', 429,
            headers: {
              'content-type': ['text/html'],
            }),
      ),
    );
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Demasiadas solicitudes'), findsOneWidget);
  });

  testWidgets(
      'CREDIT_NOT_FOUND shows a dedicated view and offers a way back to the catalog',
      (tester) async {
    await _pumpApp(
      tester,
      loansRepository: _loansRepository(
        (options) => jsonResponseBody({
          'mensaje': 'Tipo de credito no encontrado.',
          'codigo': 'CREDIT_NOT_FOUND'
        }, 404),
      ),
    );
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Crédito no disponible'), findsOneWidget);
    await tester.ensureVisible(find.text('Volver al catálogo'));
    await tester.tap(find.text('Volver al catálogo'));
    await tester.pumpAndSettle();

    expect(find.text('Simulación'), findsWidgets);
  });

  testWidgets('TOKEN_EXPIRED during submission ends on the login screen',
      (tester) async {
    // This one specifically needs the *real* `ApiClient` (with its real
    // `AuthInterceptor`), not a bare `Dio`, to prove the actual end-to-end
    // wiring: a 401 TOKEN_EXPIRED on the loan submission clears the session
    // through the exact same mechanism as anywhere else in the app (see
    // `auth_session_rejection_integration_test.dart` for the same pattern).
    final adapter = FakeHttpClientAdapter((options) {
      if (options.method == 'GET') {
        return jsonResponseBody(_emptyLoansPage, 200);
      }
      return jsonResponseBody(
          {'mensaje': 'Token expirado', 'codigo': 'TOKEN_EXPIRED'}, 401);
    });
    final config = EnvConfig.parse(
        appEnvRaw: 'local', apiBaseUrlRaw: 'http://10.0.2.2:3000');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_authRepository()),
          sessionLocalStorageProvider
              .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
          creditsRepositoryProvider.overrideWithValue(_creditsRepository()),
          apiClientProvider.overrideWith((ref) {
            final sessionStorage = ref.watch(sessionLocalStorageProvider);
            final apiClient = ApiClient.create(
              config: config,
              readToken: sessionStorage.readToken,
              onSessionRejected: () => ref
                  .read(authControllerProvider.notifier)
                  .sessionRejectedByServer(),
            );
            apiClient.dio.httpClientAdapter = adapter;
            return apiClient;
          }),
        ],
        child: const PrestaMestaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets(
      'TOKEN_INVALID during submission (e.g. an admin-audience token reused '
      'against this client-only route) ends on the login screen too, '
      'exactly like TOKEN_EXPIRED, and never shows an invalid-credentials '
      'style message', (tester) async {
    // Same real-`ApiClient` reasoning as the TOKEN_EXPIRED test above: this
    // route (`POST /prestamos/solicitar`) is `verificarTokenCliente`-only
    // server-side, so a structurally valid but wrong-audience (admin) JWT is
    // rejected purely on audience mismatch with 401 TOKEN_INVALID — the app
    // must treat that exactly like any other session rejection, not as a
    // "wrong password" style failure.
    final adapter = FakeHttpClientAdapter((options) {
      if (options.method == 'GET') {
        return jsonResponseBody(_emptyLoansPage, 200);
      }
      return jsonResponseBody(
          {'mensaje': 'Token invalido.', 'codigo': 'TOKEN_INVALID'}, 401);
    });
    final config = EnvConfig.parse(
        appEnvRaw: 'local', apiBaseUrlRaw: 'http://10.0.2.2:3000');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_authRepository()),
          sessionLocalStorageProvider
              .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
          creditsRepositoryProvider.overrideWithValue(_creditsRepository()),
          apiClientProvider.overrideWith((ref) {
            final sessionStorage = ref.watch(sessionLocalStorageProvider);
            final apiClient = ApiClient.create(
              config: config,
              readToken: sessionStorage.readToken,
              onSessionRejected: () => ref
                  .read(authControllerProvider.notifier)
                  .sessionRejectedByServer(),
            );
            apiClient.dio.httpClientAdapter = adapter;
            return apiClient;
          }),
        ],
        child: const PrestaMestaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.textContaining('credencial', findRichText: true), findsNothing);
  });

  testWidgets(
      'a receiveTimeout produces the outcomeUnknown screen, not a normal error with Reintentar',
      (
    tester,
  ) async {
    await _pumpApp(
      tester,
      loansRepository: _loansRepository(
        (options) => throw DioException(
            requestOptions: options, type: DioExceptionType.receiveTimeout),
      ),
    );
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo confirmar'), findsOneWidget);
    expect(find.textContaining('no la envíes nuevamente'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets(
      'success shows the server\'s values, not the local pre-submission estimate',
      (tester) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Solicitud enviada'), findsOneWidget);
    // Server total (13000.00) — deliberately different from the local
    // estimate (12400.00) that was shown on the review screen.
    expect(find.textContaining('13,000.00'), findsOneWidget);
    expect(find.textContaining('12,400.00'), findsNothing);
  });

  testWidgets(
      'success shows "Pendiente de revisión", never "Aprobado"/mensualidad/calendar',
      (tester) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));
    await _loginAndReachReview(tester);

    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Pendiente de revisión'), findsOneWidget);
    expect(find.text('Aprobado'), findsNothing);
    expect(find.textContaining('mensualidad'), findsNothing);
    expect(find.textContaining('calendario'), findsNothing);
    expect(find.textContaining('depositado'), findsNothing);
  });

  testWidgets('back gesture from confirmation does not resubmit',
      (tester) async {
    var callCount = 0;
    await _pumpApp(
      tester,
      loansRepository: _loansRepository((options) {
        callCount++;
        return jsonResponseBody(_successJson, 201);
      }),
    );
    await _loginAndReachReview(tester);
    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    expect(callCount, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(callCount, 1, reason: 'back must never trigger another POST');
  });

  testWidgets(
      'a direct route to the review screen without a draft redirects to simulation',
      (tester) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));

    await tester.enterText(
        find.byType(TextFormField).first, 'juan@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'ClaveSegura123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    // Never went through simulation to build a draft — this simulates a
    // stale deep link.
    expect(find.text('Revisar solicitud'), findsNothing);
  });

  testWidgets(
      'logout clears the draft: returning to review after logging back in requires a new selection',
      (
    tester,
  ) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));
    await _loginAndReachReview(tester);
    expect(find.text('Revisar solicitud'), findsOneWidget);

    // Go back to simulation, then to profile to log out.
    await tester.ensureVisible(find.text('Volver y editar'));
    await tester.tap(find.text('Volver y editar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets(
      'all five tabs remain reachable after a full loan submission flow',
      (tester) async {
    await _pumpApp(tester,
        loansRepository:
            _loansRepository((options) => jsonResponseBody(_successJson, 201)));
    await _loginAndReachReview(tester);
    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Volver al inicio'));
    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Simulación'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });
}
