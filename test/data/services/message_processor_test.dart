import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/encryption_service.dart';
import 'package:owntrack/data/services/http_service.dart';
import 'package:owntrack/data/services/message_processor.dart';
import 'package:owntrack/data/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMqttService extends Mock implements MqttService {}

class MockHttpService extends Mock implements HttpService {}

void main() {
  setUpAll(() {
    registerFallbackValue(MqttQos.atLeastOnce);
  });

  group('MessageProcessor', () {
    late MessageProcessor processor;
    late SettingsRepository settingsRepository;
    late MessageQueueRepository queueRepository;
    late MockMqttService mockMqttService;
    late MockHttpService mockHttpService;
    late EncryptionService encryptionService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dataSource = SettingsLocalDataSource(prefs);
      settingsRepository = SettingsRepository(dataSource);
      queueRepository = MessageQueueRepository(dataSource);
      mockMqttService = MockMqttService();
      mockHttpService = MockHttpService();
      encryptionService = EncryptionService(settingsRepository);

      // Set up default configuration
      await settingsRepository.setDeviceId('testuser');
      await settingsRepository.setTrackerId('testdevice');

      processor = MessageProcessor(
        settingsRepository,
        queueRepository,
        mockMqttService,
        mockHttpService,
        encryptionService,
      );
    });

    tearDown(() {
      processor.dispose();
    });

    group('start - MQTT mode', () {
      setUp(() async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeMqtt);
      });

      test('should connect to MQTT broker', () async {
        when(() => mockMqttService.connect()).thenAnswer((_) async => true);
        when(() => mockMqttService.messages).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockMqttService.subscribe(any(), qos: any(named: 'qos')))
            .thenReturn(null);

        await processor.start();

        verify(() => mockMqttService.connect()).called(1);
        verify(() => mockMqttService.subscribe(any(), qos: any(named: 'qos')))
            .called(greaterThan(0));
      });

      test('should not start queue processor if connection fails', () async {
        when(() => mockMqttService.connect()).thenAnswer((_) async => false);

        await processor.start();

        verify(() => mockMqttService.connect()).called(1);
        verifyNever(() => mockMqttService.subscribe(any(), qos: any(named: 'qos')));
      });

      test('should subscribe to user topics', () async {
        when(() => mockMqttService.connect()).thenAnswer((_) async => true);
        when(() => mockMqttService.messages).thenAnswer(
          (_) => const Stream.empty(),
        );
        when(() => mockMqttService.subscribe(any(), qos: any(named: 'qos')))
            .thenReturn(null);

        await processor.start();

        // Should subscribe to user's own topic and shared topics
        verify(() => mockMqttService.subscribe(
              'owntracks/testuser/testdevice/+',
              qos: any(named: 'qos'),
            )).called(1);
        verify(() => mockMqttService.subscribe(
              'owntracks/+/+',
              qos: any(named: 'qos'),
            )).called(1);
      });
    });

    group('start - HTTP mode', () {
      setUp(() async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeHttp);
      });

      test('should connect to HTTP endpoint', () async {
        when(() => mockHttpService.connect()).thenAnswer((_) async => true);
        when(() => mockHttpService.messages).thenAnswer(
          (_) => const Stream.empty(),
        );

        await processor.start();

        verify(() => mockHttpService.connect()).called(1);
      });

      test('should not start queue processor if connection fails', () async {
        when(() => mockHttpService.connect()).thenAnswer((_) async => false);

        await processor.start();

        verify(() => mockHttpService.connect()).called(1);
      });
    });

    group('stop', () {
      test('should disconnect MQTT when in MQTT mode', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeMqtt);
        when(() => mockMqttService.disconnect()).thenAnswer((_) async {});

        await processor.stop();

        verify(() => mockMqttService.disconnect()).called(1);
      });

      test('should disconnect HTTP when in HTTP mode', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeHttp);
        when(() => mockHttpService.disconnect()).thenAnswer((_) async {});

        await processor.stop();

        verify(() => mockHttpService.disconnect()).called(1);
      });
    });

    group('sendMessage', () {
      test('should queue message for MQTT delivery', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeMqtt);

        final message = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };

        await processor.sendMessage(message, topic: 'owntracks/test/device');

        expect(queueRepository.size, equals(1));
        final queued = queueRepository.peek();
        expect(queued, isNotNull);
        expect(queued!.topic, equals('owntracks/test/device'));
      });

      test('should queue message for HTTP delivery', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeHttp);

        final message = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };

        await processor.sendMessage(message);

        expect(queueRepository.size, equals(1));
        final queued = queueRepository.peek();
        expect(queued, isNotNull);
        expect(queued!.topic, isEmpty); // HTTP doesn't use topics
      });

      test('should encrypt message when encryption is enabled', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeMqtt);
        await settingsRepository.setEncryptionKey('test-key');

        final message = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };

        await processor.sendMessage(message, topic: 'owntracks/test/device');

        expect(queueRepository.size, equals(1));
        final queued = queueRepository.peek();
        expect(queued, isNotNull);

        final payload = json.decode(queued!.payload);
        expect(payload['_type'], equals('encrypted'));
        expect(payload['data'], isA<String>());
      });

      test('should use default topic when not provided in MQTT mode', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeMqtt);

        final message = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };

        await processor.sendMessage(message);

        expect(queueRepository.size, equals(1));
        final queued = queueRepository.peek();
        expect(queued, isNotNull);
        expect(queued!.topic, equals('owntracks/testuser/testdevice'));
      });
    });

    group('incoming messages', () {
      test('should emit incoming MQTT messages', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeMqtt);

        final controller = StreamController<({String topic, String payload})>();
        when(() => mockMqttService.messages).thenAnswer((_) => controller.stream);
        when(() => mockMqttService.connect()).thenAnswer((_) async => true);
        when(() => mockMqttService.subscribe(any(), qos: any(named: 'qos')))
            .thenReturn(null);

        final messages = <Map<String, dynamic>>[];
        processor.incomingMessages.listen(messages.add);

        await processor.start();

        final payload = json.encode({
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        });

        controller.add((topic: 'owntracks/friend/device', payload: payload));

        await Future.delayed(const Duration(milliseconds: 100));

        expect(messages.length, equals(1));
        expect(messages[0]['_type'], equals('location'));
        expect(messages[0]['lat'], equals(37.7749));

        await controller.close();
      });

      test('should emit incoming HTTP messages', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeHttp);

        final controller = StreamController<Map<String, dynamic>>();
        when(() => mockHttpService.messages).thenAnswer((_) => controller.stream);
        when(() => mockHttpService.connect()).thenAnswer((_) async => true);

        final messages = <Map<String, dynamic>>[];
        processor.incomingMessages.listen(messages.add);

        await processor.start();

        controller.add({
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        });

        await Future.delayed(const Duration(milliseconds: 100));

        expect(messages.length, equals(1));
        expect(messages[0]['_type'], equals('location'));
        expect(messages[0]['lat'], equals(37.7749));

        await controller.close();
      });

      test('should decrypt encrypted incoming messages', () async {
        await settingsRepository.setConnectionMode(AppConstants.connectionModeMqtt);
        await settingsRepository.setEncryptionKey('test-key');

        final controller = StreamController<({String topic, String payload})>();
        when(() => mockMqttService.messages).thenAnswer((_) => controller.stream);
        when(() => mockMqttService.connect()).thenAnswer((_) async => true);
        when(() => mockMqttService.subscribe(any(), qos: any(named: 'qos')))
            .thenReturn(null);

        final messages = <Map<String, dynamic>>[];
        processor.incomingMessages.listen(messages.add);

        await processor.start();

        // Encrypt a message
        final originalMessage = {
          '_type': 'location',
          'lat': 37.7749,
          'lon': -122.4194,
        };
        final encryptedMessage = await encryptionService.encryptMessage(originalMessage);
        final payload = json.encode(encryptedMessage);

        controller.add((topic: 'owntracks/friend/device', payload: payload));

        await Future.delayed(const Duration(milliseconds: 100));

        expect(messages.length, equals(1));
        expect(messages[0]['_type'], equals('location'));
        expect(messages[0]['lat'], equals(37.7749));

        await controller.close();
      });
    });
  });
}
