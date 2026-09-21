import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String host, String id) {
  final uri = Uri.tryParse(host.contains('://') ? host : 'wss://$host');
  if (uri == null ||
      uri.scheme != 'wss' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const FormatException(
      'Configure a secure WebSocket broker URL (wss://host/path).',
    );
  }
  // Mosquitto's WebSocket handshake requires the MQTT subprotocol alone.
  // One attempt keeps the client's retry loop within the service deadline.
  return MqttBrowserClient(uri.toString(), id, maxConnectionAttempts: 1)
    ..websocketProtocols = MqttClientConstants.protocolsSingleDefault;
}

void configureMqttTransport(MqttClient client, bool useTls) {
  if (!useTls) {
    throw const FormatException(
      'Browser MQTT requires secure WebSockets (WSS).',
    );
  }
}
