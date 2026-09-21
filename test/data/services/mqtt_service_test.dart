import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/mqtt_service.dart';
import 'package:owntrack/data/services/connection_probe.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestMqttClient extends MqttServerClient {
  TestMqttClient(super.server, super.clientIdentifier);
  final status = MqttClientConnectionStatus();
  final incoming =
      StreamController<List<MqttReceivedMessage<MqttMessage>>>.broadcast();
  Completer<void>? connectGate;
  Object? connectError;
  final acknowledgements = StreamController<MqttPublishMessage>.broadcast();
  @override
  Stream<MqttPublishMessage> get published => acknowledgements.stream;
  @override
  int publishMessage(
    String topic,
    MqttQos qualityOfService,
    dynamic data, {
    bool retain = false,
  }) => 7;
  @override
  MqttClientConnectionStatus get connectionStatus => status;
  @override
  Stream<List<MqttReceivedMessage<MqttMessage>>> get updates => incoming.stream;
  @override
  Future<MqttClientConnectionStatus?> connect([
    String? username,
    String? password,
  ]) async {
    await connectGate?.future;
    if (connectError != null) throw connectError!;
    status.state = MqttConnectionState.connected;
    onConnected?.call();
    return status;
  }

  @override
  void disconnect() {
    status.state = MqttConnectionState.disconnected;
  }
}

void main() {
  test(
    'MQTT probe authenticates an isolated client and disconnects it',
    () async {
      final client = TestMqttClient('broker.invalid', 'probe-test');
      final probe = ConnectionProbe(clientFactory: (_, _) => client);
      await probe.testMqtt(
        host: 'broker.invalid',
        port: 8883,
        useTls: true,
        username: 'user',
        password: 'secret',
      );
      expect(client.connectionMessage!.payload.username, 'user');
      expect(client.connectionMessage!.payload.password, 'secret');
      expect(
        client.connectionMessage!.payload.clientIdentifier,
        startsWith('probe-'),
      );
      expect(client.secure, isTrue);
      expect(client.port, 8883);
      expect(client.status.state, MqttConnectionState.disconnected);
      await client.incoming.close();
      probe.dispose();
    },
  );
  group('MqttService', () {
    late MqttService service;
    late SettingsRepository settingsRepository;
    late EndpointStateRepository stateRepository;
    TestMqttClient? client;
    Object? nextConnectError;
    Completer<void>? nextConnectGate;
    late List<TestMqttClient> clients;

    test(
      'QoS 1 delivery waits for the matching broker acknowledgement',
      () async {
        await settingsRepository.setMqttHost('broker.invalid');
        await service.connect();
        var completed = false;
        final sending = service.publish('owntracks/a/b', '{}').then((value) {
          completed = true;
          return value;
        });
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        client!.acknowledgements.add(
          MqttPublishMessage().withMessageIdentifier(6),
        );
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);
        client!.acknowledgements.add(
          MqttPublishMessage().withMessageIdentifier(7),
        );
        expect(await sending, isTrue);
      },
    );

    testWidgets(
      'a timed out publication cannot remove a newer reused packet identifier',
      (tester) async {
        await settingsRepository.setMqttHost('broker.invalid');
        expect(await service.connect(), isTrue);
        bool? firstResult;
        bool? secondResult;
        unawaited(
          service.publish('owntracks/a/b', '{"sequence":1}').then((accepted) {
            firstResult = accepted;
          }),
        );
        await tester.pump(const Duration(seconds: 1));
        unawaited(
          service.publish('owntracks/a/b', '{"sequence":2}').then((accepted) {
            secondResult = accepted;
          }),
        );
        await tester.pump(const Duration(seconds: 14));
        expect(firstResult, isFalse);
        expect(secondResult, isNull);
        client!.acknowledgements.add(
          MqttPublishMessage().withMessageIdentifier(7),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(secondResult, isTrue);
      },
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = SettingsLocalDataSource(prefs);
      settingsRepository = SettingsRepository(dataSource);
      stateRepository = EndpointStateRepository();

      client = null;
      nextConnectError = null;
      nextConnectGate = null;
      clients = [];
      service = MqttService(
        settingsRepository,
        stateRepository,
        clientFactory: (host, id) {
          final created = TestMqttClient(host, id)
            ..connectError = nextConnectError
            ..connectGate = nextConnectGate;
          clients.add(created);
          return client = created;
        },
      );
    });

    tearDown(() async {
      service.dispose();
      stateRepository.dispose();
      for (final created in clients) {
        await created.incoming.close();
        await created.acknowledgements.close();
      }
    });

    group('connect', () {
      test(
        'disconnect permits a replacement while a cancelled connection completes late',
        () async {
          await settingsRepository.setMqttHost('broker.invalid');
          final blocked = Completer<void>();
          nextConnectGate = blocked;
          final cancelled = service.connect();
          await pumpEventQueue();
          await service.disconnect();
          nextConnectGate = null;
          final replacement = service.connect();
          await pumpEventQueue();
          blocked.complete();
          expect(await cancelled, isFalse);
          expect(await replacement, isTrue);
          expect(stateRepository.state, EndpointState.connected);
          expect(service.isConnected, isTrue);
        },
      );

      test(
        'failed client disconnect cannot corrupt a later connection or its pending acknowledgement',
        () async {
          await settingsRepository.setMqttHost('broker.invalid');
          nextConnectError = StateError('Authentication denied');
          expect(await service.connect(), isFalse);
          final staleDisconnect = client!.onDisconnected!;
          nextConnectError = null;
          expect(await service.connect(), isTrue);
          var completed = false;
          final sending = service.publish('owntracks/a/b', '{}').then((
            accepted,
          ) {
            completed = true;
            return accepted;
          });
          staleDisconnect();
          await pumpEventQueue();
          expect(stateRepository.state, EndpointState.connected);
          expect(completed, isFalse);
          client!.acknowledgements.add(
            MqttPublishMessage().withMessageIdentifier(7),
          );
          expect(await sending, isTrue);
        },
      );

      test(
        'old client acknowledgement cannot complete a replacement connection publication',
        () async {
          await settingsRepository.setMqttHost('broker.invalid');
          expect(await service.connect(), isTrue);
          final disconnectedClient = client!;
          disconnectedClient.status.state = MqttConnectionState.disconnected;
          disconnectedClient.onDisconnected!();
          expect(await service.connect(), isTrue);
          var completed = false;
          final sending = service.publish('owntracks/a/b', '{}').then((
            accepted,
          ) {
            completed = true;
            return accepted;
          });
          disconnectedClient.acknowledgements.add(
            MqttPublishMessage().withMessageIdentifier(7),
          );
          await pumpEventQueue();
          expect(completed, isFalse);
          client!.acknowledgements.add(
            MqttPublishMessage().withMessageIdentifier(7),
          );
          expect(await sending, isTrue);
        },
      );

      test('should fail when MQTT host not configured', () async {
        final result = await service.connect();

        expect(result, isFalse);
        expect(stateRepository.state, equals(EndpointState.error));
        expect(service.isConnected, isFalse);
      });

      test(
        'reports connecting until the broker accepts the connection',
        () async {
          await settingsRepository.setMqttHost('broker.invalid');
          // The factory is invoked synchronously before connect waits.
          final connecting = service.connect();
          expect(stateRepository.state, EndpointState.connecting);
          expect(await connecting, isTrue);
          expect(stateRepository.state, EndpointState.connected);
        },
      );

      test(
        'configures credentials and identity on the client used to connect',
        () async {
          await settingsRepository.setMqttHost('broker.invalid');
          await settingsRepository.setMqttPort(8883);
          await settingsRepository.setMqttUsername('testuser');
          await settingsRepository.setMqttPassword('testpass');
          await settingsRepository.setMqttClientId('test-client-123');
          expect(await service.connect(), isTrue);
          expect(client!.server, 'broker.invalid');
          expect(client!.port, 8883);
          expect(client!.connectionMessage!.payload.username, 'testuser');
          expect(client!.connectionMessage!.payload.password, 'testpass');
          expect(
            client!.connectionMessage!.payload.clientIdentifier,
            'test-client-123',
          );
        },
      );

      test('enables TLS on the client used to connect', () async {
        await settingsRepository.setMqttHost('broker.invalid');
        await settingsRepository.setMqttUseTls(true);
        expect(await service.connect(), isTrue);
        expect(client!.secure, isTrue);
        expect(client!.securityContext, isNotNull);
      });
    });

    group('disconnect', () {
      test('should disconnect and update state', () async {
        await service.disconnect();

        expect(service.isConnected, isFalse);
        expect(stateRepository.state, equals(EndpointState.disconnected));
      });
    });

    group('publish', () {
      test('should fail when not connected', () async {
        final result = await service.publish('test/topic', '{"test": "data"}');
        expect(result, isFalse);
      });
    });

    group('subscribe/unsubscribe', () {
      test('should not throw when not connected', () {
        expect(() => service.subscribe('test/topic'), returnsNormally);
        expect(() => service.unsubscribe('test/topic'), returnsNormally);
      });
    });

    group('isConnected', () {
      test('should return false when not connected', () {
        expect(service.isConnected, isFalse);
      });
    });

    group('messages stream', () {
      test('should have broadcast stream', () {
        // Should be able to listen multiple times
        final subscription1 = service.messages.listen((_) {});
        final subscription2 = service.messages.listen((_) {});

        expect(subscription1, isNotNull);
        expect(subscription2, isNotNull);

        subscription1.cancel();
        subscription2.cancel();
      });
    });
  });
}
