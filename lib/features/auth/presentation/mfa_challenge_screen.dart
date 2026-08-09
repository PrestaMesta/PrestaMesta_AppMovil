import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/pm_logo.dart';
import '../data/mfa_validators.dart';
import 'mfa_controller.dart';
import 'mfa_state.dart';
import 'widgets/auth_error_banner.dart';

/// Shown once MFA is already `ACTIVO` for the account
/// (`siguientePaso: MFA_CHALLENGE_REQUIRED`): asks for either a TOTP code
/// from the authenticator app or a one-time recovery code — exactly one of
/// the two, matching `MfaVerifyInput`'s "never both, never neither"
/// contract. Reachable only while `mfaControllerProvider`'s phase is
/// `challengeReady`/`challengeVerifying` (`router.dart#mfaRedirect`).
class MfaChallengeScreen extends ConsumerStatefulWidget {
  const MfaChallengeScreen({super.key});

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

enum _ChallengeMode { totp, recoveryCode }

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  _ChallengeMode _mode = _ChallengeMode.totp;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final value = _codeController.text.trim();
    final notifier = ref.read(mfaControllerProvider.notifier);
    if (_mode == _ChallengeMode.totp) {
      notifier.verifyChallenge(totp: value);
    } else {
      notifier.verifyChallenge(recoveryCode: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mfaControllerProvider);
    final isSubmitting = state.phase == MfaPhase.challengeVerifying;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: PmLogo(size: 28)),
                    const SizedBox(height: 24),
                    Text(
                      'Verifica tu identidad',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mode == _ChallengeMode.totp
                          ? 'Ingresa el código de 6 dígitos de tu aplicación de autenticación.'
                          : 'Ingresa uno de tus códigos de recuperación (un solo uso).',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    if (state.error != null) ...[
                      AuthErrorBanner(error: state.error!),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      key: ValueKey(_mode),
                      controller: _codeController,
                      enabled: !isSubmitting,
                      textAlign: TextAlign.center,
                      keyboardType: _mode == _ChallengeMode.totp
                          ? TextInputType.number
                          : TextInputType.text,
                      maxLength: _mode == _ChallengeMode.totp ? 6 : null,
                      decoration: InputDecoration(
                        labelText: _mode == _ChallengeMode.totp
                            ? 'Código de verificación'
                            : 'Código de recuperación',
                        counterText: '',
                      ),
                      validator: (value) {
                        final raw = value ?? '';
                        final valid = _mode == _ChallengeMode.totp
                            ? isTotpCodeValid(raw)
                            : isRecoveryCodeValid(raw);
                        if (!valid) {
                          return _mode == _ChallengeMode.totp
                              ? 'Ingresa el código de 6 dígitos.'
                              : 'Ingresa un código de recuperación válido.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: isSubmitting ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('Verificar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              _codeController.clear();
                              setState(() {
                                _mode = _mode == _ChallengeMode.totp
                                    ? _ChallengeMode.recoveryCode
                                    : _ChallengeMode.totp;
                              });
                            },
                      child: Text(_mode == _ChallengeMode.totp
                          ? 'Usar un código de recuperación'
                          : 'Usar mi aplicación de autenticación'),
                    ),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => ref
                              .read(mfaControllerProvider.notifier)
                              .abandon(),
                      child:
                          const Text('Cancelar y volver al inicio de sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
