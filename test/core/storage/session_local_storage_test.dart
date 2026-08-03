import 'package:flutter_test/flutter_test.dart';
import 'package:prestamesta_app/core/storage/secure_storage.dart';
import 'package:prestamesta_app/core/storage/session_local_storage.dart';

/// In-memory double: never touches the platform's real secure storage
/// (Android Keystore/EncryptedSharedPreferences), so these tests run
/// anywhere without a device/emulator.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  bool containsKey(String key) => _values.containsKey(key);
}

void main() {
  late FakeSecureStorage fakeStorage;
  late SessionLocalStorage session;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    session = SessionLocalStorage(fakeStorage);
  });

  test('readToken/readCliente return null before any session is saved',
      () async {
    expect(await session.readToken(), isNull);
    expect(await session.readCliente(), isNull);
  });

  test('saveSession persists token and cliente under separate storage entries',
      () async {
    await session.saveSession(
      token: 'jwt-abc',
      cliente: const ClienteSummary(
          id: 1, nombre: 'Juan Pérez', email: 'juan@example.com'),
    );

    expect(await session.readToken(), 'jwt-abc');
    final cliente = await session.readCliente();
    expect(cliente!.id, 1);
    expect(cliente.nombre, 'Juan Pérez');
    expect(cliente.email, 'juan@example.com');

    // Token and profile must live under different keys, never bundled into
    // one entry that would carry the secret alongside display-only data.
    final tokenKeys = fakeStorage._values.keys
        .where((k) => fakeStorage._values[k] == 'jwt-abc');
    expect(tokenKeys, hasLength(1));
  });

  test('clear wipes both the token and the cliente profile', () async {
    await session.saveSession(
      token: 'jwt-abc',
      cliente: const ClienteSummary(
          id: 1, nombre: 'Juan', email: 'juan@example.com'),
    );

    await session.clear();

    expect(await session.readToken(), isNull);
    expect(await session.readCliente(), isNull);
    expect(fakeStorage._values, isEmpty);
  });

  test(
      'readCliente returns null (not a crash) if the stored value is corrupted',
      () async {
    // Simulates a corrupted/unexpected value ending up in secure storage.
    await fakeStorage.write('session_cliente', 'not-json');

    expect(await session.readCliente(), isNull);
  });
}
