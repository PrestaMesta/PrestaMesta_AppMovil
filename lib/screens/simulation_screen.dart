import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../screens/home_screen.dart' show NumberFormatMxn;
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';

class SimulationScreen extends StatelessWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulación',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Explora opciones de préstamo (demo)',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ...DemoData.simulationOptions.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _OptionCard(option: o),
                )),
            const SizedBox(height: 8),
            const DemoBanner(),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final LoanOption option;
  const _OptionCard({required this.option});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                NumberFormatMxn.format(option.amount),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                '${option.months} meses · ${NumberFormatMxn.format(option.monthlyPayment)}/mes',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.greenEnd.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Simular',
              style: TextStyle(color: AppColors.greenStart, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
