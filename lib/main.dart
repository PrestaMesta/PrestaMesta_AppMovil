import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_environment.dart';
import 'core/config/env_config.dart';

void main() {
  // Fail fast and loudly on a bad/missing --dart-define configuration rather
  // than starting with a guessed backend URL — mirrors
  // `PrestaMesta_Server/config/env.js`, which does the same for the backend.
  try {
    EnvConfig.fromDartDefines();
    runApp(const ProviderScope(child: PrestaMestaApp()));
  } on ConfigError catch (error) {
    runApp(_ConfigErrorApp(message: error.message));
  }
}

/// Shown instead of the app when APP_ENV/API_BASE_URL are missing or
/// invalid, so the failure is a readable Spanish message instead of a crash.
class _ConfigErrorApp extends StatelessWidget {
  final String message;
  const _ConfigErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error de configuración',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
