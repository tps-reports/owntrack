import 'dart:convert';

import 'package:pinenacl/x25519.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';

/// OwnTracks secretbox: zero-padded UTF-8 key, nonce || MAC || ciphertext.
class EncryptionService {
  final SettingsRepository _settingsRepository;
  EncryptionService(this._settingsRepository);

  bool get isEnabled => _settingsRepository.getEncryptionKey().isNotEmpty;

  SecretBox _box() {
    final bytes = utf8.encode(_settingsRepository.getEncryptionKey());
    if (bytes.isEmpty || bytes.length > 32) {
      throw const FormatException(
        'Encryption key must contain 1 to 32 UTF-8 bytes.',
      );
    }
    return SecretBox(Uint8List(32)..setRange(0, bytes.length, bytes));
  }

  Future<String?> encrypt(String jsonPayload) async {
    if (!isEnabled) return jsonPayload;
    try {
      return base64Encode(
        _box().encrypt(Uint8List.fromList(utf8.encode(jsonPayload))),
      );
    } catch (_) {
      AppLogger.e('Message encryption failed. Check the encryption key.');
      return null;
    }
  }

  Future<String?> decrypt(String encryptedData) async {
    if (!isEnabled) return encryptedData;
    try {
      final bytes = base64Decode(encryptedData);
      if (bytes.length < 40) return null;
      return utf8.decode(_box().decrypt(EncryptedMessage.fromList(bytes)));
    } catch (_) {
      AppLogger.w('Message authentication or decryption failed.');
      return null;
    }
  }

  Future<Map<String, dynamic>?> encryptMessage(
    Map<String, dynamic> message,
  ) async {
    if (!isEnabled) return message;
    final encrypted = await encrypt(jsonEncode(message));
    return encrypted == null ? null : {'_type': 'encrypted', 'data': encrypted};
  }

  Future<Map<String, dynamic>?> decryptMessage(
    Map<String, dynamic> message,
  ) async {
    if (message['_type'] != 'encrypted') return message;
    final data = message['data'];
    if (data is! String || !isEnabled || data.length > 1024 * 1024) return null;
    final decrypted = await decrypt(data);
    if (decrypted == null) return null;
    try {
      final parsed = jsonDecode(decrypted);
      return parsed is Map<String, dynamic> ? parsed : null;
    } on FormatException {
      return null;
    }
  }
}
