import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/widgets/pm_bottom_nav.dart';

const _labels = ['Inicio', 'Simulación', 'Calendario', 'Estado', 'Perfil'];

Future<void> _pumpNav(
  WidgetTester tester,
  double textScale, {
  int currentIndex = 0,
  ValueChanged<int>? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          bottomNavigationBar: PmBottomNav(
            currentIndex: currentIndex,
            onTap: onTap ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final scale in [1.0, 1.3, 2.0, 2.5]) {
    testWidgets('renders all five tabs with no overflow at ${scale}x',
        (tester) async {
      await _pumpNav(tester, scale);

      expect(tester.takeException(), isNull);
      for (final label in _labels) {
        expect(find.text(label), findsOneWidget);
      }
    });
  }

  testWidgets(
      'all five tabs remain tappable at 2.5x (essential actions visible)',
      (tester) async {
    final taps = <int>[];
    await _pumpNav(tester, 2.5, onTap: taps.add);

    for (var i = 0; i < _labels.length; i++) {
      await tester.tap(find.text(_labels[i]));
    }

    expect(taps, [0, 1, 2, 3, 4]);
  });

  testWidgets('the selected tab is announced to assistive technology',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpNav(tester, 1.0, currentIndex: 2);

    expect(find.bySemanticsLabel('Calendario, seleccionada'), findsOneWidget);
    expect(find.bySemanticsLabel('Inicio'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('selection announcement updates when the current index changes',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpNav(tester, 1.0, currentIndex: 0);
    expect(find.bySemanticsLabel('Inicio, seleccionada'), findsOneWidget);

    await _pumpNav(tester, 1.0, currentIndex: 4);
    expect(find.bySemanticsLabel('Perfil, seleccionada'), findsOneWidget);
    expect(find.bySemanticsLabel('Inicio, seleccionada'), findsNothing);
    handle.dispose();
  });

  testWidgets(
      'changing text scale alone never calls onTap (no navigation triggered by scale)',
      (tester) async {
    final taps = <int>[];
    await _pumpNav(tester, 1.0, onTap: taps.add);
    await _pumpNav(tester, 2.5, onTap: taps.add);

    expect(taps, isEmpty);
  });
}
