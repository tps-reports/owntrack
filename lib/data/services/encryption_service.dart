import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';

/// Encryption service for OwnTracks messages
///
/// Uses ChaCha20-Poly1305 AEAD encryption compatible with libsodium.
/// Messages are encrypted with a shared secret key.
class EncryptionService {
  final SettingsRepository _settingsRepository;
  final _algorithm = Chacha20.poly1305Aead();

  EncryptionService(this._settingsRepository);

  /// Check if encryption is enabled
  bool get isEnabled {
    final key = _settingsRepository.getEncryptionKey();
    return key.isNotEmpty;
  }

  /// Encrypt a JSON message
  ///
  /// Returns base64-encoded encrypted data, or null if encryption fails
  Future<String?> encrypt(String jsonPayload) async {
    if (!isEnabled) {
      AppLogger.d('Encryption not enabled, returning plain payload');
      return jsonPayload;
    }

    try {
      final key = _settingsRepository.getEncryptionKey();
      final secretKey = await _deriveKey(key);

      // Generate random nonce (12 bytes for ChaCha20-Poly1305)
      final nonce = _algorithm.newNonce();

      // Encrypt the payload
      final plaintext = utf8.encode(jsonPayload);
      final secretBox = await _algorithm.encrypt(
        plaintext,
        secretKey: secretKey,
        nonce: nonce,
      );

      // Combine nonce + ciphertext + mac for storage
      final combined = Uint8List.fromList([
        ...nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]);

      final encoded = base64.encode(combined);
      AppLogger.d('Message encrypted successfully');
      return encoded;
    } catch (e) {
      AppLogger.e('Encryption error: $e');
      return null;
    }
  }

  /// Decrypt a base64-encoded encrypted message
  ///
  /// Returns decrypted JSON string, or null if decryption fails
  Future<String?> decrypt(String encryptedData) async {
    if (!isEnabled) {
      AppLogger.d('Encryption not enabled, returning plain payload');
      return encryptedData;
    }

    try {
      final key = _settingsRepository.getEncryptionKey();
      final secretKey = await _deriveKey(key);

      // Decode from base64
      final combined = base64.decode(encryptedData);

      // Extract nonce (12 bytes), ciphertext, and MAC (16 bytes)
      final nonce = combined.sublist(0, 12);
      final mac = Mac(combined.sublist(combined.length - 16));
      final cipherText = combined.sublist(12, combined.length - 16);

      // Decrypt
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: mac,
      );

      final plaintext = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final decrypted = utf8.decode(plaintext);
      AppLogger.d('Message decrypted successfully');
      return decrypted;
    } catch (e) {
      AppLogger.e('Decryption error: $e');
      return null;
    }
  }

  /// Derive a 256-bit key from the user's encryption key string
  Future<SecretKey> _deriveKey(String keyString) async {
    // Use SHA-256 to create a consistent 32-byte key from the user's string
    final sha256 = Sha256();
    final hash = await sha256.hash(utf8.encode(keyString));
    return SecretKey(hash.bytes);
  }

  /// Encrypt a message and wrap it in OwnTracks encrypted format
  ///
  /// Returns a JSON object with _type: "encrypted" and data field
  Future<Map<String, dynamic>?> encryptMessage(Map<String, dynamic> message) async {
    final jsonString = json.encode(message);
    final encrypted = await encrypt(jsonString);

    if (encrypted == null) {
      return null;
    }

    return {
      '_type': 'encrypted',
      'data': encrypted,
    };
  }

  /// Decrypt an OwnTracks encrypted message
  ///
  /// Expects a JSON object with _type: "encrypted" and data field
  Future<Map<String, dynamic>?> decryptMessage(Map<String, dynamic> encryptedMessage) async {
    if (encryptedMessage['_type'] != 'encrypted') {
      // Not an encrypted message, return as-is
      return encryptedMessage;
    }

    final encryptedData = encryptedMessage['data'] as String?;
    if (encryptedData == null) {
      AppLogger.e('Encrypted message missing data field');
      return null;
    }

    final decrypted = await decrypt(encryptedData);
    if (decrypted == null) {
      return null;
    }

    try {
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.e('Error parsing decrypted JSON: $e');
      return null;
    }
  }
}
