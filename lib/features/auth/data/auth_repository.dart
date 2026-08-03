import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/error_mapper.dart';
import 'auth_models.dart';

const _invalidResponseException = AppException(
  type: AppExceptionType.respuestaInvalida,
  mensaje: 'El servidor respondió de forma inesperada. Intenta de nuevo.',
);

/// Talks to the two public client-auth endpoints. Both calls are public —
/// they never set `requiresAuth` in the request options, so
/// `core/network/auth_interceptor.dart` never attaches an `Authorization`
/// header, even if a stale token happens to still be in storage.
///
/// Every failure surfaces as an [AppException] (never a raw [DioException])
/// via `mapDioExceptionToAppException` — callers (the auth controllers) only
/// ever need to handle that one type.
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

  Future<LoginResult> login(LoginRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/client/auth/login',
        data: request.toJson(),
      );
      return LoginResult.fromJson(response.data!);
    } on DioException catch (error) {
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }
}
