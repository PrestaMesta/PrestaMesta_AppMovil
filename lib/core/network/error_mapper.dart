import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Converts a [DioException] into the fixed set of [AppException]s the rest
/// of the app is allowed to react to. This is the single place that decides
/// what a failed HTTP call means — screens and repositories must not
/// interpret [DioException]/status codes themselves.
AppException mapDioExceptionToAppException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionError:
      return const AppException(
        type: AppExceptionType.sinConexion,
        mensaje:
            'No hay conexión a internet. Verifica tu conexión e intenta de nuevo.',
      );
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const AppException(
        type: AppExceptionType.tiempoAgotado,
        mensaje: 'La solicitud tardó demasiado. Intenta de nuevo.',
      );
    case DioExceptionType.badCertificate:
      return const AppException(
        type: AppExceptionType.sinConexion,
        mensaje: 'No se pudo establecer una conexión segura con el servidor.',
      );
    case DioExceptionType.cancel:
      return const AppException(
        type: AppExceptionType.desconocido,
        mensaje: 'La solicitud fue cancelada.',
      );
    case DioExceptionType.badResponse:
      return _mapBadResponse(error);
    case DioExceptionType.unknown:
      return const AppException(
        type: AppExceptionType.sinConexion,
        mensaje:
            'No hay conexión a internet. Verifica tu conexión e intenta de nuevo.',
      );
  }
}

AppException _mapBadResponse(DioException error) {
  final statusCode = error.response?.statusCode;
  final envelope = _tryParseEnvelope(error.response?.data);

  final mensaje = envelope?.mensaje ?? _defaultMessageFor(statusCode);
  final codigo = envelope?.codigo;
  final requestId = envelope?.requestId;
  final detalles = envelope?.detalles ?? const [];

  final type = switch (statusCode) {
    400 => AppExceptionType.validacion,
    401 => AppExceptionType.noAutenticado,
    403 => AppExceptionType.prohibido,
    404 => AppExceptionType.noEncontrado,
    409 => AppExceptionType.conflicto,
    429 => AppExceptionType.demasiadasSolicitudes,
    int() when statusCode >= 500 => AppExceptionType.errorServidor,
    _ => AppExceptionType.desconocido,
  };

  return AppException(
    type: type,
    mensaje: mensaje,
    codigo: codigo,
    requestId: requestId,
    statusCode: statusCode,
    detalles: detalles,
  );
}

ServerErrorEnvelope? _tryParseEnvelope(dynamic data) {
  if (data is Map<String, dynamic>) {
    try {
      return ServerErrorEnvelope.fromJson(data);
    } catch (_) {
      return null;
    }
  }
  return null;
}

String _defaultMessageFor(int? statusCode) {
  switch (statusCode) {
    case 400:
      return 'Los datos enviados no son válidos.';
    case 401:
      return 'Tu sesión no es válida. Inicia sesión de nuevo.';
    case 403:
      return 'No tienes permiso para realizar esta acción.';
    case 404:
      return 'No se encontró el recurso solicitado.';
    case 409:
      return 'La operación no se puede completar en el estado actual.';
    case 429:
      return 'Demasiadas solicitudes. Intenta de nuevo más tarde.';
    default:
      if (statusCode != null && statusCode >= 500) {
        return 'Ocurrió un error en el servidor. Intenta de nuevo más tarde.';
      }
      return 'Ocurrió un error inesperado.';
  }
}
