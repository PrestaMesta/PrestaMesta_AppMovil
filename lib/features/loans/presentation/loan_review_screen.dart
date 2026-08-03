import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../theme/app_theme.dart';
import '../../credits/data/loan_estimate.dart';
import '../../credits/presentation/credits_controller.dart';
import '../data/loan_request.dart';
import 'loan_draft.dart';
import 'loan_submission_controller.dart';
import 'loan_submission_state.dart';
import 'widgets/guarantor_form.dart';

/// Masks all but the last 4 characters (e.g. `8711234567` → `******4567`),
/// so a phone number entered into the form isn't redisplayed in full a
/// second time in the summary just above it. Short values are masked
/// entirely rather than throwing.
String _maskPhone(String phone) {
  if (phone.length <= 4) return '*' * phone.length;
  return '*' * (phone.length - 4) + phone.substring(phone.length - 4);
}

/// Review before `POST /prestamos/solicitar`. Requires a valid
/// [LoanDraft] — the router redirects away (back to simulation) before this
/// screen is ever built without one, but this build method still guards
/// defensively against a draft disappearing mid-screen (e.g. a background
/// logout, which the router also handles, but belt-and-suspenders costs
/// nothing here).
class LoanReviewScreen extends ConsumerStatefulWidget {
  const LoanReviewScreen({super.key});

  @override
  ConsumerState<LoanReviewScreen> createState() => _LoanReviewScreenState();
}

class _LoanReviewScreenState extends ConsumerState<LoanReviewScreen> {
  GuarantorFormResult _guarantorResult =
      const GuarantorFormResult(enabled: false, guarantor: null);

  void _submit(LoanDraft draft) {
    if (_guarantorResult.blocksSubmit) return;
    final request = LoanRequest(
      creditoId: draft.credito.id,
      montoSolicitado: draft.montoSolicitado,
      aval: _guarantorResult.guarantor,
    );
    ref.read(loanSubmissionControllerProvider.notifier).submit(request);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(loanDraftControllerProvider);
    final submissionState = ref.watch(loanSubmissionControllerProvider);

    ref.listen<LoanSubmissionState>(loanSubmissionControllerProvider,
        (previous, next) {
      if (next.status == LoanSubmissionStatus.success) {
        ref.read(loanDraftControllerProvider.notifier).clear();
        context.go('/app/simulacion/confirmacion');
      }
    });

    if (draft == null) {
      // The router redirects away almost immediately; this avoids a null
      // dereference in the brief window before that happens.
      return const SizedBox.shrink();
    }

    if (submissionState.status == LoanSubmissionStatus.outcomeUnknown) {
      return _OutcomeUnknownView(requestId: submissionState.ambiguousRequestId);
    }

    final isCreditGone =
        submissionState.status == LoanSubmissionStatus.failure &&
            submissionState.error?.codigo == 'CREDIT_NOT_FOUND';
    if (isCreditGone) {
      return _CreditGoneView(mensaje: submissionState.error!.mensaje);
    }

    final isSubmitting =
        submissionState.status == LoanSubmissionStatus.submitting;
    final estimate = calculateEstimate(
      amount: draft.montoSolicitado,
      annualRatePercent: draft.credito.tasaInteresAnual,
      termMonths: draft.credito.plazoMeses,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar solicitud')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (submissionState.status == LoanSubmissionStatus.failure &&
                  !isCreditGone) ...[
                _ReviewErrorBanner(error: submissionState.error!),
                const SizedBox(height: 16),
              ],
              _SummaryCard(draft: draft, estimate: estimate),
              const SizedBox(height: 20),
              GuarantorForm(
                  onChanged: (result) =>
                      setState(() => _guarantorResult = result)),
              if (_guarantorResult.guarantor != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Aval: ${_guarantorResult.guarantor!.nombre} · '
                  'tel. ${_maskPhone(_guarantorResult.guarantor!.telefono)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'El estado inicial de la solicitud será "Pendiente de revisión". El total '
                'mostrado arriba es una estimación — el servidor calcula el monto '
                'definitivo al recibir la solicitud.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: isSubmitting ? null : () => context.pop(),
                child: const Text('Volver y editar'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (isSubmitting || _guarantorResult.blocksSubmit)
                    ? null
                    : () => _submit(draft),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Enviar solicitud'),
              ),
              const SizedBox(height: 8),
              const Text(
                '"Enviar solicitud" realiza una operación real contra el servidor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final LoanDraft draft;
  final LoanEstimate estimate;
  const _SummaryCard({required this.draft, required this.estimate});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            draft.credito.nombre,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          _Row('Monto solicitado', formatMoney(draft.montoSolicitado)),
          const SizedBox(height: 6),
          _Row('Tasa anual', formatPercent(draft.credito.tasaInteresAnual)),
          const SizedBox(height: 6),
          _Row('Plazo', '${draft.credito.plazoMeses} meses'),
          const SizedBox(height: 6),
          _Row('Interés estimado', formatMoney(estimate.estimatedInterest)),
          const Divider(height: 20),
          _Row('Total estimado', formatMoney(estimate.estimatedTotal),
              emphasize: true),
          const SizedBox(height: 12),
          const Text(
            'Estimación. El monto definitivo lo calcula el servidor al enviar la solicitud.',
            style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _Row(this.label, this.value, {this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ReviewErrorBanner extends StatelessWidget {
  final AppException error;
  const _ReviewErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final requestId = error.requestId;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFCE8E8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF2B8B8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.mensaje,
              style: const TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5),
            ),
            if (requestId != null && requestId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Referencia: $requestId',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutcomeUnknownView extends StatelessWidget {
  final String? requestId;
  const _OutcomeUnknownView({required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('No se pudo confirmar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.help_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text(
                'No pudimos confirmar si la solicitud fue registrada. Para evitar una '
                'solicitud duplicada, no la envíes nuevamente por ahora.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              const Text(
                'Actualmente la aplicación no puede consultar solicitudes propias, así que '
                'no podemos verificar el resultado desde aquí.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              if (requestId != null && requestId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Referencia: $requestId',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/app/simulacion'),
                child: const Text('Volver a simulación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditGoneView extends StatelessWidget {
  final String mensaje;
  const _CreditGoneView({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crédito no disponible')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este crédito ya no está disponible en el catálogo. Vuelve a la simulación y '
                'actualiza el catálogo para elegir otro.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Consumer(
                builder: (context, ref, _) {
                  return FilledButton(
                    onPressed: () {
                      ref.read(loanDraftControllerProvider.notifier).clear();
                      ref.read(creditsControllerProvider.notifier).refresh();
                      context.go('/app/simulacion');
                    },
                    child: const Text('Volver al catálogo'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
