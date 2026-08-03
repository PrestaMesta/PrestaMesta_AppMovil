import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Header and body-field names that must never appear in a log line, matched
/// case-insensitively (and, for body fields, as a substring match so a nested
/// key like `cliente.telefono` or `aval.ingreso_mensual` is still caught).
/// Covers auth material, credentials, and the personal/financial data the
/// client/credits/loan endpoints carry (`nombre`, `email`, `telefono`,
/// `direccion`, `ingreso_mensual`, and anything with `monto` in its name —
/// `monto_solicitado`, `montoTotalAPagar`, etc. — see
/// `ClienteRegistroInput`/`Credito`/`SolicitudPrestamoInput`/`AvalInput` in
/// `PrestaMesta_Server/openapi.yaml`).
const _sensitiveKeys = {
  'authorization',
  'cookie',
  'set-cookie',
  'password',
  'token',
  'jwt',
  'email',
  'nombre',
  'telefono',
  'direccion',
  'ingreso',
  'monto',
};

const _redacted = '***';

/// Logs request/response lines, redacting sensitive headers/body fields
/// first. Real logging only happens when [logsEnabled] is true.
///
/// [logsEnabled] defaults to [kDebugMode] so a production build never logs
/// regardless of `APP_ENV`, but is accepted as a constructor parameter (per
/// the Checkpoint 2 security review) so the "disabled" branch is directly
/// testable instead of being permanently unreachable under `flutter test`
/// (which always runs in debug mode, so `kDebugMode` alone can't be flipped
/// off from a test).
class SanitizingLoggingInterceptor extends Interceptor {
  final void Function(String message) _log;
  final bool logsEnabled;

  SanitizingLoggingInterceptor(
      {void Function(String message)? log, bool? logsEnabled})
      : _log = log ?? debugPrint,
        logsEnabled = logsEnabled ?? kDebugMode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (logsEnabled) {
      _log(
        '--> ${options.method} ${options.uri}\n'
        'headers: ${_redactMap(options.headers)}\n'
        'body: ${_redactBody(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (logsEnabled) {
      _log(
        '<-- ${response.statusCode} ${response.requestOptions.uri}\n'
        'body: ${_redactBody(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (logsEnabled) {
      _log(
        '<-- error ${err.response?.statusCode} ${err.requestOptions.uri}\n'
        'body: ${_redactBody(err.response?.data)}',
      );
    }
    handler.next(err);
  }
}

Map<String, dynamic> _redactMap(Map<String, dynamic> source) {
  return source.map((key, value) {
    if (_sensitiveKeys.contains(key.toLowerCase())) {
      return MapEntry(key, _redacted);
    }
    return MapEntry(key, value);
  });
}

dynamic _redactBody(dynamic data) {
  if (data is Map) {
    return data.map((key, value) {
      final k = key.toString();
      if (_sensitiveKeys
          .any((sensitive) => k.toLowerCase().contains(sensitive))) {
        return MapEntry(k, _redacted);
      }
      if (value is Map || value is List) {
        return MapEntry(k, _redactBody(value));
      }
      return MapEntry(k, value);
    });
  }
  if (data is List) {
    return data.map(_redactBody).toList(growable: false);
  }
  return data;
}
