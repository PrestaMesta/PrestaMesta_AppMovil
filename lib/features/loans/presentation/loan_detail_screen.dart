import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../theme/app_theme.dart';
import '../data/loan_detail.dart';
import 'loan_detail_controller.dart';
import 'loan_detail_state.dart';
import 'loan_status_label.dart';

/// `GET /client/prestamos/:id` — the credit, aval (when one exists), and
/// every server-authoritative amount for a single loan. [loanId] is `null`
/// only when the route's `:id` segment wasn't a valid positive integer (a
/// malformed deep link); that case never calls the repository at all, since
/// there is nothing meaningful to ask the server for.
class LoanDetailScreen extends ConsumerWidget {
  final int? loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = loanId;
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Solicitud')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Identificador de solicitud inválido.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      );
    }

    final state = ref.watch(loanDetailControllerProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de solicitud')),
      body: SafeArea(
        child: switch (state.status) {
          LoanDetailStatus.loading => const _LoadingBody(),
          LoanDetailStatus.error => _ErrorBody(
              mensaje: state.error?.mensaje,
              requestId: state.error?.requestId,
              onRetry: () =>
                  ref.read(loanDetailControllerProvider(id).notifier).retry(),
            ),
          LoanDetailStatus.data => _DetailBody(detail: state.detail!),
        },
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Cargando detalle de la solicitud',
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String? mensaje;
  final String? requestId;
  final VoidCallback onRetry;
  const _ErrorBody(
      {required this.mensaje, required this.requestId, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                mensaje ?? 'No se pudo cargar esta solicitud.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              if (requestId != null && requestId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Referencia: $requestId',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final PrestamoDetalle detail;
  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final aval = detail.aval;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.credito.nombre,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  estadoPrestamoLabel(detail.estado),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greenEnd),
                ),
                const Divider(height: 24),
                _Row('Número de solicitud', '#${detail.id}'),
                const SizedBox(height: 8),
                _Row('Monto solicitado', formatMoney(detail.montoSolicitado)),
                const SizedBox(height: 8),
                _Row('Monto total a pagar',
                    formatMoney(detail.montoTotalAPagar)),
                const SizedBox(height: 8),
                _Row('Saldo pendiente', formatMoney(detail.saldoPendiente)),
                const SizedBox(height: 8),
                _Row('Fecha de solicitud',
                    formatLoanDate(detail.fechaSolicitud)),
                if (detail.fechaDecision != null) ...[
                  const SizedBox(height: 8),
                  _Row('Fecha de decisión',
                      formatLoanDate(detail.fechaDecision!)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAL',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                if (aval == null)
                  const Text(
                    'Esta solicitud no tiene un aval registrado.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  )
                else ...[
                  _Row('Nombre', aval.nombre),
                  const SizedBox(height: 8),
                  _Row('Teléfono', aval.telefono),
                  if (aval.direccion != null) ...[
                    const SizedBox(height: 8),
                    _Row('Dirección', aval.direccion!),
                  ],
                  if (aval.ingresoMensual != null) ...[
                    const SizedBox(height: 8),
                    _Row('Ingreso mensual', formatMoney(aval.ingresoMensual!)),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Esta información corresponde a la consulta más reciente al servidor. '
            'Vuelve a esta pantalla para ver cambios de estado.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
