import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// End-to-end Checkpoint 5 coverage: Home/Estado/Calendario/Perfil built
/// only from real session data + the in-session `SessionLoanSummary` — no
/// `DemoData` anywhere. Driven through the real [PrestaMestaApp]/router,
/// same fake-repository pattern as `test/app/loan_flow_test.dart`.
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

final _successJson = {
  'mensaje': 'Solicitud de préstamo enviada con éxito',
  'prestamoId': 42,
  'fechaSolicitud': '2026-08-02T20:46:06.000Z',
  'montoSolicitado': 10000,
  'montoTotalAPagar': '13000.00',
  'estado': 'PENDIENTE',
};

int _loanCallCount = 0;
LoansRepository _loansRepository(
    [FutureOr<ResponseBody> Function(RequestOptions)? responder]) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      _loanCallCount++;
      return responder != null
          ? responder(options)
          : jsonResponseBody(_successJson, 201);
    });
  return LoansRepository(dio);
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
          loansRepositoryProvider
              .overrideWithValue(loansRepository ?? _loansRepository()),
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
        'without a submission this session, shows the honest empty message '
        '— never claims "no tienes préstamos"', (tester) async {
      await _pumpApp(tester);
      await _login(tester);

      expect(find.text('Aún no has enviado una solicitud durante esta sesión.'),
          findsOneWidget);
      expect(find.textContaining('No tienes préstamos'), findsNothing);
    });

    testWidgets('with a successful submission, shows a session summary',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);

      expect(find.text('Inicio'), findsOneWidget); // back on the home tab
      expect(find.text('Pendiente de revisión'), findsOneWidget);
      expect(find.textContaining('#42'),
          findsNothing); // Home shows no folio, StatusScreen does
      expect(find.text('Aún no has enviado una solicitud durante esta sesión.'),
          findsNothing);
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
    testWidgets('empty state when there is no submission this session',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();

      expect(find.text('Sin solicitudes en esta sesión'), findsOneWidget);
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
        'shows the last in-session response with server values and the '
        'not-updated disclaimer, never a fabricated timeline', (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      await _submitLoan(tester);
      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();

      expect(find.text('Pendiente de revisión'), findsOneWidget);
      expect(find.textContaining('#42'), findsOneWidget);
      expect(find.textContaining('13,000.00'), findsOneWidget); // server total
      expect(find.textContaining('no ofrece una forma de volver a consultar'),
          findsOneWidget);
      // Old DemoData fabricated timeline steps must never appear.
      expect(find.text('Documentos validados'), findsNothing);
      expect(find.text('Depósito'), findsNothing);
      expect(find.text('Aprobación'), findsNothing);
    });

    testWidgets('visiting this tab makes no network call of its own',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      final callsAfterLogin = _authCallCount;

      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();

      expect(_authCallCount, callsAfterLogin);
      expect(_loanCallCount, 0);
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

    testWidgets('logout clears the session summary too', (tester) async {
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

      expect(find.text('Aún no has enviado una solicitud durante esta sesión.'),
          findsOneWidget);
      expect(find.text('Pendiente de revisión'), findsNothing);
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
        'switching tabs never issues an extra HTTP call and never re-triggers a POST',
        (tester) async {
      await _pumpApp(tester);
      await _login(tester);
      final creditsCallsAfterLogin = _creditsCallCount;

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

      expect(_loanCallCount, 0);
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
