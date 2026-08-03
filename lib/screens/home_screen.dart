import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/currency_formatter.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/loans/data/loan_submission_response.dart';
import '../features/loans/presentation/loan_status_label.dart';
import '../features/loans/presentation/session_loan_summary.dart';
import '../theme/app_theme.dart';

/// Honest, real-data-only Home: a greeting from the actual authenticated
/// client, a way into Simulación (the only real "product" surface today),
/// and — if this session already sent a loan request — the server's own
/// response to it. No balance, no next payment, no fabricated application
/// status: none of that can be backed by anything the server actually
/// returns (see `docs/mobile-api-gaps.md`).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = ref.watch(authControllerProvider).cliente;
    final summary = ref.watch(sessionLoanSummaryControllerProvider);
    final nombre = cliente?.nombre ?? '';

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, $nombre',
              style: const TextStyle(
                color: AppColors.greenEnd,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'PrestaMesta',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Consulta nuestro catálogo de créditos, simula un monto y envía tu '
              'solicitud en unos pasos.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppColors.greenStart, AppColors.greenEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simular y solicitar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explora los créditos disponibles y arma tu solicitud.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.greenEnd,
                    ),
                    onPressed: () => context.go('/app/simulacion'),
                    child: const Text('Ir a Simulación'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (summary == null)
              _NoSubmissionCard(
                  onGoToSimulation: () => context.go('/app/simulacion'))
            else
              _SessionSummaryCard(summary: summary),
            const SizedBox(height: 20),
            const _AvailabilityNote(),
          ],
        ),
      ),
    );
  }
}

class _NoSubmissionCard extends StatelessWidget {
  final VoidCallback onGoToSimulation;
  const _NoSubmissionCard({required this.onGoToSimulation});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'Aún no has enviado una solicitud durante esta sesión.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onGoToSimulation,
            child: const Text('Simular un crédito'),
          ),
        ],
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  final LoanSubmissionResponse summary;
  const _SessionSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            'INFORMACIÓN RECIBIDA AL ENVIAR LA SOLICITUD',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            estadoPrestamoLabel(summary.estado),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monto solicitado: ${formatMoney(summary.montoSolicitado)}',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Recibido el ${formatLoanDate(summary.fechaSolicitud)}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          const Text(
            'Este estado no se actualiza automáticamente porque el backend todavía no '
            'permite consultar tus solicitudes.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityNote extends StatelessWidget {
  const _AvailabilityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Text(
        'El calendario de pagos y la consulta de solicitudes anteriores todavía no '
        'están disponibles: el servidor aún no ofrece esa información.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
