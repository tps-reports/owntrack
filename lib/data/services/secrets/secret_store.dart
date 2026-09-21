import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Browser policy: secrets exist only in this application session's memory.
/// Reloading or closing the page requires entering credentials again. Browser
/// localStorage is deliberately never used as a substitute for an OS keychain.
abstract interface class SecretStore {
  String? read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SessionSecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Synchronous reads are served only from an initialized keychain cache.
class SecureSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;
  final Map<String, String> _values;

  SecureSecretStore._(this._storage, this._values);

  static Future<SecureSecretStore> open({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) async {
    final values = await storage.readAll();
    return SecureSecretStore._(storage, Map.of(values));
  }

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
    if (await _storage.read(key: key) != value) {
      throw StateError('Secure storage could not verify the saved credential.');
    }
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
    if (await _storage.read(key: key) != null) {
      throw StateError('Secure storage could not remove the credential.');
    }
    _values.remove(key);
  }
}

// A failed bootstrap may already have migrated and removed legacy credentials.
// Retain those secrets for retries within this page's lifetime.
final _browserSessionSecrets = SessionSecretStore();

Future<SecretStore> openPlatformSecretStore() async =>
    kIsWeb ? _browserSessionSecrets : await SecureSecretStore.open();
