import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/network/auth_interceptor.dart';

RequestOptions _requestOptions({bool? requiresAuth}) {
  return RequestOptions(
    path: '/prestamos/creditos',
    extra: requiresAuth == null ? {} : {requiresAuthExtraKey: requiresAuth},
  );
}

DioException _unauthorizedError(String? codigo, {int statusCode = 401}) {
  final options = RequestOptions(path: '/prestamos/creditos');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: codigo == null ? null : {'mensaje': 'x', 'codigo': codigo},
    ),
  );
}

void main() {
  group('AuthInterceptor.onRequest', () {
    test(
        'does not attach Authorization when requiresAuth is not set (e.g. login/register)',
        () async {
      var tokenReadCount = 0;
      final interceptor = AuthInterceptor(
        readToken: () async {
          tokenReadCount++;
          return 'a-token';
        },
        onSessionRejected: () {},
      );
      final options = _requestOptions();

      await interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['Authorization'], isNull);
      expect(tokenReadCount, 0);
    });

    test('does not attach Authorization when requiresAuth is explicitly false',
        () async {
      final interceptor = AuthInterceptor(
          readToken: () async => 'a-token', onSessionRejected: () {});
      final options = _requestOptions(requiresAuth: false);

      await interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['Authorization'], isNull);
    });

    test('attaches Bearer token when requiresAuth is true and a token exists',
        () async {
      final interceptor = AuthInterceptor(
        readToken: () async => 'my-jwt',
        onSessionRejected: () {},
      );
      final options = _requestOptions(requiresAuth: true);

      await interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['Authorization'], 'Bearer my-jwt');
    });

    test(
        'sends no Authorization header when requiresAuth is true but there is no session',
        () async {
      final interceptor = AuthInterceptor(
          readToken: () async => null, onSessionRejected: () {});
      final options = _requestOptions(requiresAuth: true);

      await interceptor.onRequest(options, RequestInterceptorHandler());

      expect(options.headers['Authorization'], isNull);
    });
  });

  group('isSessionRejection', () {
    test('is true for 401 TOKEN_EXPIRED', () {
      expect(isSessionRejection(_unauthorizedError('TOKEN_EXPIRED')), isTrue);
    });

    test('is true for 401 TOKEN_INVALID', () {
      expect(isSessionRejection(_unauthorizedError('TOKEN_INVALID')), isTrue);
    });

    test('is false for 401 with an unrelated codigo (e.g. bad login attempt)',
        () {
      expect(isSessionRejection(_unauthorizedError('INVALID_CREDENTIALS')),
          isFalse);
    });

    test('is false for 401 with no parseable body', () {
      expect(isSessionRejection(_unauthorizedError(null)), isFalse);
    });

    test('is false for non-401 status codes', () {
      expect(
          isSessionRejection(
              _unauthorizedError('TOKEN_EXPIRED', statusCode: 403)),
          isFalse);
    });
  });
}
