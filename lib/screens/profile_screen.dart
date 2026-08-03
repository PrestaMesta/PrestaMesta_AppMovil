import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../theme/app_theme.dart';

/// Uses only what `POST /client/auth/login` actually returns
/// (`ClienteSummary`: `{id, nombre, email}`) — no phone (never returned by
/// login), no address, no document, no identity/verification status, no
/// score, no role, no disbursement destination, and no toggle for a security
/// feature (2FA/step-up) the server doesn't implement yet.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cliente = ref.watch(authControllerProvider).cliente;
    final nombre = cliente?.nombre ?? '';
    final email = cliente?.email ?? '';
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perfil',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
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
                    decoration: const BoxDecoration(
                        color: AppColors.navy, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Semantics(
                      excludeSemantics: true,
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Text(
                'Funciones de seguridad adicionales, como autenticación en dos pasos, '
                'se incorporarán cuando el servidor las admita.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            _ProfileTile(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Seguro que quieres cerrar sesión? Tendrás que iniciar sesión de nuevo para '
          'volver a ver tu información.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
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
                Text(label,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
