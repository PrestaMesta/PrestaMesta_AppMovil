import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/error_mapper.dart';
import 'credit_model.dart';

const _invalidResponseException = AppException(
  type: AppExceptionType.respuestaInvalida,
  mensaje: 'El servidor respondió de forma inesperada. Intenta de nuevo.',
);

/// The only thing that calls `GET /prestamos/creditos`. The **first real
/// authenticated endpoint** in this app: marks the request with
/// [requiresAuthExtraKey] so `core/network/auth_interceptor.dart` attaches
/// `Authorization: Bearer <token>` — this repository never builds that
/// header itself, and never touches `SecureStorage` directly.
///
/// This endpoint requires auth (client **or** admin token,
/// `verificarTokenClienteOAdmin` — see `routes/prestamoRoutes.js`); it is
/// not public. No retry here, no fallback to `DemoData` on failure — a
/// failure is always surfaced as an [AppException] to the caller.
class CreditsRepository {
  final Dio _dio;

  CreditsRepository(this._dio);

  Future<List<Credito>> fetchCreditos() async {
    try {
      // Requested as `dynamic` (not `List<dynamic>`) so a wrong-shaped body
      // (e.g. an object instead of the documented array) is caught by our
      // own `is! List` check below — as a controlled `respuestaInvalida` —
      // instead of Dio's generic-type enforcement surfacing it as a generic
      // `DioException` that would get misclassified as a connection issue.
      final response = await _dio.get<dynamic>(
        '/prestamos/creditos',
        options: Options(extra: const {requiresAuthExtraKey: true}),
      );
      final data = response.data;
      if (data is! List) {
        throw const FormatException('El catálogo no llegó como una lista.');
      }

      return data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
              'Elemento del catálogo con forma inesperada.');
        }
        return Credito.fromJson(item);
      }).toList(growable: false);
    } on DioException catch (error) {
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }
}
