@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/mqtt/client_factory_web.dart';
import 'package:owntrack/data/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fixturePort = int.fromEnvironment('OWNTRACK_WSS_PORT');
const untrustedPort = int.fromEnvironment('OWNTRACK_WSS_UNTRUSTED_PORT');
const fixtureUsername = String.fromEnvironment('OWNTRACK_WSS_USERNAME');
const fixturePassword = String.fromEnvironment('OWNTRACK_WSS_PASSWORD');

class WssFixtureClient {
  final SettingsRepository settings;
  final EndpointStateRepository state;
  final MqttService service;

  WssFixtureClient._(this.settings, this.state, this.service);

  static Future<WssFixtureClient> open(String clientId) async {
    final settings = SettingsRepository(
      SettingsLocalDataSource(await SharedPreferences.getInstance()),
    );
    await settings.setMqttHost('wss://127.0.0.1/mqtt');
    await settings.setMqttPort(fixturePort);
    await settings.setMqttUseTls(true);
    await settings.setMqttClientId(clientId);
    await settings.setMqttUsername(fixtureUsername);
    await settings.setMqttPassword(fixturePassword);
    final state = EndpointStateRepository();
    return WssFixtureClient._(settings, state, MqttService(settings, state));
  }

  Future<void> close() async {
    await service.disconnect();
    service.dispose();
    state.dispose();
  }
}

Future<void> verifyRoundTrip(
  MqttService service,
  String topic,
  int sequence,
) async {
  service.subscribe(topic);
  final messages = StreamIterator(
    service.messages.where((message) => message.topic == topic),
  );
  final payload = jsonEncode({
    '_type': 'location',
    'lat': 1,
    'lon': 2,
    'tst': 100,
    'fixtureSequence': sequence,
  });
  try {
    final delivered = messages.moveNext().timeout(const Duration(seconds: 10));
    final results = await Future.wait([
      delivered,
      service.publish(topic, payload),
    ]);
    expect(
      results,
      [true, true],
      reason:
          'QoS 1 acknowledgement and subscribed delivery are both required.',
    );
    expect(messages.current.topic, topic);
    expect(messages.current.payload, payload);
  } finally {
    await messages.cancel();
  }
}

void main() {
  test('production browser adapter rejects ws URLs before connecting', () {
    expect(
      () => createMqttClient('ws://127.0.0.1:28886/mqtt', 'insecure'),
      throwsFormatException,
    );
  });

  group(
    'authenticated local WSS broker',
    () {
      late WssFixtureClient client;
      late String clientId;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        clientId = 'owntrack-wss-${DateTime.now().microsecondsSinceEpoch}';
        client = await WssFixtureClient.open(clientId);
      });

      tearDown(() => client.close());

      test(
        'authenticates, acknowledges QoS 1, and receives subscribed payload',
        () async {
          expect(await client.service.connect(), isTrue);
          expect(client.state.state, EndpointState.connected);
          await verifyRoundTrip(
            client.service,
            'owntracks/wss-test/$clientId',
            1,
          );
        },
      );

      test(
        'rejects an incorrect password on the reachable trusted listener',
        () async {
          await client.settings.setMqttPassword('$fixturePassword-incorrect');
          expect(await client.service.connect(), isFalse);
          expect(client.service.isConnected, isFalse);
          expect(client.state.state, isNot(EndpointState.connected));
          expect(
            await client.service.publish('owntracks/wss-test/$clientId', '{}'),
            isFalse,
          );
        },
      );

      test(
        'rejects an unlisted certificate without broad browser trust',
        () async {
          await client.settings.setMqttPort(untrustedPort);
          expect(await client.service.connect(), isFalse);
          expect(client.service.isConnected, isFalse);
          expect(client.state.state, isNot(EndpointState.connected));
        },
      );

      test('production browser adapter rejects disabling TLS', () async {
        await client.settings.setMqttUseTls(false);
        expect(await client.service.connect(), isFalse);
        expect(client.service.isConnected, isFalse);
        expect(client.state.errorMessage, contains('TLS'));
      });

      test(
        'reconnects and resubscribes after the broker evicts its connection',
        () async {
          expect(await client.service.connect(), isTrue);
          final topic = 'owntracks/wss-test/$clientId';
          await verifyRoundTrip(client.service, topic, 1);
          final duplicate = await WssFixtureClient.open(clientId);
          try {
            final disconnected = client.state.stateStream
                .firstWhere((state) => state == EndpointState.disconnected)
                .timeout(const Duration(seconds: 10));
            final results = await Future.wait([
              disconnected.then((_) => true),
              duplicate.service.connect(),
            ]);
            expect(results, [true, true]);
            expect(client.service.isConnected, isFalse);
          } finally {
            await duplicate.close();
          }
          expect(await client.service.connect(), isTrue);
          expect(client.state.state, EndpointState.connected);
          await verifyRoundTrip(client.service, topic, 2);
        },
      );
    },
    skip:
        fixturePort == 0 ||
            untrustedPort == 0 ||
            fixtureUsername.isEmpty ||
            fixturePassword.isEmpty
        ? 'Run bash tool/verify_mqtt_wss.sh to provision the local authenticated WSS fixture.'
        : false,
  );
}
