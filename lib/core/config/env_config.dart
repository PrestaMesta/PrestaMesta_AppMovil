import 'app_environment.dart';

/// Centralized, validated runtime configuration. Values come only from
/// `--dart-define` (never hardcoded, never committed) so the same APK build
/// process can target local/testing/production without touching source.
///
/// Build with [EnvConfig.fromDartDefines], not the constructor directly, so
/// every field is validated together (see the invariants enforced there).
class EnvConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;

  const EnvConfig._({required this.environment, required this.apiBaseUrl});

  static const _rawAppEnv = String.fromEnvironment('APP_ENV', defaultValue: '');
  static const _rawApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Validates and builds the config from the compiled-in `--dart-define`
  /// values. Throws [ConfigError] — never returns a half-valid config — when:
  /// - APP_ENV is missing or not one of local/testing/production;
  /// - API_BASE_URL is missing or not a valid absolute http(s) URL;
  /// - environment is `production` and the URL scheme isn't `https`.
  factory EnvConfig.fromDartDefines() {
    return EnvConfig.parse(
        appEnvRaw: _rawAppEnv, apiBaseUrlRaw: _rawApiBaseUrl);
  }

  /// Same validation as [fromDartDefines], exposed with explicit inputs so
  /// tests can exercise every branch without recompiling with dart-defines.
  factory EnvConfig.parse(
      {required String appEnvRaw, required String apiBaseUrlRaw}) {
    if (appEnvRaw.isEmpty) {
      throw ConfigError(
        'APP_ENV no fue definido. Ejecuta con --dart-define=APP_ENV=local|testing|production.',
      );
    }
    final environment = AppEnvironment.parse(appEnvRaw);

    if (apiBaseUrlRaw.isEmpty) {
      throw ConfigError(
        'API_BASE_URL no fue definido. Ejecuta con --dart-define=API_BASE_URL=<url>.',
      );
    }

    final uri = Uri.tryParse(apiBaseUrlRaw);
    if (uri == null ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ConfigError(
          'API_BASE_URL no es una URL http(s) válida: "$apiBaseUrlRaw".');
    }

    // Only `local` (the Android emulator talking to a dev machine over
    // http://10.0.2.2) may use plain HTTP. Both `testing` and `production`
    // point at real, network-reachable servers and must use HTTPS.
    if (environment != AppEnvironment.local && uri.scheme != 'https') {
      throw ConfigError(
        'APP_ENV=$appEnvRaw requiere API_BASE_URL con esquema https. '
        'Recibido: "$apiBaseUrlRaw".',
      );
    }

    return EnvConfig._(environment: environment, apiBaseUrl: apiBaseUrlRaw);
  }

  bool get isProduction => environment == AppEnvironment.production;

  @override
  String toString() =>
      'EnvConfig(environment: $environment, apiBaseUrl: $apiBaseUrl)';
}
