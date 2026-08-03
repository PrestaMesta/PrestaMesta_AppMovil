import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/config/app_environment.dart';
import 'package:prestamesta_app/core/config/env_config.dart';

void main() {
  group('EnvConfig.parse', () {
    test('throws when APP_ENV is missing', () {
      expect(
        () => EnvConfig.parse(
            appEnvRaw: '', apiBaseUrlRaw: 'http://10.0.2.2:3000'),
        throwsA(isA<ConfigError>()),
      );
    });

    test('throws when APP_ENV is not one of the known values', () {
      expect(
        () => EnvConfig.parse(
            appEnvRaw: 'staging', apiBaseUrlRaw: 'http://10.0.2.2:3000'),
        throwsA(isA<ConfigError>()),
      );
    });

    test('throws when API_BASE_URL is missing', () {
      expect(
        () => EnvConfig.parse(appEnvRaw: 'local', apiBaseUrlRaw: ''),
        throwsA(isA<ConfigError>()),
      );
    });

    test('throws when API_BASE_URL is not a valid absolute http(s) URL', () {
      expect(
        () => EnvConfig.parse(appEnvRaw: 'local', apiBaseUrlRaw: 'not-a-url'),
        throwsA(isA<ConfigError>()),
      );
      expect(
        () => EnvConfig.parse(
            appEnvRaw: 'local', apiBaseUrlRaw: 'ftp://10.0.2.2:3000'),
        throwsA(isA<ConfigError>()),
      );
    });

    // Only `local` may use plain HTTP (the Android emulator reaching a dev
    // machine at 10.0.2.2); `testing` and `production` both point at real,
    // network-reachable servers and must use HTTPS.
    group('scheme requirements per environment', () {
      test('local + http: allowed', () {
        final config = EnvConfig.parse(
          appEnvRaw: 'local',
          apiBaseUrlRaw: 'http://10.0.2.2:3000',
        );
        expect(config.environment, AppEnvironment.local);
        expect(config.apiBaseUrl, 'http://10.0.2.2:3000');
      });

      test('local + https: allowed', () {
        final config = EnvConfig.parse(
          appEnvRaw: 'local',
          apiBaseUrlRaw: 'https://10.0.2.2:3000',
        );
        expect(config.environment, AppEnvironment.local);
      });

      test('testing + http: rejected', () {
        expect(
          () => EnvConfig.parse(
            appEnvRaw: 'testing',
            apiBaseUrlRaw: 'http://testing-api.prestamesta.com',
          ),
          throwsA(isA<ConfigError>()),
        );
      });

      test('testing + https: allowed', () {
        final config = EnvConfig.parse(
          appEnvRaw: 'testing',
          apiBaseUrlRaw: 'https://testing-api.prestamesta.com',
        );
        expect(config.environment, AppEnvironment.testing);
        expect(config.isProduction, isFalse);
      });

      test('production + http: rejected', () {
        expect(
          () => EnvConfig.parse(
            appEnvRaw: 'production',
            apiBaseUrlRaw: 'http://api.prestamesta.com',
          ),
          throwsA(isA<ConfigError>()),
        );
      });

      test('production + https: allowed', () {
        final config = EnvConfig.parse(
          appEnvRaw: 'production',
          apiBaseUrlRaw: 'https://api.prestamesta.com',
        );
        expect(config.environment, AppEnvironment.production);
        expect(config.isProduction, isTrue);
        expect(config.apiBaseUrl, 'https://api.prestamesta.com');
      });
    });
  });
}
