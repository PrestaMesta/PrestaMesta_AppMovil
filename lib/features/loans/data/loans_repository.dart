import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/error_mapper.dart';
import 'loan_request.dart';
import 'loan_submission_response.dart';

/// Thrown instead of [AppException] when a `POST /prestamos/solicitar`
/// failed in a way that does **not** rule out the server having received
/// and processed it. The backend has no idempotency support (no
/// `Idempotency-Key`, no dedupe) — this exception exists so the caller can
/// refuse to guess, not so it can pretend to fix the underlying gap.
///
/// [requestId] is populated only in the rare case a partial response body
/// was actually decoded (e.g. a proxy-generated error page that happens to
/// carry the app's envelope); for a genuine timeout/connection loss there is
/// no response at all, so it stays `null` — the server never got a chance to
/// hand back a `requestId` for a request it may or may not have seen.
class LoanSubmissionAmbiguousException implements Exception {
  final String? requestId;
  const LoanSubmissionAmbiguousException({this.requestId});
}

const _invalidResponseException = AppException(
  type: AppExceptionType.respuestaInvalida,
  mensaje: 'El servidor respondió de forma inesperada. Intenta de nuevo.',
);

/// Whether a failed `DioException` proves the request never reached (or was
/// never processed by) the server, or whether that's genuinely unknown.
///
/// The bar for "definite" is deliberately high: it requires *proof* that no
/// request bytes ever left the client for the server to act on, not merely
/// "probably didn't." Only two cases clear that bar:
/// - [DioExceptionType.connectionTimeout]: the TCP handshake itself never
///   completed — nothing was ever written to the wire.
/// - [DioExceptionType.badCertificate]: the TLS handshake failed — the HTTP
///   request was never sent, because there was no secure channel to send it
///   on yet.
///
/// Everything else is ambiguous, including:
/// - `sendTimeout` (the request body may have partially or fully reached the
///   server before the client gave up waiting).
/// - `receiveTimeout` (the request was very likely fully sent — the client
///   is waiting for a response that just hasn't arrived — the server may
///   already be processing or have finished processing it).
/// - `connectionError` (a socket reset/dropped connection can happen at any
///   point, including after the server received and processed the request).
/// - `unknown` (no specific information to rule anything out).
/// - `transformTimeout` (a response was almost certainly already received
///   from the server — the request/response cycle completed — decoding it
///   locally just timed out; the loan may well already exist).
/// - **`cancel`**: deliberately *not* treated as a definite local-only
///   failure. A `CancelToken` can fire at any point — before the connection
///   opens, mid-send, or while waiting for the response — and Dio's
///   `DioException` for `cancel` carries no information about how much (if
///   any) of the request had already reached the server when it fired. This
///   app has no mechanism that proves a cancellation happened strictly
///   pre-send, so every `cancel` is treated as ambiguous. (In practice this
///   app never cancels a loan submission at all today — there's no
///   `CancelToken` wired into [LoansRepository.submit] — so this case mostly
///   guards against a future change accidentally reintroducing one without
///   revisiting this reasoning.)
///
/// [badResponse] (we got a real HTTP response, definitely not ambiguous) is
/// never actually consulted here in practice — see this function's caller in
/// [LoansRepository.submit], which only calls it when `error.response ==
/// null`. It stays in the switch for exhaustiveness, not because it's
/// expected to be hit.
bool _isAmbiguousFailure(DioExceptionType type) {
  switch (type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.badCertificate:
      return false;
    case DioExceptionType.badResponse:
      return false;
    case DioExceptionType.cancel:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
    case DioExceptionType.transformTimeout:
      return true;
  }
}

/// The only thing that calls `POST /prestamos/solicitar`. No retry, no
/// idempotency key (the server doesn't support one — see
/// [LoanSubmissionAmbiguousException]), no fallback data. Marks the request
/// as authenticated via [requiresAuthExtraKey] — never builds the
/// `Authorization` header itself.
class LoansRepository {
  final Dio _dio;

  LoansRepository(this._dio);

  /// Throws [LoanSubmissionAmbiguousException] when the outcome is unknown,
  /// or [AppException] for every other (definite) failure.
  Future<LoanSubmissionResponse> submit(LoanRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/prestamos/solicitar',
        data: request.toJson(),
        options: Options(extra: const {requiresAuthExtraKey: true}),
      );
      return LoanSubmissionResponse.fromJson(response.data!);
    } on DioException catch (error) {
      if (error.response == null && _isAmbiguousFailure(error.type)) {
        throw LoanSubmissionAmbiguousException(
            requestId: _requestIdFrom(error.response?.data));
      }
      throw mapDioExceptionToAppException(error);
    } on TypeError {
      throw _invalidResponseException;
    } on FormatException {
      throw _invalidResponseException;
    }
  }

  String? _requestIdFrom(dynamic data) {
    if (data is Map<String, dynamic>) {
      final requestId = data['requestId'];
      if (requestId is String) return requestId;
    }
    return null;
  }
}
