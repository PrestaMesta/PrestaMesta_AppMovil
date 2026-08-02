/// All data in this file is hardcoded / fictional, matching the
/// "Interfaz de demostración con datos ficticios" disclaimer used
/// throughout prestamesta.fun.
class DemoData {
  DemoData._();

  static const String userName = 'Alex';

  // Resumen de préstamo
  static const double nextPaymentAmount = 1250;
  static const String nextPaymentCurrency = 'MXN';
  static const String nextPaymentDueLabel = 'Vence el 15 de cada mes';

  static const double estimatedBalance = 8750;

  // Estado de solicitud
  static const String applicationStatus = 'En revisión (demo)';
  static const double applicationProgress = 0.55;

  static const List<StatusStep> statusSteps = [
    StatusStep(title: 'Solicitud enviada', done: true, date: '02 jul'),
    StatusStep(title: 'Documentos validados', done: true, date: '05 jul'),
    StatusStep(title: 'En revisión', done: false, date: 'En curso'),
    StatusStep(title: 'Aprobación', done: false, date: 'Pendiente'),
    StatusStep(title: 'Depósito', done: false, date: 'Pendiente'),
  ];

  static const List<PaymentItem> upcomingPayments = [
    PaymentItem(label: 'Pago de agosto', date: '15 ago 2026', amount: 1250, status: PaymentStatus.upcoming),
    PaymentItem(label: 'Pago de julio', date: '15 jul 2026', amount: 1250, status: PaymentStatus.paid),
    PaymentItem(label: 'Pago de junio', date: '15 jun 2026', amount: 1250, status: PaymentStatus.paid),
  ];

  static const List<LoanOption> simulationOptions = [
    LoanOption(amount: 5000, months: 6, monthlyPayment: 950),
    LoanOption(amount: 8750, months: 12, monthlyPayment: 1250),
    LoanOption(amount: 15000, months: 18, monthlyPayment: 1480),
  ];
}

class StatusStep {
  final String title;
  final bool done;
  final String date;
  const StatusStep({required this.title, required this.done, required this.date});
}

enum PaymentStatus { paid, upcoming }

class PaymentItem {
  final String label;
  final String date;
  final double amount;
  final PaymentStatus status;
  const PaymentItem({
    required this.label,
    required this.date,
    required this.amount,
    required this.status,
  });
}

class LoanOption {
  final double amount;
  final int months;
  final double monthlyPayment;
  const LoanOption({
    required this.amount,
    required this.months,
    required this.monthlyPayment,
  });
}
