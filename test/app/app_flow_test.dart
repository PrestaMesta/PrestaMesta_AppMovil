import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/app/app.dart';
import 'package:prestamesta_app/app/providers.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/loans/data/loans_repository.dart';
import 'package:prestamesta_app/features/loans/presentation/loan_submission_controller.dart';

import '../support/fake_http_client_adapter.dart';

/// End-to-end widget/router coverage for Checkpoint 2: splash → login →
/// authenticated shell → tabs → logout → back to login, driven through the
/// real [PrestaMestaApp]/`routerProvider`/`authControllerProvider` — only
/// the network (`authRepositoryProvider`) and secure storage
/// (`sessionLocalStorageProvider`) are swapped for in-memory fakes, so this
/// never touches a real backend, the network, or the platform's secure
/// storage.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

AuthRepository _repository(ResponseBody Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(responder);
  return AuthRepository(dio);
}

/// `routerProvider` reads `loanSubmissionControllerProvider` (hence
/// `loansRepositoryProvider`) unconditionally on every redirect check, even
/// in tests that never touch the loan flow — same reasoning as
/// `authRepositoryProvider` always needing an override. Never actually
/// invoked by any test in this file.
LoansRepository _unusedLoansRepository() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = FakeHttpClientAdapter(
      (options) =>
          throw StateError('LoansRepository should not be called in this test'),
    );
  return LoansRepository(dio);
}

String _validToken() {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  return '${encode({
        'alg': 'HS256',
      })}.${encode({'sub': 1, 'exp': exp})}.sig';
}

ResponseBody _successfulLoginResponse(RequestOptions options) {
  return jsonResponseBody({
    'mensaje': 'Autenticación exitosa',
    'token': _validToken(),
    'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
  }, 200);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required AuthRepository authRepository,
  SessionLocalStorage? sessionStorage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        sessionLocalStorageProvider.overrideWithValue(
          sessionStorage ?? SessionLocalStorage(FakeSecureStorage()),
        ),
        loansRepositoryProvider.overrideWithValue(_unusedLoansRepository()),
      ],
      child: const PrestaMestaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).first, 'juan@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'ClaveSegura123');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'no session: restoration resolves to the login screen, not the shell',
      (tester) async {
    await _pumpApp(tester,
        authRepository: _repository((_) => throw StateError('unused')));

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Perfil'), findsNothing);
  });

  testWidgets('successful login navigates into the shell with all five tabs',
      (tester) async {
    await _pumpApp(tester,
        authRepository: _repository(_successfulLoginResponse));

    await _login(tester);

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Simulación'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('failed login shows a visible error banner and stays on login',
      (tester) async {
    await _pumpApp(
      tester,
      authRepository: _repository(
        (options) => jsonResponseBody({
          'mensaje': 'Credenciales inválidas.',
          'codigo': 'INVALID_CREDENTIALS'
        }, 401),
      ),
    );

    await _login(tester);

    expect(find.text('Credenciales inválidas.'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('the register link navigates to the register screen',
      (tester) async {
    await _pumpApp(tester,
        authRepository: _repository((_) => throw StateError('unused')));

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre completo'), findsOneWidget);
  });

  testWidgets(
      'successful registration returns to login without creating a session',
      (tester) async {
    await _pumpApp(
      tester,
      authRepository: _repository(
        (options) => jsonResponseBody(
            {'mensaje': 'Cliente registrado exitosamente', 'clienteId': 1},
            201),
      ),
    );

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'), 'Juan Pérez');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        'juan@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'ClaveSegura123');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Nombre completo'), findsNothing);
  });

  testWidgets(
      'switching tabs keeps each branch mounted (StatefulShellRoute keeps state)',
      (tester) async {
    await _pumpApp(tester,
        authRepository: _repository(_successfulLoginResponse));
    await _login(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsNothing);
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets(
      'logout from the profile tab clears the session and returns to login',
      (tester) async {
    await _pumpApp(tester,
        authRepository: _repository(_successfulLoginResponse));
    await _login(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'confirmation dialog should be open here');
    // Confirmation dialog is up; confirm.
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('after logout, the system back gesture does not reopen the shell',
      (tester) async {
    await _pumpApp(tester,
        authRepository: _repository(_successfulLoginResponse));
    await _login(tester);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);

    // Simulate the Android back gesture at the root of the navigation stack.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Still on login — there is no /app history entry left to pop back into.
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
