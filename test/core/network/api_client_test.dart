import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/config/env_config.dart';
import 'package:prestamesta_app/core/network/api_client.dart';
import 'package:prestamesta_app/core/network/auth_interceptor.dart';
import 'package:prestamesta_app/core/network/logging_interceptor.dart';

void main() {
  test(
      'ApiClient.create wires baseUrl/headers and only the auth+logging interceptors',
      () {
    final config = EnvConfig.parse(
        appEnvRaw: 'local', apiBaseUrlRaw: 'http://10.0.2.2:3000');

    final client = ApiClient.create(
      config: config,
      readToken: () async => null,
      onSessionRejected: () {},
    );

    expect(client.dio.options.baseUrl, 'http://10.0.2.2:3000/api/v1');
    expect(client.dio.options.headers['Accept'], 'application/json');

    expect(client.dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
    expect(client.dio.interceptors.whereType<SanitizingLoggingInterceptor>(),
        hasLength(1));

    // No retry interceptor of any kind (Dio's own default
    // ImplyContentTypeInterceptor is expected and harmless): a POST
    // (login/loan request) must never be replayed automatically by the HTTP
    // layer.
    final hasRetryInterceptor = client.dio.interceptors.any(
      (i) => i.runtimeType.toString().toLowerCase().contains('retry'),
    );
    expect(hasRetryInterceptor, isFalse);
  });

  test('appends /api/v1 exactly once even if API_BASE_URL has a trailing slash',
      () {
    final config = EnvConfig.parse(
        appEnvRaw: 'testing',
        apiBaseUrlRaw: 'https://apitest.prestamesta.fun/');

    final client = ApiClient.create(
      config: config,
      readToken: () async => null,
      onSessionRejected: () {},
    );

    expect(
        client.dio.options.baseUrl, 'https://apitest.prestamesta.fun/api/v1');
  });

  test(
      'a real deployed domain gets the exact route confirmed against the '
      'server (PrestaMesta_Server/app.js mounts everything under /api/v1)', () {
    final config = EnvConfig.parse(
        appEnvRaw: 'testing', apiBaseUrlRaw: 'https://apitest.prestamesta.fun');

    final client = ApiClient.create(
      config: config,
      readToken: () async => null,
      onSessionRejected: () {},
    );

    expect(
        client.dio.options.baseUrl, 'https://apitest.prestamesta.fun/api/v1');
  });
}
