import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/credits/data/credit_model.dart';
import 'package:prestamesta_app/features/loans/data/guarantor.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_draft.dart';

final _credito = Credito(
  id: 1,
  nombre: 'Crédito Personal Express',
  montoMinimo: Decimal.parse('1000.00'),
  montoMaximo: Decimal.parse('20000.00'),
  tasaInteresAnual: Decimal.parse('24.00'),
  plazoMeses: 12,
  creadoEn: DateTime.parse('2026-08-02T02:43:54.000Z'),
);

void main() {
  test('starts with no draft', () {
    final controller = LoanDraftController();
    expect(controller.state, isNull);
  });

  test('start() creates a draft with the given credit and amount, no aval', () {
    final controller = LoanDraftController();

    controller.start(
        credito: _credito, montoSolicitado: Decimal.parse('10000'));

    expect(controller.state?.credito.id, 1);
    expect(controller.state?.montoSolicitado, Decimal.parse('10000'));
    expect(controller.state?.aval, isNull);
  });

  test('setAval() updates the aval on an existing draft', () {
    final controller = LoanDraftController()
      ..start(credito: _credito, montoSolicitado: Decimal.parse('10000'));
    const aval = Guarantor(nombre: 'Roberto Gómez', telefono: '8711234567');

    controller.setAval(aval);

    expect(controller.state?.aval, aval);
  });

  test('setAval() is a no-op when there is no draft', () {
    final controller = LoanDraftController();

    controller.setAval(const Guarantor(nombre: 'x', telefono: '1234567'));

    expect(controller.state, isNull);
  });

  test(
      'setAval(null) clears a previously-set aval without discarding the draft',
      () {
    final controller = LoanDraftController()
      ..start(credito: _credito, montoSolicitado: Decimal.parse('10000'))
      ..setAval(
          const Guarantor(nombre: 'Roberto Gómez', telefono: '8711234567'));

    controller.setAval(null);

    expect(controller.state, isNotNull);
    expect(controller.state?.aval, isNull);
  });

  test('clear() removes the draft entirely', () {
    final controller = LoanDraftController()
      ..start(credito: _credito, montoSolicitado: Decimal.parse('10000'));

    controller.clear();

    expect(controller.state, isNull);
  });
}
