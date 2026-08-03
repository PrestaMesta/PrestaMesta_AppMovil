import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/currency_formatter.dart';
import '../features/credits/data/amount_input_parser.dart';
import '../features/credits/data/credit_model.dart';
import '../features/credits/data/loan_estimate.dart';
import '../features/credits/presentation/credits_controller.dart';
import '../features/credits/presentation/widgets/credits_catalog_view.dart';
import '../features/loans/presentation/loan_draft.dart';
import '../theme/app_theme.dart';

/// Real catalog + a **non-authoritative** local estimate — not a simulator
/// backed by its own endpoint (there isn't one) and not a way to request a
/// loan (`POST /prestamos/solicitar` is not wired up yet). Every number
/// shown here either comes straight from `GET /prestamos/creditos` or is
/// computed locally by `calculateEstimate` and labeled as an estimate.
class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key});

  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  int? _selectedCreditId;

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _selectCredito(Credito credito) {
    setState(() {
      _selectedCreditId = credito.id;
      _amountController.clear();
    });
  }

  Credito? _findSelected(List<Credito> creditos) {
    for (final credito in creditos) {
      if (credito.id == _selectedCreditId) return credito;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final creditsState = ref.watch(creditsControllerProvider);
    final selectedCredito = _findSelected(creditsState.creditos);
    final validation = selectedCredito == null
        ? const _AmountValidation()
        : _validateAmount(_amountController.text, selectedCredito);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulación',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Elige un crédito del catálogo y un monto para ver una estimación.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            CreditsCatalogView(
              state: creditsState,
              selectedCreditId: _selectedCreditId,
              onSelect: _selectCredito,
              onRetry: () =>
                  ref.read(creditsControllerProvider.notifier).retry(),
              onRefresh: () =>
                  ref.read(creditsControllerProvider.notifier).refresh(),
            ),
            if (selectedCredito != null) ...[
              const SizedBox(height: 24),
              Text(
                'Monto a simular',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Entre ${formatMoney(selectedCredito.montoMinimo)} y ${formatMoney(selectedCredito.montoMaximo)}.',
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                focusNode: _amountFocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: r'$ ',
                  errorText: validation.errorText,
                  errorMaxLines: 2,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (validation.amount != null) ...[
                const SizedBox(height: 20),
                _EstimateCard(
                  estimate: calculateEstimate(
                    amount: validation.amount!,
                    annualRatePercent: selectedCredito.tasaInteresAnual,
                    termMonths: selectedCredito.plazoMeses,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.read(loanDraftControllerProvider.notifier).start(
                        credito: selectedCredito,
                        montoSolicitado: validation.amount!);
                    context.go('/app/simulacion/solicitud');
                  },
                  child: const Text('Continuar con la solicitud'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AmountValidation {
  final Decimal? amount;
  final String? errorText;
  const _AmountValidation({this.amount, this.errorText});
}

/// Pure validation: empty input shows no error (there's simply no estimate
/// yet) — an error only appears once the user has typed something that
/// can't be turned into a valid, in-range amount.
_AmountValidation _validateAmount(String raw, Credito credito) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const _AmountValidation();

  final parsed = parseUserAmount(trimmed);
  if (parsed == null) {
    return const _AmountValidation(
      errorText:
          'Ingresa un monto válido (usa punto o coma, máximo 2 decimales).',
    );
  }
  if (parsed <= Decimal.zero) {
    return const _AmountValidation(
        errorText: 'El monto debe ser mayor que cero.');
  }
  if (parsed < credito.montoMinimo) {
    return _AmountValidation(
        errorText: 'El monto mínimo es ${formatMoney(credito.montoMinimo)}.');
  }
  if (parsed > credito.montoMaximo) {
    return _AmountValidation(
        errorText: 'El monto máximo es ${formatMoney(credito.montoMaximo)}.');
  }
  return _AmountValidation(amount: parsed);
}

class _EstimateCard extends StatelessWidget {
  final LoanEstimate estimate;
  const _EstimateCard({required this.estimate});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.greenStart, AppColors.greenEnd]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Estimación. El monto definitivo lo calcula el servidor al enviar la solicitud.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _EstimateRow(
                label: 'Monto solicitado', value: formatMoney(estimate.amount)),
            const SizedBox(height: 8),
            _EstimateRow(
                label: 'Tasa anual',
                value: formatPercent(estimate.annualRatePercent)),
            const SizedBox(height: 8),
            _EstimateRow(label: 'Plazo', value: '${estimate.termMonths} meses'),
            const SizedBox(height: 8),
            _EstimateRow(
                label: 'Interés estimado',
                value: formatMoney(estimate.estimatedInterest)),
            const Divider(color: Colors.white30, height: 24),
            _EstimateRow(
              label: 'Total estimado',
              value: formatMoney(estimate.estimatedTotal),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _EstimateRow(
      {required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: emphasize ? 20 : 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
