import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:owntrack/bootstrap.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android startup opens and reopens native storage without changing messages',
    (tester) async {
      // Use the real preferences plugin with an isolated, empty namespace.
      // Existing settings and legacy credentials must never migrate in a test.
      SharedPreferences.setPrefix(
        'owntrack_startup_test_${DateTime.now().microsecondsSinceEpoch}.',
      );
      addTearDown(SharedPreferences.resetStatic);

      Future<SecretStore> openSecrets() => SecureSecretStore.open(
        storage: const FlutterSecureStorage(
          aOptions: AndroidOptions(resetOnError: false),
        ),
      );

      Future<List<int>> readSnapshotDigest() async {
        // Deliberately leave outboxStore unspecified: the production native
        // factory must load packaged SQLite and use path_provider on device.
        // No runtime, network service, or queue mutation is started here.
        final dependencies = await initializeApplication(
          openSecrets: openSecrets,
        );
        try {
          final snapshot = jsonEncode(
            dependencies.queue
                .getAllMessages()
                .map((message) => message.toJson())
                .toList(),
          );
          // Compare opaque digests so a failed assertion cannot print queued
          // locations or encrypted payloads from an existing installation.
          return (await Sha256().hash(utf8.encode(snapshot))).bytes;
        } finally {
          await dependencies.queue.close();
        }
      }

      final initial = await readSnapshotDigest();
      expect(await readSnapshotDigest(), orderedEquals(initial));
    },
    skip: !Platform.isAndroid,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
