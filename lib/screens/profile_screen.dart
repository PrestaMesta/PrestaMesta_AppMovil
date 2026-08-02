import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/demo_banner.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
              'Perfil',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Text('A', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DemoData.userName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      SizedBox(height: 4),
                      Text('alex@correo.demo', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ProfileTile(icon: Icons.description_outlined, label: 'Mis solicitudes'),
            _ProfileTile(icon: Icons.notifications_none_rounded, label: 'Notificaciones'),
            _ProfileTile(icon: Icons.shield_outlined, label: 'Privacidad y seguridad'),
            _ProfileTile(icon: Icons.help_outline_rounded, label: 'Ayuda y soporte'),
            _ProfileTile(icon: Icons.logout_rounded, label: 'Cerrar sesión'),
            const SizedBox(height: 12),
            const DemoBanner(),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ProfileTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.navy),
                const SizedBox(width: 14),
                Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
