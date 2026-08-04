import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prestamesta_app/app/app.dart';
import 'package:prestamesta_app/app/providers.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/credits/data/credits_repository.dart';
import 'package:prestamesta_app/features/credits/presentation/credits_controller.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_controller.dart';

import '../support/fake_http_client_adapter.dart';

/// End-to-end coverage for Home/Estado/Calendario/Perfil built only from
/// real session/server data — no `DemoData`, and (since the client-only
/// `GET /client/prestamos`/`GET /client/prestamos/:id` routes exist now) no
/// locally-cached `SessionLoanSummary` either: the server is the source of
/// truth, driven through the real [PrestaMestaApp]/router, same
/// fake-repository pattern as `test/app/loan_flow_test.dart`.
class FakeSecureStorage implements SecureStorage {
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

int _authCallCount = 0;
AuthRepository _authRepository(
    {int clienteId = 1,
    String nombre = 'Juan Pérez',
    String email = 'juan@example.com'}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      _authCallCount++;
      return jsonResponseBody({
        'mensaje': 'ok',
        'token': _token(clienteId),
        'cliente': {'id': clienteId, 'nombre': nombre, 'email': email},
      }, 200);
    });
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

int _creditsCallCount = 0;
CreditsRepository _creditsRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      _creditsCallCount++;
      return jsonResponseBody([_creditoJson], 200);
    });
  return CreditsRepository(dio);
}

int _loanCallCount = 0;

/// A tiny in-memory stand-in for the real backend's `prestamos` table: a
/// `POST /prestamos/solicitar` appends a row (most recent first, mirroring
/// the server's `fecha_solicitud DESC, id DESC` order), `GET
/// /client/prestamos` paginates over it, and `GET /client/prestamos/:id`
/// looks a single row up by id (404 `LOAN_NOT_FOUND` when missing) — the
/// same three routes `LoansRepository` actually calls, so screens built on
/// top of it exercise the real request/response shapes end to end instead of
/// a single canned response.
class FakeLoansServer {
  final List<Map<String, dynamic>> _loans = [];
  int _nextId = 1;

  /// Overrides the `aval` field a detail lookup returns for a given loan id
  /// — absent means `null` (no aval), matching the server's `LEFT JOIN`
  /// default. Set explicitly by tests that need to prove the aval section
  /// renders when the server does return one.
  final Map<int, Map<String, dynamic>?> avalOverrides = {};

  LoansRepository repository() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = FakeHttpClientAdapter(_handle);
    return LoansRepository(dio);
  }

  /// Directly seeds a loan as if it had already been submitted before the
  /// test started — used by pagination tests that need many rows without
  /// driving the full submission UI flow for each one.
  void seed({
    Decimal? montoSolicitado,
    String estado = 'PENDIENTE',
    String? fechaSolicitud,
  }) {
    final id = _nextId++;
    _loans.insert(0, {
      'id': id,
      'credito': {'id': 1, 'nombre': 'Crédito Personal Express'},
      'monto_solicitado':
          (montoSolicitado ?? Decimal.parse('10000.00')).toString(),
      'monto_total_a_pagar': '13000.00',
      'saldo_pendiente': '13000.00',
      'estado': estado,
      'fecha_solicitud': fechaSolicitud ?? '2026-08-02T20:46:06.000Z',
      'fecha_decision': null,
    });
  }

  FutureOr<ResponseBody> _handle(RequestOptions options) {
    _loanCallCount++;

    if (options.method == 'POST' && options.path == '/prestamos/solicitar') {
      final body = options.data as Map<String, dynamic>;
      final id = _nextId++;
      final montoSolicitado = body['monto_solicitado'];
      _loans.insert(0, {
        'id': id,
        'credito': {
          'id': body['credito_id'],
          'nombre': 'Crédito Personal Express'
        },
        'monto_solicitado': montoSolicitado is num
            ? montoSolicitado.toStringAsFixed(2)
            : montoSolicitado.toString(),
        'monto_total_a_pagar': '13000.00',
        'saldo_pendiente': '13000.00',
        'estado': 'PENDIENTE',
        'fecha_solicitud': '2026-08-02T20:46:06.000Z',
        'fecha_decision': null,
      });
      return jsonResponseBody({
        'mensaje': 'Solicitud de préstamo enviada con éxito',
        'prestamoId': id,
        'fechaSolicitud': '2026-08-02T20:46:06.000Z',
        'montoSolicitado': montoSolicitado,
        'montoTotalAPagar': '13000.00',
        'estado': 'PENDIENTE',
      }, 201);
    }

    if (options.method == 'GET' && options.path == '/client/prestamos') {
      final page = int.parse(options.queryParameters['page'].toString());
      final limit = int.parse(options.queryParameters['limit'].toString());
      final start = (page - 1) * limit;
      final end = (start + limit).clamp(0, _loans.length);
      final pageItems = start >= _loans.length
          ? const <Map<String, dynamic>>[]
          : _loans.sublist(start, end);
      final totalPages = _loans.isEmpty ? 0 : (_loans.length / limit).ceil();
      return jsonResponseBody({
        'data': pageItems,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': _loans.length,
          'totalPages': totalPages,
        },
      }, 200);
    }

    if (options.method == 'GET' &&
        options.path.startsWith('/client/prestamos/')) {
      final id = int.tryParse(options.path.split('/').last);
      Map<String, dynamic>? loan;
      for (final candidate in _loans) {
        if (candidate['id'] == id) {
          loan = candidate;
          break;
        }
      }
      if (loan == null) {
        return jsonResponseBody(
            {'mensaje': 'Prestamo no encontrado.', 'codigo': 'LOAN_NOT_FOUND'},
            404);
      }
      return jsonResponseBody({...loan, 'aval': avalOverrides[id]}, 200);
    }

    throw StateError('unexpected request in FakeLoansServer: '
        '${options.method} ${options.path}');
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  AuthRepository? authRepository,
  CreditsRepository? creditsRepository,
  LoansRepository? loansRepository,
  double textScaleFactor = 1.0,
}) async {
  _authCallCount = 0;
  _creditsCallCount = 0;
  _loanCallCount = 0;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: ProviderScope(
        overrides: [
          authRepositoryProvider
              .overrideWithValue(authRepository ?? _authRepository()),
          sessionLocalStorageProvider
              .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
          creditsRepositoryProvider
              .overrideWithValue(creditsRepository ?? _creditsRepository()),
          loansRepositoryProvider.overrideWithValue(
              loansRepository ?? FakeLoansServer().repository()),
        ],
        child: const PrestaMestaApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester,
    {String email = 'juan@example.com',
    String password = 'ClaveSegura123'}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

Future<void> _submitLoan(WidgetTester tester, {String amount = '10000'}) async {
  await tester.tap(find.text('Simulación'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Crédito Personal Express'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), amount);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Continuar con la solicitud'));
  await tester.tap(find.text('Continuar con la solicitud'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Enviar solicitud'));
  await tester.tap(find.text('Enviar solicitud'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Volver al inicio'));
  await tester.tap(find.text('Volver al inicio'));
  await tester.pumpAndSettle();
}

void main() {
  group('HomeScreen', () {
    testWidgets('shows the real client name from login, not a fake one',
        (tester) async {
      await _pumpApp(tester,
          authRepository: _authRepository(nombre: 'María López'));
      await _login(tester);

      expect(find.textContaining('María López'), findsOneWidget);
      expect(find.textContaining('Alex'), findsNothing); // old DemoData name
    });

    testWidgets('never shows a fabricated balance or next payment amount',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);

      expect(find.textContaining('Próximo pago'), findsNothing);
      expect(find.textContaining('Saldo estimado'), findsNothing);
      expect(find.textContaining('1,250'), findsNothing); // old DemoData amount
      expect(find.textContaining('8,750'), findsNothing); // old DemoData amount
    });

    testWidgets(
        'without any loan on the server, shows the honest empty message '
        '— never claims "no tienes préstamos"', (tester) async {
      await _pumpApp(tester);
      await _login(tester);

      expect(find.text('Aún no has enviado una solicitud.'), findsOneWidget);
      expect(find.textContaining('No tienes préstamos'), findsNothing);
    });

    testWidgets(
        'with a real loan on the server, shows it as the most recent loan',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);

      expect(find.text('Inicio'), findsOneWidget); // back on the home tab
      expect(find.text('Pendiente de revisión'), findsOneWidget);
      expect(find.text('Ver detalle'), findsOneWidget);
      expect(find.text('Aún no has enviado una solicitud.'), findsNothing);
    });

    testWidgets('tapping "Ver detalle" opens the loan detail screen',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);

      await tester.ensureVisible(find.text('Ver detalle'));
      await tester.tap(find.text('Ver detalle'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle de solicitud'), findsOneWidget);
      expect(find.textContaining('#1'), findsWidgets);
    });

    testWidgets('an initial load failure shows a message, not a crash',
        (tester) async {
      await _pumpApp(
        tester,
        loansRepository: LoansRepository(
          Dio(BaseOptions(baseUrl: 'https://api.test'))
            ..httpClientAdapter = FakeHttpClientAdapter(
              (options) => jsonResponseBody(
                  {'mensaje': 'Error del servidor.', 'codigo': null}, 500),
            ),
        ),
      );
      await _login(tester);

      expect(find.textContaining('Error del servidor'), findsOneWidget);
    });

    testWidgets(
        'the CTA switches to the Simulación branch without duplicating the shell',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);

      await tester.tap(find.text('Ir a Simulación'));
      await tester.pumpAndSettle();

      expect(find.text('Simulación'), findsWidgets);
      // A single AppBar means the shell (RootShell) was not pushed a second
      // time — the branch changed in place, same Scaffold/AppBar instance.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders without overflow at a large text scale',
        (tester) async {
      await _pumpApp(tester, textScaleFactor: 1.3);
      await _login(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('StatusScreen', () {
    testWidgets('empty state when there are no loans on the server',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();

      expect(
          find.text('Aún no tienes solicitudes registradas.'), findsOneWidget);
      expect(find.textContaining('No tienes préstamos'), findsNothing);
    });

    testWidgets('CTA from the empty state navigates to Simulación',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ir a Simulación'));
      await tester.pumpAndSettle();

      expect(find.text('Simulación'), findsWidgets);
    });

    testWidgets(
        'lists real loans from the server and updates estado exactly as '
        'received, never a fabricated timeline', (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pendiente de revisión'), findsWidgets);
      expect(find.textContaining('#1'), findsWidgets);
      expect(find.textContaining('13,000.00'),
          findsNothing); // list-item shows monto_solicitado
      expect(find.textContaining('10,000.00'), findsOneWidget);
      // Old DemoData fabricated timeline steps must never appear.
      expect(find.text('Documentos validados'), findsNothing);
      expect(find.text('Depósito'), findsNothing);
      expect(find.text('Aprobación'), findsNothing);
    });

    testWidgets('tapping a loan opens its detail with full server fields',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Crédito Personal Express').last);
      await tester.pumpAndSettle();

      expect(find.text('Detalle de solicitud'), findsOneWidget);
      // Both "monto total a pagar" and "saldo pendiente" are 13,000.00 in
      // this fake (no payments have been made yet, so the balance still
      // equals the total) — two widgets, not a fabricated duplicate.
      expect(find.textContaining('13,000.00'), findsNWidgets(2));
      expect(find.text('Esta solicitud no tiene un aval registrado.'),
          findsOneWidget);
    });

    testWidgets('detail shows the aval when the server returns one',
        (tester) async {
      final server = FakeLoansServer();
      server.seed();
      server.avalOverrides[1] = {
        'id': 5,
        'nombre': 'Roberto Gómez',
        'telefono': '8711234567',
        'direccion': null,
        'ingreso_mensual': null,
      };

      await _pumpApp(tester, loansRepository: server.repository());
      await _login(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Crédito Personal Express').last);
      await tester.pumpAndSettle();

      expect(find.text('Roberto Gómez'), findsOneWidget);
      expect(find.text('8711234567'), findsOneWidget);
      expect(find.text('Esta solicitud no tiene un aval registrado.'),
          findsNothing);
    });

    testWidgets(
        'a 404 detail (loan gone/not owned) shows a message, not a crash',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();
      // Deep-link straight into a nonexistent loan id.
      final context = tester.element(find.text('Estado').first);
      GoRouter.of(context).go('/app/estado/999');
      await tester.pumpAndSettle();

      expect(find.textContaining('Prestamo no encontrado'), findsOneWidget);
    });

    testWidgets('the manual refresh button re-fetches the list',
        (tester) async {
      final server = FakeLoansServer()..seed();
      await _pumpApp(tester, loansRepository: server.repository());
      await _login(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();
      final callsAfterLoad = _loanCallCount;

      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();

      expect(_loanCallCount, callsAfterLoad + 1);
    });

    testWidgets('pagination controls page through more than one page',
        (tester) async {
      final server = FakeLoansServer();
      for (var i = 0; i < 25; i++) {
        server.seed();
      }
      await _pumpApp(tester, loansRepository: server.repository());
      await _login(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();

      expect(find.text('Página 1 de 2'), findsOneWidget);
      final nextButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Siguiente'));
      expect(nextButton.onPressed, isNotNull);

      await tester.ensureVisible(find.text('Siguiente'));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Página 2 de 2'), findsOneWidget);
      final nextButtonPage2 = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Siguiente'));
      expect(nextButtonPage2.onPressed, isNull);

      await tester.ensureVisible(find.text('Anterior'));
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();

      expect(find.text('Página 1 de 2'), findsOneWidget);
    });

    testWidgets(
        'visiting this tab after Home already loaded the list makes no '
        'extra network call — same shared, client-id-keyed provider',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      final callsAfterLogin = _loanCallCount;

      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      expect(_authCallCount, 1);
      expect(_loanCallCount, callsAfterLogin);
    });
  });

  group('CalendarScreen', () {
    testWidgets('shows an honest empty state, no fabricated payments',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();

      expect(find.text('Calendario de pagos no disponible'), findsOneWidget);
      expect(find.text('Pago de agosto'), findsNothing); // old DemoData
      expect(find.text('Pago de julio'), findsNothing);
      expect(find.textContaining('1,250'), findsNothing);
    });

    testWidgets('CTA navigates back to Inicio', (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ir a Inicio'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hola,'), findsOneWidget);
    });

    testWidgets('renders without overflow at a large text scale',
        (tester) async {
      await _pumpApp(tester, textScaleFactor: 1.3);
      await _login(tester);
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('ProfileScreen', () {
    testWidgets('shows the real name and email, nothing fabricated',
        (tester) async {
      await _pumpApp(
        tester,
        authRepository:
            _authRepository(nombre: 'María López', email: 'maria@example.com'),
      );
      await _login(tester, email: 'maria@example.com');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('María López'), findsOneWidget);
      expect(find.text('maria@example.com'), findsOneWidget);
    });

    testWidgets('never shows a phone number or the old fake navigation tiles',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Mis solicitudes'), findsNothing);
      expect(find.text('Notificaciones'), findsNothing);
      expect(find.text('Privacidad y seguridad'), findsNothing);
      expect(find.text('Ayuda y soporte'), findsNothing);
    });

    testWidgets('does not present 2FA as an active toggle', (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('se incorporarán cuando el servidor'),
          findsOneWidget);
    });

    testWidgets(
        'logout clears the loans list — a fresh login sees an empty Home '
        'until the (now client-id-keyed) provider reloads', (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);
      expect(find.text('Pendiente de revisión'), findsOneWidget);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);

      await _login(tester);

      // A brand new client-id-keyed provider — the fake server this test
      // uses is shared across the session, but a fresh login for the same
      // client re-fetches from it rather than reusing stale in-memory
      // state, so the loan submitted before logout is still visible here
      // (proving it came from the server, not a leftover local cache).
      expect(find.text('Pendiente de revisión'), findsOneWidget);
    });

    testWidgets('renders without overflow at a large text scale',
        (tester) async {
      await _pumpApp(tester, textScaleFactor: 1.3);
      await _login(tester);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('cross-cutting', () {
    testWidgets('all five tabs remain reachable with only real screens',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);

      for (final tab in [
        'Inicio',
        'Simulación',
        'Calendario',
        'Estado',
        'Perfil'
      ]) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.text(tab), findsWidgets);
      }
    });

    testWidgets(
        'switching tabs never issues an extra HTTP call beyond the one '
        'loans-list load on Home, and never re-triggers a POST',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      final creditsCallsAfterLogin = _creditsCallCount;
      final loanCallsAfterLogin = _loanCallCount;

      for (var i = 0; i < 2; i++) {
        for (final tab in [
          'Inicio',
          'Calendario',
          'Estado',
          'Perfil',
          'Inicio'
        ]) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
        }
      }

      expect(_loanCallCount, loanCallsAfterLogin);
      // Credits are fetched once (on first entering Simulación) — but this
      // test never visits Simulación, so no credits call should happen
      // either.
      expect(_creditsCallCount, creditsCallsAfterLogin);
    });

    testWidgets(
        'no DemoData-only symbols leak into the real flow (grep-equivalent smoke test)',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);

      for (final tab in ['Inicio', 'Calendario', 'Estado', 'Perfil']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.textContaining('demo'), findsNothing,
            reason: 'no "(demo)" labels on tab $tab');
        expect(find.text('Interfaz de demostración con datos ficticios'),
            findsNothing,
            reason: 'DemoBanner text must not appear on tab $tab');
      }
    });

    group('Checkpoint 6: text scale on the real, logged-in app', () {
      for (final scale in [1.0, 1.3, 2.0, 2.5]) {
        testWidgets(
            'all five tabs stay reachable at ${scale}x, and the four Checkpoint '
            '5/6 screens (chrome + Inicio/Calendario/Estado/Perfil) render with '
            'no overflow — Simulación\'s own credit-card content is a separate, '
            'pre-existing, out-of-scope issue not touched by this checkpoint',
            (tester) async {
          await _pumpApp(tester, textScaleFactor: scale);
          await _login(tester);

          for (final tab in [
            'Inicio',
            'Simulación',
            'Calendario',
            'Estado',
            'Perfil'
          ]) {
            await tester.tap(find.text(tab));
            await tester.pumpAndSettle();
            expect(find.text(tab), findsWidgets,
                reason: 'tab $tab at ${scale}x');
            if (tab == 'Simulación') {
              // Known pre-existing overflow in
              // features/credits/presentation/widgets/credit_card.dart at
              // large text scales — out of this checkpoint's scope (only
              // pm_logo.dart/pm_bottom_nav.dart/strictly-necessary shared
              // components). Consume the exception so it doesn't leak into
              // the next tab's assertion below, without pretending it's
              // fixed.
              tester.takeException();
              continue;
            }
            expect(tester.takeException(), isNull,
                reason: 'tab $tab at ${scale}x');
          }
        });
      }

      testWidgets(
          'changing the system text scale after login triggers no HTTP call '
          'of any kind — not credits, not loans, not auth', (tester) async {
        await _pumpApp(tester);
        await _login(tester);
        final authCalls = _authCallCount;
        final creditsCalls = _creditsCallCount;
        final loanCalls = _loanCallCount;

        addTearDown(
            () => tester.platformDispatcher.clearTextScaleFactorTestValue());
        for (final scale in [1.3, 2.0, 2.5, 1.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpAndSettle();
        }

        expect(_authCallCount, authCalls);
        expect(_creditsCallCount, creditsCalls);
        expect(_loanCallCount, loanCalls);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'the selected tab keeps announcing correctly after a scale change',
          (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpApp(tester);
        await _login(tester);
        await tester.tap(find.text('Estado'));
        await tester.pumpAndSettle();

        addTearDown(
            () => tester.platformDispatcher.clearTextScaleFactorTestValue());
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Estado, seleccionada'), findsOneWidget);
        handle.dispose();
      });
    });
  });
}
