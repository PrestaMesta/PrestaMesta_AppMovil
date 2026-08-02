import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Mirrors the "Datos de ejemplo con fines demostrativos" /
/// "Interfaz de demostración con datos ficticios" notice shown on
/// every mockup screen of prestamesta.fun.
class DemoBanner extends StatelessWidget {
  final String text;
  const DemoBanner({super.key, this.text = 'Interfaz de demostración con datos ficticios'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
