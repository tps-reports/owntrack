@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const port = int.fromEnvironment('MQTT_TLS_TEST_PORT');
  const certificatePath = String.fromEnvironment('MQTT_TLS_TEST_CA_FILE');
  const username = String.fromEnvironment('MQTT_TLS_TEST_USERNAME');
  const password = String.fromEnvironment('MQTT_TLS_TEST_PASSWORD');
  const serverCertificatePath = String.fromEnvironment(
    'MQTT_TLS_TEST_SERVER_CERT_FILE',
  );
  const serverKeyPath = String.fromEnvironment('MQTT_TLS_TEST_SERVER_KEY_FILE');

  test(
    'real MQTT TLS rejects untrusted issuers, invalid credentials and wrong '
    'hostnames while trusted authenticated delivery survives reconnect',
    () async {
      expect(certificatePath, isNotEmpty);
      expect(username, isNotEmpty);
      expect(password, isNotEmpty);
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        SettingsLocalDataSource(await SharedPreferences.getInstance()),
      );
      await settings.setMqttHost('localhost');
      await settings.setMqttPort(port);
      await settings.setMqttUseTls(true);
      await settings.setMqttClientId('owntrack-native-tls-integration');
      await settings.setMqttUsername(username);
      await settings.setMqttPassword(password);
      final state = EndpointStateRepository();
      final service = MqttService(settings, state);

      Future<void> exchange(int sequence) async {
        const topic = 'owntracks/integration/native-tls';
        service.subscribe(topic);
        final received = service.messages.first.timeout(
          const Duration(seconds: 5),
        );
        final payload = jsonEncode({
          '_type': 'location',
          'lat': 1,
          'lon': 2,
          'tst': sequence,
        });
        final results = await Future.wait<Object>([
          service.publish(topic, payload),
          received,
        ]);
        expect(results.first, isTrue, reason: 'QoS 1 broker acknowledgement');
        final message = results.last as ({String topic, String payload});
        expect(message.topic, topic);
        expect(jsonDecode(message.payload), jsonDecode(payload));
      }

      try {
        // Run before adding the fixture CA: this must use ordinary production
        // trust validation, with no bad-certificate callback or injected client.
        expect(
          await service.connect(),
          isFalse,
          reason: 'The ephemeral issuer is not trusted by the application.',
        );
        expect(service.isConnected, isFalse);
        expect(state.state, EndpointState.error);

        // Dart documents that defaultContext belongs to this isolate. Adding a
        // fixture CA here does not change the host trust store or app defaults.
        SecurityContext.defaultContext.setTrustedCertificatesBytes(
          await File(certificatePath).readAsBytes(),
        );
        expect(await service.connect(), isTrue);
        expect(state.state, EndpointState.connected);
        await exchange(1);

        await service.disconnect();
        expect(service.isConnected, isFalse);
        expect(await service.connect(), isTrue);
        await exchange(2);

        await service.disconnect();
        await settings.setMqttPassword('$password-invalid');
        expect(
          await service.connect(),
          isFalse,
          reason: 'TLS trust must not bypass broker authentication.',
        );
        expect(service.isConnected, isFalse);
        expect(state.state, EndpointState.error);

        await settings.setMqttPassword(password);
        await settings.setMqttHost('127.0.0.1');
        expect(
          await service.connect(),
          isFalse,
          reason: 'The certificate has DNS:localhost, not an IP address SAN.',
        );
        expect(service.isConnected, isFalse);
        expect(state.state, EndpointState.error);

        // Prove rejection did not merely result from a dead broker and that a
        // failed authentication/handshake leaves this service reconnectable.
        await settings.setMqttHost('localhost');
        expect(await service.connect(), isTrue);
        await exchange(3);
      } finally {
        await service.disconnect();
        service.dispose();
        state.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: port == 0 ? 'Run bash tool/verify_mqtt_tls.sh' : false,
  );

  test(
    'a real TLS handshake completed after the service deadline closes its '
    'abandoned socket',
    () async {
      expect(serverCertificatePath, isNotEmpty);
      expect(serverKeyPath, isNotEmpty);
      final serverContext = SecurityContext()
        ..useCertificateChain(serverCertificatePath)
        ..usePrivateKey(serverKeyPath);
      SecurityContext.defaultContext.setTrustedCertificatesBytes(
        await File(certificatePath).readAsBytes(),
      );
      final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = Completer<Socket>();
      final acceptSubscription = listener.listen(
        accepted.complete,
        onError: accepted.completeError,
      );
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        SettingsLocalDataSource(await SharedPreferences.getInstance()),
      );
      await settings.setMqttHost('localhost');
      await settings.setMqttPort(listener.port);
      await settings.setMqttUseTls(true);
      await settings.setMqttClientId('owntrack-native-late-tls-integration');
      final state = EndpointStateRepository();
      final service = MqttService(settings, state);
      Socket? rawSocket;
      SecureSocket? secureSocket;
      StreamSubscription<List<int>>? secureSubscription;

      try {
        final connecting = service.connect();
        rawSocket = await accepted.future.timeout(const Duration(seconds: 5));
        // Keep the TCP connection open without answering the TLS ClientHello.
        // This must exercise the service's real fifteen-second deadline.
        expect(await connecting, isFalse);
        expect(state.state, EndpointState.error);
        expect(service.isConnected, isFalse);

        // The socket did not exist in mqtt_client when disconnect was called.
        // Complete that same handshake only after the service has abandoned it.
        secureSocket = await SecureSocket.secureServer(
          rawSocket,
          serverContext,
        ).timeout(const Duration(seconds: 5));
        rawSocket = null;
        final peerClosed = Completer<void>();
        final applicationBytes = <int>[];
        secureSubscription = secureSocket.listen(
          applicationBytes.addAll,
          onError: peerClosed.completeError,
          onDone: peerClosed.complete,
        );
        // The disconnected handler suppresses CONNECT and finishes its existing
        // ten-second CONNACK wait. Its owner must then close the late socket.
        await peerClosed.future.timeout(const Duration(seconds: 12));
        expect(applicationBytes, isEmpty);
        expect(state.state, EndpointState.error);
        expect(service.isConnected, isFalse);
      } finally {
        await service.disconnect();
        service.dispose();
        state.dispose();
        await secureSubscription?.cancel();
        secureSocket?.destroy();
        rawSocket?.destroy();
        await acceptSubscription.cancel();
        await listener.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 1)),
    skip: port == 0 ? 'Run bash tool/verify_mqtt_tls.sh' : false,
  );
}
