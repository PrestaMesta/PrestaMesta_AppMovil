import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin key-value contract over secure, encrypted device storage. Kept as an
/// interface (rather than importing `FlutterSecureStorage` directly wherever
/// it's needed) so tests can supply an in-memory fake that never touches the
/// real Android Keystore/EncryptedSharedPreferences.
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageImpl({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
