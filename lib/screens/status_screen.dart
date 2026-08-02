import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = DemoData.statusSteps;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado de solicitud',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              DemoData.applicationStatus,
              style: TextStyle(fontSize: 15, color: AppColors.greenStart, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            for (int i = 0; i < steps.length; i++) _StepRow(step: steps[i], isLast: i == steps.length - 1),
            const SizedBox(height: 12),
            const DemoBanner(),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final StatusStep step;
  final bool isLast;
  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.done ? AppColors.greenEnd : AppColors.divider;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: step.done ? AppColors.greenEnd : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                alignment: Alignment.center,
                child: step.done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.divider),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: step.done ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(step.date, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
