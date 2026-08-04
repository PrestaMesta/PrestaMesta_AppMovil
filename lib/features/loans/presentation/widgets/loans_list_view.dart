import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../theme/app_theme.dart';
import '../../data/loan_list_item.dart';
import '../loan_status_label.dart';
import '../loans_list_state.dart';

/// Renders the five explicit states of [LoansListState]
/// (`initialLoading`/`data`/`initialError`/`refreshing`/`refreshError`) plus
/// the derived "empty" case, and the manual page controls — the single
/// place `StatusScreen` delegates to instead of switching on
/// [LoansListStatus] itself, same split as
/// `features/credits/presentation/widgets/credits_catalog_view.dart`.
class LoansListView extends StatelessWidget {
  final LoansListState state;
  final ValueChanged<PrestamoListItem> onSelect;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;

  const LoansListView({
    super.key,
    required this.state,
    required this.onSelect,
    required this.onRetry,
    required this.onRefresh,
    required this.onNextPage,
    required this.onPreviousPage,
  });

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case LoansListStatus.initialLoading:
        return const _LoadingState();
      case LoansListStatus.initialError:
        return _ErrorState(error: state.error, onRetry: onRetry);
      case LoansListStatus.data:
      case LoansListStatus.refreshing:
      case LoansListStatus.refreshError:
        if (state.loans.isEmpty) return const _EmptyState();
        return _LoanList(
          state: state,
          onSelect: onSelect,
          onRefresh: onRefresh,
          onNextPage: onNextPage,
          onPreviousPage: onPreviousPage,
        );
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Semantics(
          label: 'Cargando tus solicitudes',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'Aún no tienes solicitudes registradas.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final AppException? error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final requestId = error?.requestId;
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
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 32, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              error?.mensaje ?? 'No se pudieron cargar tus solicitudes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            if (requestId != null && requestId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Referencia: $requestId',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _LoanList extends StatelessWidget {
  final LoansListState state;
  final ValueChanged<PrestamoListItem> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;

  const _LoanList({
    required this.state,
    required this.onSelect,
    required this.onRefresh,
    required this.onNextPage,
    required this.onPreviousPage,
  });

  @override
  Widget build(BuildContext context) {
    final isRefreshing = state.status == LoansListStatus.refreshing;
    final refreshFailed = state.status == LoansListStatus.refreshError;
    final pagination = state.pagination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tus solicitudes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
            if (isRefreshing)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: Semantics(
                    label: 'Actualizando solicitudes',
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            IconButton(
              onPressed: isRefreshing ? null : onRefresh,
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded, color: AppColors.navy),
            ),
          ],
        ),
        if (refreshFailed) ...[
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error?.mensaje ??
                          'No se pudieron actualizar tus solicitudes.',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(
                      onPressed: onRefresh, child: const Text('Reintentar')),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...state.loans.map(
          (loan) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LoanListTile(loan: loan, onTap: () => onSelect(loan)),
          ),
        ),
        if (pagination != null) ...[
          const SizedBox(height: 4),
          // `Wrap` (not `Row`) so the two buttons drop to a second line
          // instead of overflowing horizontally at a large text scale —
          // there's no way to `Expanded` an `OutlinedButton` without
          // truncating its label.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: state.hasPreviousPage && !isRefreshing
                    ? onPreviousPage
                    : null,
                child: const Text('Anterior'),
              ),
              Text(
                'Página ${pagination.page} de '
                '${pagination.totalPages == 0 ? 1 : pagination.totalPages}',
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary),
              ),
              OutlinedButton(
                onPressed:
                    state.hasNextPage && !isRefreshing ? onNextPage : null,
                child: const Text('Siguiente'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LoanListTile extends StatelessWidget {
  final PrestamoListItem loan;
  final VoidCallback onTap;
  const _LoanListTile({required this.loan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Every text sibling lives inside this single `Expanded` column,
            // stacked vertically — never two `Text` widgets side by side in
            // an unconstrained `Row`, which is what caused the pre-existing,
            // out-of-scope overflow in `credit_card.dart` at large text
            // scales. Only the fixed-size chevron sits outside it.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.credito.nombre,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#${loan.id} · ${estadoPrestamoLabel(loan.estado)}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatLoanDate(loan.fechaSolicitud),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatMoney(loan.montoSolicitado),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
