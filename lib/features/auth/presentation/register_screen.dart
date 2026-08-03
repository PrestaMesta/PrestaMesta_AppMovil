import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/pm_logo.dart';
import '../data/auth_validators.dart';
import 'register_controller.dart';
import 'widgets/auth_error_banner.dart';
import 'widgets/password_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();

  final _nombreFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _telefonoFocus = FocusNode();

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _nombreFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _telefonoFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final telefono = _telefonoController.text.trim();
    ref.read(registerControllerProvider.notifier).submit(
          nombre: _nombreController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          telefono: telefono.isEmpty ? null : telefono,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RegisterState>(registerControllerProvider, (previous, next) {
      if (next.status == RegisterStatus.success) {
        final email = _emailController.text.trim();
        _passwordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada. Ahora inicia sesión.')),
        );
        context.go(
            Uri(path: '/login', queryParameters: {'email': email}).toString());
      }
    });

    final registerState = ref.watch(registerControllerProvider);
    final isSubmitting = registerState.status == RegisterStatus.submitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: PmLogo(size: 28)),
                      const SizedBox(height: 24),
                      Text(
                        'Crear cuenta',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        )
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      if (registerState.status == RegisterStatus.error &&
                          registerState.error != null) ...[
                        AuthErrorBanner(error: registerState.error!),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _nombreController,
                        focusNode: _nombreFocus,
                        enabled: !isSubmitting,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        maxLength: 150,
                        decoration:
                            const InputDecoration(labelText: 'Nombre completo'),
                        validator: (value) {
                          if (!isNombreValid(value ?? '')) {
                            return 'El nombre es obligatorio.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        maxLength: 190,
                        decoration: const InputDecoration(
                            labelText: 'Correo electrónico'),
                        validator: (value) {
                          if (!isEmailFormatValid(value ?? '')) {
                            return (value ?? '').trim().isEmpty
                                ? 'El correo es obligatorio.'
                                : 'Ingresa un correo válido.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 12),
                      PasswordField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        label: 'Contraseña',
                        enabled: !isSubmitting,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) {
                          final problems = passwordProblems(value ?? '');
                          return problems.isEmpty ? null : problems.join('\n');
                        },
                        onFieldSubmitted: (_) => _telefonoFocus.requestFocus(),
                      ),
                      const SizedBox(height: 4),
                      const _PasswordHint(),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telefonoController,
                        focusNode: _telefonoFocus,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono (opcional)',
                          counterText: '',
                        ),
                        validator: (value) {
                          if (!isTelefonoValid(value ?? '')) {
                            return 'El teléfono es demasiado corto.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                TextInput.finishAutofillContext();
                                _submit();
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Crear cuenta'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed:
                            isSubmitting ? null : () => context.go('/login'),
                        child: const Text('¿Ya tienes cuenta? Inicia sesión'),
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

class _PasswordHint extends StatelessWidget {
  const _PasswordHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 4),
      child: Text(
        'Mínimo 12 caracteres, con mayúscula, minúscula y un número.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}
