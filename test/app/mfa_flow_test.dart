import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prestamesta_app/app/app.dart';
import 'package:prestamesta_app/app/providers.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_controller.dart';

import '../support/fake_http_client_adapter.dart';

/// End-to-end Checkpoint 6D coverage: login → MFA (enrollment or challenge)
/// → real session → shell, driven through the real
/// [PrestaMestaApp]/`routerProvider`/`authControllerProvider`/
/// `mfaControllerProvider` — only the network (`authRepositoryProvider`) and
/// secure storage (`sessionLocalStorageProvider`) are swapped for in-memory
/// fakes, same pattern as `test/app/app_flow_test.dart`.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

LoansRepository _unusedLoansRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(
      (options) =>
          throw StateError('LoansRepository should not be called in this test'),
    );
  return LoansRepository(dio);
}

const _enrollmentLoginJson = {
  'mensaje': 'Verifica tu identidad para continuar.',
  'preMfaToken': 'pre-mfa-token',
  'siguientePaso': 'MFA_ENROLLMENT_REQUIRED',
};

const _challengeLoginJson = {
  'mensaje': 'Verifica tu identidad para continuar.',
  'preMfaToken': 'pre-mfa-token',
  'siguientePaso': 'MFA_CHALLENGE_REQUIRED',
};

const _enrollJson = {
  'mensaje': 'Escanea el codigo QR.',
  'secreto': 'JBSWY3DPEHPK3PXP',
  'otpauthUri': 'otpauth://totp/Prestamesta:juan?secret=JBSWY3DPEHPK3PXP',
};

Map<String, dynamic> _sessionJson({List<String>? codigosRecuperacion}) => {
      'mensaje': 'Autenticacion exitosa.',
      'token': 'real-session-token',
      'cliente': {'id': 1, 'nombre': 'Juan Pérez', 'email': 'juan@example.com'},
      if (codigosRecuperacion != null)
        'codigosRecuperacion': codigosRecuperacion,
    };

AuthRepository _enrollmentRepository({int? confirmFailuresBeforeSuccess}) {
  var confirmAttempts = 0;
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      if (options.path == '/client/auth/mfa/enroll') {
        return jsonResponseBody(_enrollJson, 201);
      }
      if (options.path == '/client/auth/mfa/enroll/confirm') {
        confirmAttempts++;
        final failuresWanted = confirmFailuresBeforeSuccess ?? 0;
        if (confirmAttempts <= failuresWanted) {
          return jsonResponseBody({
            'mensaje': 'Codigo invalido o ya utilizado.',
            'codigo': 'MFA_ENROLLMENT_INVALID',
          }, 400);
        }
        return jsonResponseBody(
            _sessionJson(codigosRecuperacion: List.generate(10, (i) => 'C$i')),
            200);
      }
      return jsonResponseBody(_enrollmentLoginJson, 200);
    });
  return AuthRepository(dio);
}

AuthRepository _challengeRepository({
  int? verifyFailuresBeforeSuccess,
  String verifyFailureCodigo = 'MFA_INVALID_CODE',
  void Function(RequestOptions)? onVerify,
}) {
  var verifyAttempts = 0;
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter((options) {
      if (options.path == '/client/auth/mfa/verify') {
        onVerify?.call(options);
        verifyAttempts++;
        final failuresWanted = verifyFailuresBeforeSuccess ?? 0;
        if (verifyAttempts <= failuresWanted) {
          // Real per-openapi.yaml status/message: MFA_RATE_LIMITED is 429
          // ("Demasiados intentos..."), everything else here is 401.
          final isRateLimited = verifyFailureCodigo == 'MFA_RATE_LIMITED';
          return jsonResponseBody({
            'mensaje': isRateLimited
                ? 'Demasiados intentos. Intenta de nuevo mas tarde.'
                : 'Codigo invalido.',
            'codigo': verifyFailureCodigo,
          }, isRateLimited ? 429 : 401);
        }
        return jsonResponseBody(_sessionJson(), 200);
      }
      return jsonResponseBody(_challengeLoginJson, 200);
    });
  return AuthRepository(dio);
}

Future<void> _pumpApp(WidgetTester tester,
    {required AuthRepository authRepository}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        sessionLocalStorageProvider
            .overrideWithValue(SessionLocalStorage(FakeSecureStorage())),
        loansRepositoryProvider.overrideWithValue(_unusedLoansRepository()),
      ],
      child: const PrestaMestaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillPassword(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'juan@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'ClaveSegura123');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  group('login → enrollment', () {
    testWidgets(
        'shows the QR/secret, confirming a code moves to the recovery-codes '
        'screen, and /app is unreachable until the save is acknowledged',
        (tester) async {
      await _pumpApp(tester, authRepository: _enrollmentRepository());

      await _fillPassword(tester);

      expect(
          find.text('Configura la verificación en dos pasos'), findsOneWidget);
      expect(find.byType(Image), findsNothing); // QR is drawn, not an Image
      expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsOneWidget,
          reason: 'the manual secret must be shown as a fallback to the QR');

      // Attempting to jump straight into /app while enrollment is pending
      // must not work — router.dart#mfaRedirect pins this back here.
      final context = tester.element(find.byType(TextFormField).first);
      GoRouter.of(context).go('/app/inicio');
      await tester.pumpAndSettle();
      expect(
          find.text('Configura la verificación en dos pasos'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Confirmar y activar'));
      await tester.tap(find.text('Confirmar y activar'));
      await tester.pumpAndSettle();

      expect(find.text('Guarda tus códigos de recuperación'), findsOneWidget);
      expect(find.text('C0'), findsOneWidget);
      final continueButton = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'));
      expect(continueButton.onPressed, isNull,
          reason: 'must stay disabled until the checkbox is checked');

      // Still not authenticated — a direct /app deep link still bounces
      // back. Re-fetches the context: the previous one belonged to the
      // enrollment-ready screen's TextFormField, which was torn down when
      // the phase switched to recoveryCodesPendingAck.
      final recoveryCodesContext =
          tester.element(find.text('Guarda tus códigos de recuperación'));
      GoRouter.of(recoveryCodesContext).go('/app/inicio');
      await tester.pumpAndSettle();
      expect(find.text('Guarda tus códigos de recuperación'), findsOneWidget);

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final enabledButton = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'));
      expect(enabledButton.onPressed, isNotNull);

      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Guarda tus códigos de recuperación'), findsNothing);
    });

    testWidgets(
        'an invalid confirmation code shows an error and stays on '
        'the enrollment screen for a retry', (tester) async {
      await _pumpApp(tester,
          authRepository:
              _enrollmentRepository(confirmFailuresBeforeSuccess: 1));

      await _fillPassword(tester);
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.ensureVisible(find.text('Confirmar y activar'));
      await tester.tap(find.text('Confirmar y activar'));
      await tester.pumpAndSettle();

      expect(find.text('Codigo invalido o ya utilizado.'), findsOneWidget);
      expect(
          find.text('Configura la verificación en dos pasos'), findsOneWidget);

      // Retry succeeds.
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.text('Confirmar y activar'));
      await tester.tap(find.text('Confirmar y activar'));
      await tester.pumpAndSettle();

      expect(find.text('Guarda tus códigos de recuperación'), findsOneWidget);
    });

    testWidgets('cancelling returns to the login screen', (tester) async {
      await _pumpApp(tester, authRepository: _enrollmentRepository());
      await _fillPassword(tester);

      await tester
          .ensureVisible(find.text('Cancelar y volver al inicio de sesión'));
      await tester.tap(find.text('Cancelar y volver al inicio de sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets(
        '"Abrir en mi app de autenticación" degrades gracefully when no '
        'authenticator app/platform channel is available, instead of '
        'crashing the screen', (tester) async {
      await _pumpApp(tester, authRepository: _enrollmentRepository());
      await _fillPassword(tester);

      await tester.ensureVisible(find.text('Abrir en mi app de autenticación'));
      await tester.tap(find.text('Abrir en mi app de autenticación'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
          find.text('Configura la verificación en dos pasos'), findsOneWidget);
    });
  });

  group('login → challenge', () {
    testWidgets('a correct TOTP code enters the app', (tester) async {
      await _pumpApp(tester, authRepository: _challengeRepository());

      await _fillPassword(tester);
      expect(find.text('Verifica tu identidad'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
    });

    testWidgets(
        'switching to a recovery code and submitting it enters the '
        'app too', (tester) async {
      late RequestOptions captured;
      await _pumpApp(tester,
          authRepository:
              _challengeRepository(onVerify: (options) => captured = options));

      await _fillPassword(tester);
      await tester.tap(find.text('Usar un código de recuperación'));
      await tester.pumpAndSettle();

      expect(find.text('Código de recuperación'), findsOneWidget);
      await tester.enterText(
          find.byType(TextFormField), 'A1B2-C3D4-E5F6-0708-090A');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(captured.data, {'codigoRecuperacion': 'A1B2-C3D4-E5F6-0708-090A'});
      expect(find.text('Inicio'), findsOneWidget);
    });

    testWidgets(
        'an invalid code shows an error and stays on the challenge '
        'screen, never fabricating an "invalid credentials" message',
        (tester) async {
      await _pumpApp(tester,
          authRepository: _challengeRepository(verifyFailuresBeforeSuccess: 1));

      await _fillPassword(tester);
      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(find.text('Codigo invalido.'), findsOneWidget);
      expect(find.text('Verifica tu identidad'), findsOneWidget);
      expect(find.textContaining('Credenciales'), findsNothing);
    });

    testWidgets('a rate-limited response shows a prudent message',
        (tester) async {
      await _pumpApp(
        tester,
        authRepository: _challengeRepository(
          verifyFailuresBeforeSuccess: 1,
          verifyFailureCodigo: 'MFA_RATE_LIMITED',
        ),
      );

      await _fillPassword(tester);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Demasiados intentos'), findsOneWidget);
    });

    testWidgets('double tap on Verificar only issues one network call',
        (tester) async {
      var verifyCallCount = 0;
      await _pumpApp(
        tester,
        authRepository:
            _challengeRepository(onVerify: (_) => verifyCallCount++),
      );

      await _fillPassword(tester);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Verificar'));
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(verifyCallCount, 1);
    });

    testWidgets('cancelling returns to the login screen', (tester) async {
      await _pumpApp(tester, authRepository: _challengeRepository());
      await _fillPassword(tester);

      await tester.tap(find.text('Cancelar y volver al inicio de sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  });

  group('logout clears any pending MFA flow', () {
    testWidgets(
        'logging out and back in starts a fresh MFA flow, not a '
        'leftover one', (tester) async {
      await _pumpApp(tester, authRepository: _challengeRepository());
      await _fillPassword(tester);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsOneWidget);

      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);

      await _fillPassword(tester);
      expect(find.text('Verifica tu identidad'), findsOneWidget);
    });
  });
}
