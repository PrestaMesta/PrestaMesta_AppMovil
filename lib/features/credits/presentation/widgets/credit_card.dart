import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../theme/app_theme.dart';
import '../../data/credit_model.dart';

/// One selectable credit from the catalog. Shows only fields the server
/// actually returns (`nombre`, `monto_minimo`, `monto_maximo`,
/// `tasa_interes_anual`, `plazo_meses`) — no invented recommendation badge,
/// approval percentage, or availability status.
class CreditCard extends StatelessWidget {
  final Credito credito;
  final bool isSelected;
  final VoidCallback onTap;

  const CreditCard({
    super.key,
    required this.credito,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected
          ? 'Crédito ${credito.nombre}, seleccionado'
          : 'Crédito ${credito.nombre}',
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.greenEnd : AppColors.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        credito.nombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.greenEnd, size: 22),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoRow(
                    label: 'Monto mínimo',
                    value: formatMoney(credito.montoMinimo)),
                const SizedBox(height: 6),
                _InfoRow(
                    label: 'Monto máximo',
                    value: formatMoney(credito.montoMaximo)),
                const SizedBox(height: 6),
                _InfoRow(
                    label: 'Tasa anual',
                    value: formatPercent(credito.tasaInteresAnual)),
                const SizedBox(height: 6),
                _InfoRow(label: 'Plazo', value: '${credito.plazoMeses} meses'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
