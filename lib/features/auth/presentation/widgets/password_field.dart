import 'package:flutter/material.dart';

/// A password field with a show/hide toggle, used identically by login and
/// register. Kept as one shared widget so both screens get the same
/// behavior (obscure-by-default, accessible toggle) instead of drifting.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? errorText;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final FormFieldValidator<String>? validator;

  const PasswordField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.label,
    this.errorText,
    this.textInputAction = TextInputAction.done,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.validator,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      enabled: widget.enabled,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 3,
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
