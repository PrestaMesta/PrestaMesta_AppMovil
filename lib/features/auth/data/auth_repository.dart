import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/error_mapper.dart';
import 'auth_models.dart';
import 'mfa_models.dart';

const _invalidResponseException = AppException(
  type: AppExceptionType.respuestaInvalida,
  mensaje: 'El servidor respondió de forma inesperada. Intenta de nuevo.',
);

/// Talks to the client-auth endpoints: the two public ones
/// (`register`/`login`) and the three MFA ones that only accept a
/// `preMfaToken` (`mfaEnroll`/`mfaEnrollConfirm`/`mfaVerify`).
///
/// The MFA calls deliberately **never** set `requiresAuthExtraKey` (see
/// `core/network/auth_interceptor.dart`) — that mechanism reads the *session*
/// token from `SessionLocalStorage`, and a `preMfaToken` is never that. Each
/// MFA method takes its `preMfaToken` as an explicit parameter and attaches
/// it as `Authorization: Bearer <preMfaToken>` on that one request only, so
/// it can never be confused with — or accidentally reused as — the session
/// bearer token, and it never touches secure storage.
///
/// Every failure surfaces as an [AppException] (never a raw [DioException])
/// via `mapDioExceptionToAppException` — callers (the auth/MFA controllers)
/// only ever need to handle that one type.
class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<RegisterResult> register(RegisterRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/client/auth/register',
        data: request.toJson(),
      );
      return RegisterResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }

  Future<LoginPreMfaResult> login(LoginRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/client/auth/login',
        data: request.toJson(),
      );
      return LoginPreMfaResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }

  Future<MfaEnrollResult> mfaEnroll(String preMfaToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/client/auth/mfa/enroll',
        options: _preMfaAuth(preMfaToken),
      );
      return MfaEnrollResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }

  Future<MfaSessionResult> mfaEnrollConfirm(
      String preMfaToken, MfaEnrollConfirmRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/client/auth/mfa/enroll/confirm',
        data: request.toJson(),
        options: _preMfaAuth(preMfaToken),
      );
      return MfaSessionResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }

  Future<MfaSessionResult> mfaVerify(
      String preMfaToken, MfaVerifyRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/client/auth/mfa/verify',
        data: request.toJson(),
        options: _preMfaAuth(preMfaToken),
      );
      return MfaSessionResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }

  Options _preMfaAuth(String preMfaToken) =>
      Options(headers: {'Authorization': 'Bearer $preMfaToken'});
}
