import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormatMxn.format(DemoData.nextPaymentAmount);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Saludo
            Text(
              'Hola, ${DemoData.userName}',
              style: const TextStyle(
                color: AppColors.greenEnd,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Resumen de tu préstamo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Próximo pago card
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.greenEnd.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Próximo pago (demo)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currency,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DemoData.nextPaymentDueLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Estado de solicitud card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTADO DE SOLICITUD',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    DemoData.applicationStatus,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: DemoData.applicationProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation(AppColors.greenEnd),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Saldo estimado (secundario, tomado de la vista previa del sitio)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo estimado (demo)',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        NumberFormatMxn.format(DemoData.estimatedBalance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white54, size: 30),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const DemoBanner(),
          ],
        ),
      ),
    );
  }
}

/// Small helper to format hardcoded MXN amounts as "$1,250 MXN".
class NumberFormatMxn {
  static String format(double amount) {
    final s = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    final reversed = s.split('').reversed.toList();
    for (int i = 0; i < reversed.length; i++) {
      buffer.write(reversed[i]);
      if ((i + 1) % 3 == 0 && i + 1 != reversed.length) buffer.write(',');
    }
    return '\$${buffer.toString().split('').reversed.join()} MXN';
  }
}
