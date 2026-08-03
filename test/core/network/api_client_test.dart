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

    expect(client.dio.options.baseUrl, 'http://10.0.2.2:3000');
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
}
