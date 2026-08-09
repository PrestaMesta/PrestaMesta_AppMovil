import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/config/env_config.dart';
import 'package:prestamesta_app/core/errors/app_exception.dart';
import 'package:prestamesta_app/core/network/api_client.dart';
import 'package:prestamesta_app/features/auth/data/auth_repository.dart';
import 'package:prestamesta_app/features/auth/data/mfa_models.dart';

import '../../../support/fake_http_client_adapter.dart';

AuthRepository _repository(FakeHttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return AuthRepository(dio);
}

void main() {
  group('AuthRepository.mfaEnroll', () {
    test('sends Authorization: Bearer <preMfaToken> and parses the response',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Escanea el codigo QR.',
          'secreto': 'JBSWY3DPEHPK3PXP',
          'otpauthUri':
              'otpauth://totp/Prestamesta:juan?secret=JBSWY3DPEHPK3PXP',
        }, 201),
      );
      final repository = _repository(adapter);

      final result = await repository.mfaEnroll('pre-mfa-token-abc');

      expect(adapter.capturedRequests.single.path, '/client/auth/mfa/enroll');
      expect(adapter.capturedRequests.single.headers['Authorization'],
          'Bearer pre-mfa-token-abc');
      expect(result.secreto, 'JBSWY3DPEHPK3PXP');
    });

    test(
        'throws AppException(conflicto) on 409 MFA_CHALLENGE_REQUIRED '
        '(MFA already ACTIVO — a preMfaToken cannot re-enroll)', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'El MFA ya esta activo para esta cuenta.',
          'codigo': 'MFA_CHALLENGE_REQUIRED',
        }, 409),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaEnroll('pre-mfa-token'),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.conflicto)
            .having((e) => e.codigo, 'codigo', 'MFA_CHALLENGE_REQUIRED')),
      );
    });

    test('throws AppException(noAutenticado) on 401 TOKEN_EXPIRED', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody(
            {'mensaje': 'Token expirado', 'codigo': 'TOKEN_EXPIRED'}, 401),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaEnroll('expired-pre-mfa-token'),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.noAutenticado)
            .having((e) => e.codigo, 'codigo', 'TOKEN_EXPIRED')),
      );
    });
  });

  group('AuthRepository.mfaEnrollConfirm', () {
    test(
        'sends the code and Authorization: Bearer <preMfaToken>, parses '
        'token + cliente + codigosRecuperacion', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Autenticacion exitosa.',
          'token': 'session-token',
          'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
          'codigosRecuperacion': List.generate(10, (i) => 'CODE-$i'),
        }, 200),
      );
      final repository = _repository(adapter);

      final result = await repository.mfaEnrollConfirm(
          'pre-mfa-token-abc', const MfaEnrollConfirmRequest(codigo: '123456'));

      final captured = adapter.capturedRequests.single;
      expect(captured.path, '/client/auth/mfa/enroll/confirm');
      expect(captured.headers['Authorization'], 'Bearer pre-mfa-token-abc');
      expect(captured.data, {'codigo': '123456'});
      expect(result.token, 'session-token');
      expect(result.codigosRecuperacion, hasLength(10));
    });

    test(
        'throws AppException(validacion) on 400 MFA_ENROLLMENT_INVALID '
        '(invalid or already-used confirmation code)', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Codigo invalido o ya utilizado.',
          'codigo': 'MFA_ENROLLMENT_INVALID',
        }, 400),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaEnrollConfirm(
            'pre-mfa-token', const MfaEnrollConfirmRequest(codigo: '000000')),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.validacion)
            .having((e) => e.codigo, 'codigo', 'MFA_ENROLLMENT_INVALID')),
      );
    });

    test('throws AppException(demasiadasSolicitudes) on 429 MFA_RATE_LIMITED',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody(
            {'mensaje': 'Demasiados intentos.', 'codigo': 'MFA_RATE_LIMITED'},
            429),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaEnrollConfirm(
            'pre-mfa-token', const MfaEnrollConfirmRequest(codigo: '123456')),
        throwsA(isA<AppException>().having(
            (e) => e.type, 'type', AppExceptionType.demasiadasSolicitudes)),
      );
    });
  });

  group('AuthRepository.mfaVerify', () {
    test('sends Authorization: Bearer <preMfaToken> with a TOTP request',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Autenticacion exitosa.',
          'token': 'session-token',
          'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
        }, 200),
      );
      final repository = _repository(adapter);

      final result = await repository.mfaVerify(
          'pre-mfa-token-xyz', const MfaVerifyRequest.totp('123456'));

      final captured = adapter.capturedRequests.single;
      expect(captured.path, '/client/auth/mfa/verify');
      expect(captured.headers['Authorization'], 'Bearer pre-mfa-token-xyz');
      expect(captured.data, {'codigo': '123456'});
      expect(result.token, 'session-token');
      expect(result.codigosRecuperacion, isNull,
          reason: 'mfa/verify never returns recovery codes');
    });

    test('sends a recovery-code request with exactly codigoRecuperacion',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Autenticacion exitosa.',
          'token': 'session-token',
          'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
        }, 200),
      );
      final repository = _repository(adapter);

      await repository.mfaVerify('pre-mfa-token',
          const MfaVerifyRequest.recoveryCode('A1B2-C3D4-E5F6-0708-090A'));

      expect(adapter.capturedRequests.single.data,
          {'codigoRecuperacion': 'A1B2-C3D4-E5F6-0708-090A'});
    });

    test('throws AppException(noAutenticado) on 401 MFA_INVALID_CODE',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Codigo invalido.',
          'codigo': 'MFA_INVALID_CODE',
        }, 401),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaVerify(
            'pre-mfa-token', const MfaVerifyRequest.totp('000000')),
        throwsA(isA<AppException>()
            .having((e) => e.type, 'type', AppExceptionType.noAutenticado)
            .having((e) => e.codigo, 'codigo', 'MFA_INVALID_CODE')),
      );
    });

    test('throws with codigo MFA_CODE_REUSED when the same TOTP is reused',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Este codigo ya fue utilizado.',
          'codigo': 'MFA_CODE_REUSED',
        }, 401),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaVerify(
            'pre-mfa-token', const MfaVerifyRequest.totp('123456')),
        throwsA(isA<AppException>()
            .having((e) => e.codigo, 'codigo', 'MFA_CODE_REUSED')),
      );
    });

    test(
        'throws with codigo RECOVERY_CODE_ALREADY_USED for a spent recovery '
        'code', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Este codigo de recuperacion ya fue utilizado.',
          'codigo': 'RECOVERY_CODE_ALREADY_USED',
        }, 401),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaVerify('pre-mfa-token',
            const MfaVerifyRequest.recoveryCode('A1B2-C3D4-E5F6-0708-090A')),
        throwsA(isA<AppException>()
            .having((e) => e.codigo, 'codigo', 'RECOVERY_CODE_ALREADY_USED')),
      );
    });

    test(
        'throws AppException(noAutenticado) on 401 TOKEN_EXPIRED '
        '(the pre-MFA token itself expired mid-challenge)', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody(
            {'mensaje': 'Token expirado', 'codigo': 'TOKEN_EXPIRED'}, 401),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaVerify(
            'expired-pre-mfa-token', const MfaVerifyRequest.totp('123456')),
        throwsA(isA<AppException>()
            .having((e) => e.codigo, 'codigo', 'TOKEN_EXPIRED')),
      );
    });

    test('throws AppException(demasiadasSolicitudes) on 429 MFA_RATE_LIMITED',
        () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody(
            {'mensaje': 'Demasiados intentos.', 'codigo': 'MFA_RATE_LIMITED'},
            429),
      );
      final repository = _repository(adapter);

      await expectLater(
        repository.mfaVerify(
            'pre-mfa-token', const MfaVerifyRequest.totp('123456')),
        throwsA(isA<AppException>().having(
            (e) => e.type, 'type', AppExceptionType.demasiadasSolicitudes)),
      );
    });
  });

  group('pre-MFA vs session Authorization separation (end to end)', () {
    test(
        'through the real ApiClient/AuthInterceptor, an MFA call never picks '
        'up the session token from readToken — it only ever sends the '
        'explicit preMfaToken passed to it', () async {
      final adapter = FakeHttpClientAdapter(
        (options) => jsonResponseBody({
          'mensaje': 'Escanea el codigo QR.',
          'secreto': 'ABC',
          'otpauthUri': 'otpauth://totp/x',
        }, 201),
      );
      final config = EnvConfig.parse(
          appEnvRaw: 'local', apiBaseUrlRaw: 'http://10.0.2.2:3000');
      final apiClient = ApiClient.create(
        config: config,
        // A stale *session* token sitting in storage — must never leak into
        // an MFA call, which only ever uses the preMfaToken explicitly
        // passed to AuthRepository's MFA methods (see the doc comment on
        // AuthRepository — MFA calls never set requiresAuthExtraKey).
        readToken: () async => 'stale-session-token-from-a-previous-login',
        onSessionRejected: () {},
      );
      apiClient.dio.httpClientAdapter = adapter;
      final repository = AuthRepository(apiClient.dio);

      await repository.mfaEnroll('the-real-pre-mfa-token');

      expect(adapter.capturedRequests.single.headers['Authorization'],
          'Bearer the-real-pre-mfa-token',
          reason: 'must be the explicit preMfaToken, never the session token '
              'AuthInterceptor would have attached via requiresAuthExtraKey');
    });
  });
}
