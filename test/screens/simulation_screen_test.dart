import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/credits/data/credits_repository.dart';
import 'package:prestamesta_app/features/credits/presentation/credits_controller.dart';
import 'package:prestamesta_app/screens/simulation_screen.dart';

import '../support/fake_http_client_adapter.dart';

final _creditoJson = {
  'id': 1,
  'nombre': 'Crédito Personal Express',
  'monto_minimo': '1000.00',
  'monto_maximo': '20000.00',
  'tasa_interes_anual': '24.00',
  'plazo_meses': 12,
  'creado_en': '2026-08-02T02:43:54.000Z',
};

final _otherCreditoJson = {
  'id': 2,
  'nombre': 'Crédito Plus',
  'monto_minimo': '5000.00',
  'monto_maximo': '50000.00',
  'tasa_interes_anual': '18.00',
  'plazo_meses': 24,
  'creado_en': '2026-08-02T02:43:54.000Z',
};

CreditsController _controller(
    FutureOr<ResponseBody> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return CreditsController(CreditsRepository(dio));
}

Future<void> _pumpScreen(
    WidgetTester tester, CreditsController controller) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [creditsControllerProvider.overrideWith((ref) => controller)],
      child: const MaterialApp(home: Scaffold(body: SimulationScreen())),
    ),
  );
}

void main() {
  testWidgets(
      'shows an accessible loading indicator before the catalog resolves',
      (tester) async {
    final controller = _controller(
        (options) => Completer<ResponseBody>().future); // never resolves
    await _pumpScreen(tester, controller);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        find.bySemanticsLabel('Cargando créditos disponibles'), findsOneWidget);
  });

  testWidgets('renders real catalog data in cards once loaded', (tester) async {
    final controller =
        _controller((options) => jsonResponseBody([_creditoJson], 200));
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();

    expect(find.text('Crédito Personal Express'), findsOneWidget);
    expect(find.textContaining('12 meses'), findsOneWidget);
  });

  testWidgets(
      'shows an honest empty state, not DemoData, when the catalog is empty',
      (tester) async {
    final controller = _controller((options) => jsonResponseBody([], 200));
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();

    expect(find.text('Por ahora no hay créditos disponibles.'), findsOneWidget);
  });

  testWidgets('shows an error state with a working Reintentar button',
      (tester) async {
    var attempt = 0;
    final controller = _controller((options) {
      attempt++;
      if (attempt == 1) {
        return jsonResponseBody({'mensaje': 'Error interno'}, 500);
      }
      return jsonResponseBody([_creditoJson], 200);
    });
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Crédito Personal Express'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets(
      'a refresh failure keeps the previous cards visible with a non-blocking notice',
      (
    tester,
  ) async {
    var attempt = 0;
    final controller = _controller((options) {
      attempt++;
      if (attempt == 1) return jsonResponseBody([_creditoJson], 200);
      return jsonResponseBody({'mensaje': 'Error interno'}, 500);
    });
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();

    await tester.runAsync(() => controller.refresh());
    await tester.pumpAndSettle();

    expect(find.text('Crédito Personal Express'), findsOneWidget,
        reason: 'previous card stays visible');
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets(
      'selecting a credit shows its min/max amount and no estimate before an amount is entered',
      (
    tester,
  ) async {
    final controller =
        _controller((options) => jsonResponseBody([_creditoJson], 200));
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crédito Personal Express'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Entre'), findsOneWidget);
    expect(find.text('Monto a simular'), findsOneWidget);
    expect(find.textContaining('Total estimado'), findsNothing);
  });

  testWidgets(
      'an out-of-range amount shows a validation error, not an estimate',
      (tester) async {
    final controller =
        _controller((options) => jsonResponseBody([_creditoJson], 200));
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crédito Personal Express'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextField), '999999'); // above monto_maximo
    await tester.pumpAndSettle();

    expect(find.textContaining('El monto máximo es'), findsOneWidget);
    expect(find.textContaining('Total estimado'), findsNothing);
  });

  testWidgets(
      'a valid amount shows the estimate, clearly labeled, with no invented fields',
      (
    tester,
  ) async {
    final controller =
        _controller((options) => jsonResponseBody([_creditoJson], 200));
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crédito Personal Express'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '10000');
    await tester.pumpAndSettle();

    expect(find.textContaining('Total estimado'), findsOneWidget);
    expect(
      find.textContaining(
          'Estimación. El monto definitivo lo calcula el servidor'),
      findsOneWidget,
    );
    // 10000 @ 24% for 12 months -> total 12400.00
    expect(find.textContaining('12,400.00'), findsOneWidget);

    // Never invented: server has no concept of these for this endpoint.
    expect(find.textContaining('Mensualidad'), findsNothing);
    expect(find.textContaining('mensualidad'), findsNothing);
    expect(find.textContaining('Cuota'), findsNothing);
    expect(find.textContaining('amortización'), findsNothing);
    expect(find.textContaining('CAT'), findsNothing);
  });

  testWidgets('no DemoData names, amounts or banner ever appear on this screen',
      (tester) async {
    final controller =
        _controller((options) => jsonResponseBody([_creditoJson], 200));
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crédito Personal Express'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10000');
    await tester.pumpAndSettle();

    // DemoData.simulationOptions text/values from the old hardcoded screen.
    expect(find.textContaining('demo'), findsNothing);
    expect(find.text('Simular'), findsNothing);
    expect(find.textContaining('Interfaz de demostración'), findsNothing);
    expect(find.textContaining('8,750'), findsNothing); // old DemoData amount
    expect(find.textContaining('1,480'),
        findsNothing); // old DemoData monthlyPayment
  });

  testWidgets(
      'changing the selected credit clears the amount and any stale estimate',
      (tester) async {
    final controller = _controller(
      (options) => jsonResponseBody([_creditoJson, _otherCreditoJson], 200),
    );
    await _pumpScreen(tester, controller);
    await tester.runAsync(() => controller.loadInitial());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crédito Personal Express'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10000');
    await tester.pumpAndSettle();
    expect(find.textContaining('Total estimado'), findsOneWidget);

    await tester.tap(find.text('Crédito Plus'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Total estimado'), findsNothing);
    final amountField = tester.widget<TextField>(find.byType(TextField));
    expect(amountField.controller!.text, isEmpty,
        reason: 'amount must not carry over to the new credit');
  });
}
