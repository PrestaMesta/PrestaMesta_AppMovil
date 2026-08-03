/// The three deployment environments this app can be built for, selected via
/// `--dart-define=APP_ENV=...`. Nothing else in the app should branch on a
/// raw string environment name — always go through [AppEnvironment].
enum AppEnvironment {
  local,
  testing,
  production;

  static AppEnvironment parse(String raw) {
    switch (raw) {
      case 'local':
        return AppEnvironment.local;
      case 'testing':
        return AppEnvironment.testing;
      case 'production':
        return AppEnvironment.production;
      default:
        throw ConfigError(
          "APP_ENV inválido: '$raw'. Valores permitidos: local, testing, production.",
        );
    }
  }
}

/// Thrown when the app is launched without a valid, complete `--dart-define`
/// configuration. This is intentionally a hard failure at startup — an app
/// that silently falls back to a guessed backend URL is worse than one that
/// refuses to start.
class ConfigError extends Error {
  final String message;
  ConfigError(this.message);

  @override
  String toString() => 'ConfigError: $message';
}
