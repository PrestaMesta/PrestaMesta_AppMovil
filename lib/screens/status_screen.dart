import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/loans/presentation/loans_list_controller.dart';
import '../features/loans/presentation/widgets/loans_list_view.dart';
import '../theme/app_theme.dart';

/// The server is the source of truth: this screen lists the client's real
/// loans from `GET /client/prestamos` (manual refresh + page controls, no
/// auto-polling) instead of caching a submission response locally. Tapping a
/// loan opens `/app/estado/:id` (`GET /client/prestamos/:id`), which also
/// shows the aval when one is on record.
class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loansListControllerProvider);
    final notifier = ref.read(loansListControllerProvider.notifier);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado de solicitudes',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Consulta el estado real de tus solicitudes directamente desde el servidor.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            LoansListView(
              state: state,
              onSelect: (loan) => context.go('/app/estado/${loan.id}'),
              onRetry: notifier.retry,
              onRefresh: notifier.refresh,
              onNextPage: notifier.nextPage,
              onPreviousPage: notifier.previousPage,
            ),
            if (state.isEmpty) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.go('/app/simulacion'),
                child: const Text('Ir a Simulación'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
