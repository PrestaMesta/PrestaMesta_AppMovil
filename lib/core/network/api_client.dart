import 'package:dio/dio.dart';

import '../config/env_config.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';

const _connectTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 20);

/// Builds the single [Dio] instance the app uses to talk to
/// `PrestaMesta_Server`. Centralizing this means every call gets the same
/// base URL, timeouts, headers, auth handling and sanitized logging without
/// each repository re-deriving it.
///
/// Deliberately does **not** register any retry interceptor: a POST that
/// creates a loan or an auth attempt must never be retried automatically by
/// the HTTP layer — a timed-out request whose write actually succeeded on the
/// server must not be replayed blindly. Callers decide retries, if any, only
/// for safe (GET) operations.
class ApiClient {
  final Dio dio;

  ApiClient._(this.dio);

  factory ApiClient.create({
    required EnvConfig config,
    required Future<String?> Function() readToken,
    required void Function() onSessionRejected,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );

    dio.interceptors.add(AuthInterceptor(
        readToken: readToken, onSessionRejected: onSessionRejected));
    dio.interceptors.add(SanitizingLoggingInterceptor());

    return ApiClient._(dio);
  }
}
