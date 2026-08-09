import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/pm_logo.dart';
import '../data/mfa_validators.dart';
import 'mfa_controller.dart';
import 'mfa_state.dart';
import 'widgets/auth_error_banner.dart';

/// Covers the whole TOTP enrollment sub-flow in one screen — one switch on
/// `MfaState.phase`, same pattern `CreditsCatalogView`/`LoansListView` use
/// for their own status enums — rather than a separate route per step:
/// starting the enrollment (spinner), showing the QR/secret and asking for
/// the first code, confirming it (spinner), and finally the one-time
/// recovery codes with their save-confirmation gate. Reachable only while
/// `mfaControllerProvider`'s phase is one of the enrollment ones
/// (`router.dart#mfaRedirect`), so there's never a "nothing to show" case to
/// handle here.
class MfaEnrollmentScreen extends ConsumerWidget {
  const MfaEnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mfaControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: PmLogo(size: 28)),
                  const SizedBox(height: 24),
                  switch (state.phase) {
                    MfaPhase.enrollmentStarting => const _StartingView(),
                    MfaPhase.enrollmentReady => _ReadyView(state: state),
                    MfaPhase.enrollmentConfirming =>
                      _ConfirmingView(secreto: state.secreto ?? ''),
                    MfaPhase.recoveryCodesPendingAck => _RecoveryCodesView(
                        codes: state.recoveryCodes ?? const []),
                    _ => const SizedBox.shrink(),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartingView extends StatelessWidget {
  const _StartingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparando la verificación en dos pasos…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ConfirmingView extends StatelessWidget {
  final String secreto;

  const _ConfirmingView({required this.secreto});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Confirmando código…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ReadyView extends ConsumerStatefulWidget {
  final MfaState state;

  const _ReadyView({required this.state});

  @override
  ConsumerState<_ReadyView> createState() => _ReadyViewState();
}

class _ReadyViewState extends ConsumerState<_ReadyView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openInAuthenticatorApp(String otpauthUri) async {
    var launched = false;
    try {
      launched = await launchUrl(Uri.parse(otpauthUri),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('No se encontró una aplicación de autenticación instalada. '
                'Usa la clave manual.'),
      ));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(mfaControllerProvider.notifier)
        .confirmEnrollment(_codeController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final otpauthUri = widget.state.otpauthUri ?? '';
    final secreto = widget.state.secreto ?? '';
    final error = widget.state.error;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Configura la verificación en dos pasos',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escanea este código QR con una aplicación de autenticación '
            '(Google Authenticator, Authy u otra compatible con TOTP).',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (error != null) ...[
            AuthErrorBanner(error: error),
            const SizedBox(height: 16),
          ],
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: QrImageView(
                data: otpauthUri,
                size: 200,
                semanticsLabel:
                    'Código QR para configurar la aplicación de autenticación',
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: otpauthUri.isEmpty
                ? null
                : () => _openInAuthenticatorApp(otpauthUri),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir en mi app de autenticación'),
          ),
          const SizedBox(height: 20),
          const Text('¿No puedes escanear? Ingresa esta clave manualmente:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 6),
          SelectableText(
            secreto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            decoration: const InputDecoration(
                labelText: 'Código de 6 dígitos', counterText: ''),
            validator: (value) {
              if (!isTotpCodeValid(value ?? '')) {
                return 'Ingresa el código de 6 dígitos de tu aplicación.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('Confirmar y activar'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => ref.read(mfaControllerProvider.notifier).abandon(),
            child: const Text('Cancelar y volver al inicio de sesión'),
          ),
        ],
      ),
    );
  }
}

class _RecoveryCodesView extends ConsumerStatefulWidget {
  final List<String> codes;

  const _RecoveryCodesView({required this.codes});

  @override
  ConsumerState<_RecoveryCodesView> createState() => _RecoveryCodesViewState();
}

class _RecoveryCodesViewState extends ConsumerState<_RecoveryCodesView> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Guarda tus códigos de recuperación',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada código se puede usar una sola vez si pierdes acceso a tu '
          'aplicación de autenticación. Esta es la única vez que se muestran: '
          'guárdalos en un lugar seguro antes de continuar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (final code in widget.codes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          value: _acknowledged,
          onChanged: (value) => setState(() => _acknowledged = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Ya guardé mis códigos de recuperación en un lugar seguro.',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _acknowledged
              ? () => ref
                  .read(mfaControllerProvider.notifier)
                  .acknowledgeRecoveryCodesSaved()
              : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
