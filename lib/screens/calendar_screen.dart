import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../screens/home_screen.dart' show NumberFormatMxn;
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

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
              'Calendario de pagos',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Historial y próximos pagos (demo)',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ...DemoData.upcomingPayments.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _PaymentTile(payment: p),
                )),
            const SizedBox(height: 8),
            const DemoBanner(),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final PaymentItem payment;
  const _PaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    final isPaid = payment.status == PaymentStatus.paid;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isPaid ? AppColors.greenEnd : AppColors.navy).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isPaid ? Icons.check_rounded : Icons.schedule_rounded,
              color: isPaid ? AppColors.greenStart : AppColors.navy,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(payment.date, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            NumberFormatMxn.format(payment.amount),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
