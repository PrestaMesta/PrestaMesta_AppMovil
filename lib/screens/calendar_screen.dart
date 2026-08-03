import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/empty_state.dart';

/// The backend has no payments/amortization implementation at all yet (see
/// `docs/mobile-api-gaps.md`) — not even a way to confirm "no payments are
/// pending," since that would still require an endpoint that doesn't exist.
/// This screen is deliberately just an honest empty state, not a partial or
/// simulated calendar.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Calendario de pagos no disponible',
        message: 'El servidor todavía no tiene pagos ni tabla de amortización '
            'implementados, así que esta sección no puede calcular ni mostrar un '
            'calendario oficial. Aparecerá aquí cuando el servicio esté disponible.',
        actionLabel: 'Ir a Inicio',
        onAction: () => context.go('/app/inicio'),
      ),
    );
  }
}
