import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/pm_logo.dart';
import 'mfa_controller.dart';
import 'mfa_state.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/password_field.dart';

/// Only checks the password now (`MfaController.loginWithPassword`) — since
/// Checkpoint 6D, a correct password never authenticates by itself, it only
/// starts the mandatory MFA flow (see `mfa_controller.dart`). This screen is
/// reachable only while `mfaControllerProvider`'s phase is `idle`
/// (`router.dart#mfaRedirect` bounces every other phase to the matching MFA
/// screen), so any error/notice shown here always belongs to *this* screen,
/// never a stale one from a previous attempt.
class LoginScreen extends ConsumerStatefulWidget {
  final String? prefillEmail;

  const LoginScreen({super.key, this.prefillEmail});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(mfaControllerProvider.notifier).loginWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final mfaState = ref.watch(mfaControllerProvider);
    final isSubmitting = mfaState.phase == MfaPhase.loggingIn;
    final expiredNotice = mfaState.sessionExpiredNotice;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: PmLogo(size: 30)),
                      const SizedBox(height: 32),
                      Text(
                        'Iniciar sesión',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      if (expiredNotice != null) ...[
                        _ExpiredNoticeBanner(message: expiredNotice),
                        const SizedBox(height: 16),
                      ],
                      if (mfaState.phase == MfaPhase.idle &&
                          mfaState.error != null) ...[
                        AuthErrorBanner(error: mfaState.error!),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Correo electrónico'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El correo es obligatorio.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        label: 'Contraseña',
                        enabled: !isSubmitting,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                TextInput.finishAutofillContext();
                                ref
                                    .read(mfaControllerProvider.notifier)
                                    .dismissExpiredNotice();
                                _submit();
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Entrar'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed:
                            isSubmitting ? null : () => context.go('/register'),
                        child: const Text('¿No tienes cuenta? Regístrate'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpiredNoticeBanner extends StatelessWidget {
  final String message;

  const _ExpiredNoticeBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
