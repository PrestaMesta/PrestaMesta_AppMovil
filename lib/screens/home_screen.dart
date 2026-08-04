import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/currency_formatter.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/loans/data/loan_list_item.dart';
import '../features/loans/presentation/loan_status_label.dart';
import '../features/loans/presentation/loans_list_controller.dart';
import '../features/loans/presentation/loans_list_state.dart';
import '../theme/app_theme.dart';

/// Honest, real-data-only Home: a greeting from the actual authenticated
/// client, a way into Simulación (the only real "product" surface today),
/// and the client's most recent loan **as reported by the server right
/// now** (`GET /client/prestamos`, sorted `fecha_solicitud DESC, id DESC`
/// server-side, so the first row is always the most recent) — not a locally
/// cached copy of whatever `POST /prestamos/solicitar` last returned. No
/// balance, no next payment, no fabricated application-progress bar: none of
/// that can be backed by any real endpoint (see `docs/mobile-api-gaps.md`).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = ref.watch(authControllerProvider).cliente;
    final loansState = ref.watch(loansListControllerProvider);
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
            _MostRecentLoanSection(state: loansState),
            const SizedBox(height: 20),
            const _AvailabilityNote(),
          ],
        ),
      ),
    );
  }
}

class _MostRecentLoanSection extends StatelessWidget {
  final LoansListState state;
  const _MostRecentLoanSection({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case LoansListStatus.initialLoading:
        return const _LoadingCard();
      case LoansListStatus.initialError:
        return _ErrorCard(mensaje: state.error?.mensaje);
      case LoansListStatus.data:
      case LoansListStatus.refreshing:
      case LoansListStatus.refreshError:
        final mostRecent = state.mostRecent;
        if (mostRecent == null) {
          return const _NoSubmissionCard();
        }
        return _MostRecentLoanCard(loan: mostRecent);
    }
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

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
      child: Center(
        child: Semantics(
          label: 'Cargando tu préstamo más reciente',
          child: const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String? mensaje;
  const _ErrorCard({required this.mensaje});

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
      child: Semantics(
        liveRegion: true,
        child: Text(
          mensaje ?? 'No se pudo cargar tu préstamo más reciente.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _NoSubmissionCard extends StatelessWidget {
  const _NoSubmissionCard();

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
      child: const Text(
        'Aún no has enviado una solicitud.',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MostRecentLoanCard extends StatelessWidget {
  final PrestamoListItem loan;
  const _MostRecentLoanCard({required this.loan});

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
            'TU SOLICITUD MÁS RECIENTE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            estadoPrestamoLabel(loan.estado),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monto solicitado: ${formatMoney(loan.montoSolicitado)}',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'Enviada el ${formatLoanDate(loan.fechaSolicitud)}',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.go('/app/estado/${loan.id}'),
            child: const Text('Ver detalle'),
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
        'El calendario de pagos todavía no está disponible: el servidor aún no '
        'ofrece esa información.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}
