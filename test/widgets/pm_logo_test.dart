import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/widgets/pm_logo.dart';

/// Checkpoint 6: PmLogo must never overflow at a large system text scale,
/// in any of the real hosting contexts (AppBar title, a `Form` header,
/// standalone) — reproduced here with a deliberately narrow, bounded host
/// to make sure `FittedBox` actually has to do work at the larger scales.
Future<void> _pumpLogo(WidgetTester tester, double textScale,
    {double width = 200}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: const PmLogo(size: 28)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final scale in [1.0, 1.3, 2.0, 2.5]) {
    testWidgets('renders with no overflow at ${scale}x text scale',
        (tester) async {
      await _pumpLogo(tester, scale);

      expect(tester.takeException(), isNull);
      expect(find.text('PrestaMesta'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
    });
  }

  testWidgets(
      'still fits with no overflow in a very narrow host at 2.5x (AppBar-with-actions case)',
      (tester) async {
    await _pumpLogo(tester, 2.5, width: 90);

    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes a single merged "PrestaMesta" semantic label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpLogo(tester, 1.0);

    expect(find.bySemanticsLabel('PrestaMesta'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the badge letter never overflows its fixed circle at 2.5x',
      (tester) async {
    await _pumpLogo(tester, 2.5);
    await tester.pump();

    // A failed layout inside the fixed-size circle would surface as an
    // uncaught overflow exception during the pump above.
    expect(tester.takeException(), isNull);
  });
}
