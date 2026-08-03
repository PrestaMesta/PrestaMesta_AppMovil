/// The server's stable error envelope: `{ mensaje, codigo, requestId, detalles? }`
/// (see `PrestaMesta_Server/utils/AppError.js`). Application logic must branch
/// on [codigo], never on [mensaje] — the message is for display, the code is
/// the contract.
class ServerErrorEnvelope {
  final String mensaje;
  final String? codigo;
  final String? requestId;
  final List<ServerFieldError> detalles;

  const ServerErrorEnvelope({
    required this.mensaje,
    this.codigo,
    this.requestId,
    this.detalles = const [],
  });

  factory ServerErrorEnvelope.fromJson(Map<String, dynamic> json) {
    return ServerErrorEnvelope(
      mensaje: json['mensaje'] as String? ?? 'Ocurrió un error.',
      codigo: json['codigo'] as String?,
      requestId: json['requestId'] as String?,
      detalles: (json['detalles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ServerFieldError.fromJson)
          .toList(growable: false),
    );
  }
}

class ServerFieldError {
  final String? campo;
  final String mensaje;

  const ServerFieldError({this.campo, required this.mensaje});

  factory ServerFieldError.fromJson(Map<String, dynamic> json) {
    return ServerFieldError(
      campo: json['campo'] as String?,
      mensaje: json['mensaje'] as String? ?? '',
    );
  }
}

/// One of a fixed set of failure shapes the UI knows how to react to.
/// Never carries a raw stack trace or driver-level exception text — those are
/// logged (sanitized, dev-only) at the point they're caught, not surfaced.
enum AppExceptionType {
  sinConexion,
  tiempoAgotado,
  respuestaInvalida,
  validacion, // 400
  noAutenticado, // 401
  prohibido, // 403
  noEncontrado, // 404
  conflicto, // 409
  demasiadasSolicitudes, // 429
  errorServidor, // 500
  desconocido,
}

class AppException implements Exception {
  final AppExceptionType type;
  final String mensaje;
  final String? codigo;
  final String? requestId;
  final int? statusCode;
  final List<ServerFieldError> detalles;

  const AppException({
    required this.type,
    required this.mensaje,
    this.codigo,
    this.requestId,
    this.statusCode,
    this.detalles = const [],
  });

  @override
  String toString() =>
      'AppException(type: $type, codigo: $codigo, requestId: $requestId)';
}
