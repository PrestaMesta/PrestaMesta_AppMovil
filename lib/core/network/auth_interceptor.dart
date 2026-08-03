import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Dio's `extra` key a call site must set to `true` to have this interceptor
/// attach `Authorization: Bearer <token>`. Left unset (or `false`), no
/// Authorization header is sent — public endpoints like login/register never
/// see one, by construction rather than by remembering not to add it.
const requiresAuthExtraKey = 'requiresAuth';

const _tokenInvalidCodes = {'TOKEN_EXPIRED', 'TOKEN_INVALID'};

/// Attaches the bearer token to requests explicitly marked as authenticated,
/// and reacts to the server rejecting that token.
///
/// Both behaviors are injected as callbacks rather than reaching into a
/// storage singleton, so this interceptor stays unit-testable and ignorant of
/// *how* the token is stored:
/// - [readToken] is called per authenticated request; returning `null` means
///   "no session" and the request is sent without an Authorization header
///   (the server will reply 401, handled like any other unauthenticated call).
/// - [onSessionRejected] is called once when the server responds 401 with
///   `codigo` `TOKEN_EXPIRED` or `TOKEN_INVALID` — the caller is responsible
///   for clearing local session storage; this class never touches storage.
class AuthInterceptor extends Interceptor {
  final Future<String?> Function() readToken;
  final void Function() onSessionRejected;

  AuthInterceptor({required this.readToken, required this.onSessionRejected});

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final requiresAuth = options.extra[requiresAuthExtraKey] == true;
    if (requiresAuth) {
      final token = await readToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isSessionRejection(err)) {
      onSessionRejected();
    }
    handler.next(err);
  }
}

/// True when [error] is the server telling us the bearer token is dead
/// (`401` with `codigo` `TOKEN_EXPIRED` or `TOKEN_INVALID`) — as opposed to
/// any other 401 (e.g. hitting an authenticated route with no token at all)
/// or any other status code. Extracted as a pure function so this decision
/// is testable without going through Dio's interceptor/handler machinery.
bool isSessionRejection(DioException error) {
  final response = error.response;
  if (response?.statusCode != 401) return false;

  final data = response?.data;
  if (data is! Map<String, dynamic>) return false;

  try {
    final codigo = ServerErrorEnvelope.fromJson(data).codigo;
    return codigo != null && _tokenInvalidCodes.contains(codigo);
  } catch (_) {
    return false;
  }
}
