import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

// Delivery owns retry scheduling; an inner retry loop can outlive its deadline.
MqttClient createMqttClient(String host, String id) =>
    _NativeMqttClient(host, id);

class _NativeMqttClient extends MqttServerClient {
  _NativeMqttClient(super.server, super.clientIdentifier)
    : super(maxConnectionAttempts: 1);

  @override
  Future<MqttClientConnectionStatus?> connect([
    String? username,
    String? password,
  ]) async {
    final connecting = super.connect(username, password);
    final handler = connectionHandler;
    try {
      return await connecting;
    } finally {
      // Disconnect clears the client's handler before a pending native socket
      // necessarily exists. Keep that handler until the original attempt ends
      // so a socket opened after cancellation cannot retain its listeners.
      if (handler != null && !identical(handler, connectionHandler)) {
        try {
          handler.disconnect();
        } finally {
          handler.stopListening();
        }
      }
    }
  }
}

void configureMqttTransport(MqttClient client, bool useTls) {
  if (client is! MqttServerClient) {
    throw ArgumentError('Expected a native MQTT client.');
  }
  client.secure = useTls;
  if (useTls) client.securityContext = SecurityContext.defaultContext;
}
