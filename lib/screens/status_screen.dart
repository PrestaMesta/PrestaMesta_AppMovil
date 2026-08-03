import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/currency_formatter.dart';
import '../features/loans/presentation/loan_status_label.dart';
import '../features/loans/presentation/session_loan_summary.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Honest, real-data-only StatusScreen: there is no `GET` for a client's own
/// loan requests, so this can only ever show the server's response to a
/// submission made *during this session* — never a fabricated review
/// timeline, never a guessed "no active loans" claim (the backend genuinely
/// cannot confirm that).
class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sessionLoanSummaryControllerProvider);

    return SafeArea(
      bottom: false,
      child: summary == null
          ? EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Sin solicitudes en esta sesión',
              message:
                  'Todavía no existe una forma de consultar tus solicitudes anteriores: '
                  'el servidor solo confirma el resultado de una solicitud justo '
                  'después de enviarla.',
              actionLabel: 'Ir a Simulación',
              onAction: () => context.go('/app/simulacion'),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estado de solicitud',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Última solicitud enviada en esta sesión',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          estadoPrestamoLabel(summary.estado),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Row('Número de solicitud', '#${summary.prestamoId}'),
                        const SizedBox(height: 8),
                        _Row('Monto solicitado',
                            formatMoney(summary.montoSolicitado)),
                        const SizedBox(height: 8),
                        _Row('Monto total a pagar',
                            formatMoney(summary.montoTotalAPagar)),
                        const SizedBox(height: 8),
                        _Row('Recibida el',
                            formatLoanDate(summary.fechaSolicitud)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Esta información corresponde al momento en que se envió la solicitud. '
                    'No representa una consulta actualizada: el servidor todavía no ofrece '
                    'una forma de volver a consultar esta solicitud desde la aplicación.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => context.go('/app/simulacion'),
                    child: const Text('Enviar otra solicitud'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
