import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/features/auth/data/mfa_models.dart';

void main() {
  group('SiguientePasoMfa.parse', () {
    test('parses both known values', () {
      expect(SiguientePasoMfa.parse('MFA_ENROLLMENT_REQUIRED'),
          SiguientePasoMfa.enrollmentRequired);
      expect(SiguientePasoMfa.parse('MFA_CHALLENGE_REQUIRED'),
          SiguientePasoMfa.challengeRequired);
    });

    test('throws on an unrecognized value rather than guessing', () {
      expect(
          () => SiguientePasoMfa.parse('SOMETHING_NEW'), throwsFormatException);
    });
  });

  group('LoginPreMfaResult.fromJson', () {
    test('parses mensaje, preMfaToken and siguientePaso', () {
      final result = LoginPreMfaResult.fromJson({
        'mensaje': 'Verifica tu identidad para continuar.',
        'preMfaToken': 'eyJhbGciOiJIUzI1NiJ9.pre-mfa.sig',
        'siguientePaso': 'MFA_CHALLENGE_REQUIRED',
        'mfaEstado': 'ACTIVO',
      });

      expect(result.preMfaToken, 'eyJhbGciOiJIUzI1NiJ9.pre-mfa.sig');
      expect(result.siguientePaso, SiguientePasoMfa.challengeRequired);
    });

    test('never exposes mfaEstado — the UI must branch on siguientePaso only',
        () {
      // No getter for mfaEstado exists at all on this class; this test just
      // documents that a response carrying it still parses fine (it's
      // informational/debug per openapi.yaml, silently ignored here).
      final result = LoginPreMfaResult.fromJson({
        'mensaje': 'x',
        'preMfaToken': 'token',
        'siguientePaso': 'MFA_ENROLLMENT_REQUIRED',
        'mfaEstado': 'PENDIENTE_CONFIRMACION',
      });
      expect(result.siguientePaso, SiguientePasoMfa.enrollmentRequired);
    });

    test('throws FormatException when preMfaToken is missing', () {
      expect(
        () => LoginPreMfaResult.fromJson(
            {'mensaje': 'x', 'siguientePaso': 'MFA_CHALLENGE_REQUIRED'}),
        throwsFormatException,
      );
    });

    test('throws FormatException when preMfaToken is an empty string', () {
      expect(
        () => LoginPreMfaResult.fromJson({
          'mensaje': 'x',
          'preMfaToken': '',
          'siguientePaso': 'MFA_CHALLENGE_REQUIRED',
        }),
        throwsFormatException,
      );
    });

    test('throws FormatException when siguientePaso is missing', () {
      expect(
        () => LoginPreMfaResult.fromJson(
            {'mensaje': 'x', 'preMfaToken': 'token'}),
        throwsFormatException,
      );
    });
  });

  group('MfaEnrollResult.fromJson', () {
    test('parses secreto and otpauthUri', () {
      final result = MfaEnrollResult.fromJson({
        'mensaje': 'Escanea el codigo QR con tu aplicacion de autenticacion.',
        'secreto': 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
        'otpauthUri':
            'otpauth://totp/Prestamesta:juan%40example.com?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=Prestamesta',
      });

      expect(result.secreto, 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP');
      expect(result.otpauthUri, startsWith('otpauth://totp/'));
    });

    test('throws FormatException when secreto is missing', () {
      expect(
        () => MfaEnrollResult.fromJson(
            {'mensaje': 'x', 'otpauthUri': 'otpauth://totp/x'}),
        throwsFormatException,
      );
    });

    test('throws FormatException when otpauthUri is missing', () {
      expect(
        () => MfaEnrollResult.fromJson({'mensaje': 'x', 'secreto': 'ABC'}),
        throwsFormatException,
      );
    });
  });

  group('MfaEnrollConfirmRequest.toJson', () {
    test('serializes exactly codigo', () {
      const request = MfaEnrollConfirmRequest(codigo: '123456');
      expect(request.toJson(), {'codigo': '123456'});
    });
  });

  group('MfaVerifyRequest.toJson', () {
    test('totp() sends exactly codigo, never codigoRecuperacion', () {
      const request = MfaVerifyRequest.totp('123456');
      final json = request.toJson();
      expect(json, {'codigo': '123456'});
      expect(json.containsKey('codigoRecuperacion'), isFalse);
    });

    test('recoveryCode() sends exactly codigoRecuperacion, never codigo', () {
      const request = MfaVerifyRequest.recoveryCode('A1B2-C3D4-E5F6-0708-090A');
      final json = request.toJson();
      expect(json, {'codigoRecuperacion': 'A1B2-C3D4-E5F6-0708-090A'});
      expect(json.containsKey('codigo'), isFalse);
    });
  });

  group('MfaSessionResult.fromJson', () {
    test('parses token, cliente and codigosRecuperacion (enroll/confirm shape)',
        () {
      final result = MfaSessionResult.fromJson({
        'mensaje': 'Autenticacion exitosa.',
        'token': 'eyJhbGciOiJIUzI1NiJ9.session.sig',
        'cliente': {
          'id': 1,
          'nombre': 'Juan Pérez',
          'email': 'juan@example.com'
        },
        'codigosRecuperacion': List.generate(10, (i) => 'CODE-$i'),
      });

      expect(result.token, 'eyJhbGciOiJIUzI1NiJ9.session.sig');
      expect(result.cliente.email, 'juan@example.com');
      expect(result.codigosRecuperacion, hasLength(10));
    });

    test(
        'codigosRecuperacion is null (not an empty list) when absent — the '
        'mfa/verify shape', () {
      final result = MfaSessionResult.fromJson({
        'mensaje': 'Autenticacion exitosa.',
        'token': 'eyJhbGciOiJIUzI1NiJ9.session.sig',
        'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
      });

      expect(result.codigosRecuperacion, isNull);
    });

    test('throws FormatException when token is missing', () {
      expect(
        () => MfaSessionResult.fromJson({
          'mensaje': 'x',
          'cliente': {'id': 1, 'nombre': 'Juan', 'email': 'juan@example.com'},
        }),
        throwsFormatException,
      );
    });

    test('throws FormatException when cliente is missing', () {
      expect(
        () => MfaSessionResult.fromJson({'mensaje': 'x', 'token': 'abc'}),
        throwsFormatException,
      );
    });
  });
}
