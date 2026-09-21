import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:owntrack/data/services/mqtt/client_factory.dart';

/// Tests draft settings using isolated clients, without altering saved settings
/// or sending a location. Network errors never expose credential-bearing URLs.
class ConnectionProbe {
  final Dio _dio;
  final MqttClient Function(String, String) _clientFactory;

  ConnectionProbe({
    Dio? dio,
    MqttClient Function(String, String)? clientFactory,
  }) : _dio =
           dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10))),
       _clientFactory = clientFactory ?? createMqttClient;

  Future<void> testHttp(String address) async {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasFragment) {
      throw ArgumentError('Enter a valid HTTPS endpoint without a fragment.');
    }
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (uri.userInfo.isNotEmpty) {
      headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode(Uri.decodeComponent(uri.userInfo)))}';
    }
    try {
      final response = await _dio.post<Object?>(
        uri.replace(userInfo: '').toString(),
        data: '',
        options: Options(
          headers: headers,
          followRedirects: false,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final status = response.statusCode;
      if (status == null || status < 200 || status >= 300) {
        throw StateError('Endpoint rejected the test (HTTP $status).');
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw StateError(
        status == null
            ? 'Connection failed. Check the endpoint, network and certificate.'
            : 'Endpoint rejected the test (HTTP $status).',
      );
    }
  }

  Future<void> testMqtt({
    required String host,
    required int port,
    required bool useTls,
    required String username,
    required String password,
  }) async {
    if (host.trim().isEmpty || port < 1 || port > 65535) {
      throw ArgumentError('Enter a broker host and a port from 1 to 65535.');
    }
    // A separate identity prevents a probe from disconnecting active tracking.
    final id = 'probe-${DateTime.now().microsecondsSinceEpoch}';
    final client = _clientFactory(host.trim(), id);
    try {
      client.port = port;
      client.connectTimeoutPeriod = 10000;
      client.autoReconnect = false;
      client.logging(on: false);
      configureMqttTransport(client, useTls);
      final message = MqttConnectMessage()
          .withClientIdentifier(id)
          .startClean();
      if (username.isNotEmpty) message.authenticateAs(username, password);
      client.connectionMessage = message;
      await client.connect().timeout(const Duration(seconds: 15));
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError(
          'Broker rejected the connection. Check credentials and TLS.',
        );
      }
    } catch (_) {
      throw StateError(
        'Broker connection failed. Check host, port, credentials and TLS.',
      );
    } finally {
      client.disconnect();
    }
  }

  void dispose() => _dio.close(force: true);
}
