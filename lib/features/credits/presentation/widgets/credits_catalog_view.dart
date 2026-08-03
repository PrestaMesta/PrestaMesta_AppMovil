import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../theme/app_theme.dart';
import '../../data/credit_model.dart';
import '../credits_state.dart';
import 'credit_card.dart';

/// Renders the catalog's five explicit states
/// (`initialLoading`/`data`/`initialError`/`refreshing`/`refreshError`),
/// plus the derived "empty" case — this is the single place that decides
/// what the catalog section of `SimulationScreen` looks like for each state,
/// so that screen doesn't need its own `switch` on [CreditsStatus].
class CreditsCatalogView extends StatelessWidget {
  final CreditsState state;
  final int? selectedCreditId;
  final ValueChanged<Credito> onSelect;
  final VoidCallback onRetry;
  final VoidCallback onRefresh;

  const CreditsCatalogView({
    super.key,
    required this.state,
    required this.selectedCreditId,
    required this.onSelect,
    required this.onRetry,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case CreditsStatus.initialLoading:
        return const _LoadingState();
      case CreditsStatus.initialError:
        return _ErrorState(error: state.error, onRetry: onRetry);
      case CreditsStatus.data:
      case CreditsStatus.refreshing:
      case CreditsStatus.refreshError:
        if (state.creditos.isEmpty) return const _EmptyState();
        return _CatalogList(
          state: state,
          selectedCreditId: selectedCreditId,
          onSelect: onSelect,
          onRefresh: onRefresh,
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
          label: 'Cargando créditos disponibles',
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
            'Por ahora no hay créditos disponibles.',
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
              error?.mensaje ?? 'No se pudo cargar el catálogo.',
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

class _CatalogList extends StatelessWidget {
  final CreditsState state;
  final int? selectedCreditId;
  final ValueChanged<Credito> onSelect;
  final VoidCallback onRefresh;

  const _CatalogList({
    required this.state,
    required this.selectedCreditId,
    required this.onSelect,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isRefreshing = state.status == CreditsStatus.refreshing;
    final refreshFailed = state.status == CreditsStatus.refreshError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Créditos disponibles',
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
                    label: 'Actualizando catálogo',
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
                          'No se pudo actualizar el catálogo.',
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
        ...state.creditos.map(
          (credito) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: CreditCard(
              credito: credito,
              isSelected: credito.id == selectedCreditId,
              onTap: () => onSelect(credito),
            ),
          ),
        ),
      ],
    );
  }
}
