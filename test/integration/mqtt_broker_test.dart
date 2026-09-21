import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/mqtt_service.dart';

void main() {
  const port = int.fromEnvironment('MQTT_TEST_PORT');
  test(
    'real broker acknowledges QoS 1 and returns subscribed location payload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository(
        SettingsLocalDataSource(await SharedPreferences.getInstance()),
      );
      await settings.setMqttHost('127.0.0.1');
      await settings.setMqttPort(port);
      await settings.setMqttClientId('owntrack-integration');
      await settings.setMqttUseTls(false);
      final state = EndpointStateRepository();
      final service = MqttService(settings, state);
      try {
        expect(await service.connect(), isTrue);
        service.subscribe('owntracks/integration/phone');
        final received = service.messages.first;
        expect(
          await service.publish(
            'owntracks/integration/phone',
            '{"_type":"location","lat":1,"lon":2,"tst":100}',
          ),
          isTrue,
        );
        final message = await received.timeout(const Duration(seconds: 5));
        expect(message.topic, 'owntracks/integration/phone');
        expect(jsonDecode(message.payload)['lat'], 1);
      } finally {
        await service.disconnect();
        service.dispose();
        state.dispose();
      }
    },
    skip: port == 0
        ? 'Run with --dart-define=MQTT_TEST_PORT=<local broker port>'
        : false,
  );
}
