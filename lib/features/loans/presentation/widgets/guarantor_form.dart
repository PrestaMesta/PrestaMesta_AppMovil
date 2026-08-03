import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';
import '../../../credits/data/amount_input_parser.dart';
import '../../data/guarantor.dart';
import '../../data/loan_validators.dart';

/// [enabled] tells the caller whether the section is toggled on at all;
/// [guarantor] is non-null only when it's toggled on **and** every field is
/// currently valid — the caller (the review screen) uses `enabled &&
/// guarantor == null` to know the section is on but not ready, and must
/// block "Enviar solicitud" for that case without treating "toggled off" as
/// an error.
class GuarantorFormResult {
  final bool enabled;
  final Guarantor? guarantor;
  const GuarantorFormResult({required this.enabled, required this.guarantor});

  bool get blocksSubmit => enabled && guarantor == null;
}

/// The optional "aval" section — off by default. No field here is ever sent
/// to the server (or logged) unless the section is explicitly enabled by the
/// user and every required field validates.
class GuarantorForm extends StatefulWidget {
  final ValueChanged<GuarantorFormResult> onChanged;
  const GuarantorForm({super.key, required this.onChanged});

  @override
  State<GuarantorForm> createState() => _GuarantorFormState();
}

class _GuarantorFormState extends State<GuarantorForm> {
  bool _enabled = false;
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ingresoController = TextEditingController();
  final _nombreFocus = FocusNode();
  final _telefonoFocus = FocusNode();
  final _direccionFocus = FocusNode();
  final _ingresoFocus = FocusNode();

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _ingresoController.dispose();
    _nombreFocus.dispose();
    _telefonoFocus.dispose();
    _direccionFocus.dispose();
    _ingresoFocus.dispose();
    super.dispose();
  }

  void _toggle(bool value) {
    setState(() {
      _enabled = value;
      if (!value) {
        // Clearing (not just hiding) the fields when the user turns the
        // section off, so nothing lingers in memory or gets sent by accident
        // if it's turned back on and off again.
        _nombreController.clear();
        _telefonoController.clear();
        _direccionController.clear();
        _ingresoController.clear();
      }
    });
    _emit();
  }

  void _emit() {
    if (!_enabled) {
      widget.onChanged(
          const GuarantorFormResult(enabled: false, guarantor: null));
      return;
    }

    final nombre = _nombreController.text.trim();
    final telefono = _telefonoController.text.trim();
    final direccion = _direccionController.text.trim();
    final ingresoRaw = _ingresoController.text.trim();

    final nombreOk = isGuarantorNombreValid(nombre);
    final telefonoOk = isGuarantorTelefonoValid(telefono);
    final direccionOk = isGuarantorDireccionValid(direccion);
    final ingresoOk = ingresoRaw.isEmpty || parseUserAmount(ingresoRaw) != null;

    if (!nombreOk || !telefonoOk || !direccionOk || !ingresoOk) {
      widget
          .onChanged(const GuarantorFormResult(enabled: true, guarantor: null));
      return;
    }

    widget.onChanged(
      GuarantorFormResult(
        enabled: true,
        guarantor: Guarantor(
          nombre: nombre,
          telefono: telefono,
          direccion: direccion.isEmpty ? null : direccion,
          ingresoMensual:
              ingresoRaw.isEmpty ? null : parseUserAmount(ingresoRaw),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Agregar aval (opcional)',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          value: _enabled,
          onChanged: _toggle,
          activeThumbColor: AppColors.greenEnd,
        ),
        if (_enabled) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _nombreController,
            focusNode: _nombreFocus,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: 'Nombre del aval',
              errorText: _nombreController.text.isEmpty
                  ? null
                  : (isGuarantorNombreValid(_nombreController.text)
                      ? null
                      : 'Máximo 150 caracteres.'),
            ),
            onChanged: (_) => setState(_emit),
            onFieldSubmitted: (_) => _telefonoFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telefonoController,
            focusNode: _telefonoFocus,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'Teléfono del aval',
              errorText: _telefonoController.text.isEmpty
                  ? null
                  : (isGuarantorTelefonoValid(_telefonoController.text)
                      ? null
                      : 'Debe tener entre 7 y 20 caracteres.'),
            ),
            onChanged: (_) => setState(_emit),
            onFieldSubmitted: (_) => _direccionFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _direccionController,
            focusNode: _direccionFocus,
            textInputAction: TextInputAction.next,
            maxLength: 255,
            decoration:
                const InputDecoration(labelText: 'Dirección (opcional)'),
            onChanged: (_) => setState(_emit),
            onFieldSubmitted: (_) => _ingresoFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ingresoController,
            focusNode: _ingresoFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Ingreso mensual (opcional)',
              prefixText: r'$ ',
              errorText: _ingresoController.text.trim().isEmpty
                  ? null
                  : (parseUserAmount(_ingresoController.text) == null
                      ? 'Ingresa un monto válido.'
                      : null),
            ),
            onChanged: (_) => setState(_emit),
          ),
        ],
      ],
    );
  }
}
