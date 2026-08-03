import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../theme/app_theme.dart';
import 'loan_status_label.dart';
import 'loan_submission_controller.dart';
import 'loan_submission_state.dart';

/// Shown only after a real `201` from `POST /prestamos/solicitar`. Every
/// number here comes from [LoanSubmissionState.response] — nothing is
/// recalculated locally, and the server's `montoTotalAPagar` is what's
/// displayed, not the pre-submission estimate.
class LoanConfirmationScreen extends ConsumerWidget {
  const LoanConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionState = ref.watch(loanSubmissionControllerProvider);
    final response = submissionState.response;

    if (response == null) {
      // The router redirects away (no valid confirmation to show) before
      // this can normally be reached; this is just the defensive fallback
      // for the brief window before that happens.
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
          title: const Text('Solicitud enviada'),
          automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 48, color: AppColors.greenEnd),
              const SizedBox(height: 16),
              Text(
                response.mensaje.isNotEmpty
                    ? response.mensaje
                    : 'Solicitud registrada.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row('Número de solicitud', '#${response.prestamoId}'),
                    const SizedBox(height: 8),
                    _Row('Fecha de solicitud',
                        formatLoanDate(response.fechaSolicitud)),
                    const SizedBox(height: 8),
                    _Row('Monto solicitado',
                        formatMoney(response.montoSolicitado)),
                    const SizedBox(height: 8),
                    _Row('Monto total a pagar',
                        formatMoney(response.montoTotalAPagar)),
                    const SizedBox(height: 8),
                    _Row('Estado', estadoPrestamoLabel(response.estado)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Actualmente la aplicación no puede consultar nuevamente esta solicitud después '
                'de cerrar esta pantalla, porque el backend aún no ofrece consulta de '
                'solicitudes propias.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/app/inicio'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
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
