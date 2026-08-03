import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../core/storage/session_local_storage.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_controller.dart';

/// `main.dart` already validates this once before `runApp` (so a bad
/// `--dart-define` config never gets this far); parsing it again here is
/// side-effect-free and keeps this provider self-contained/overridable in
/// tests, instead of threading a value through `ProviderScope` overrides for
/// every test that needs any provider in this file.
final envConfigProvider =
    Provider<EnvConfig>((ref) => EnvConfig.fromDartDefines());

final secureStorageProvider =
    Provider<SecureStorage>((ref) => FlutterSecureStorageImpl());

final sessionLocalStorageProvider = Provider<SessionLocalStorage>((ref) {
  return SessionLocalStorage(ref.watch(secureStorageProvider));
});

/// The callback wired here is what lets a 401 `TOKEN_EXPIRED`/`TOKEN_INVALID`
/// anywhere in the app clear the session — `ref.read` (not `watch`) because
/// this only needs to *call* the controller when the callback eventually
/// fires, not rebuild the client if the controller's state changes.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final sessionStorage = ref.watch(sessionLocalStorageProvider);
  return ApiClient.create(
    config: ref.watch(envConfigProvider),
    readToken: sessionStorage.readToken,
    onSessionRejected: () =>
        ref.read(authControllerProvider.notifier).sessionRejectedByServer(),
  );
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider).dio);
});
