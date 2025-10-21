import 'dart:async';
import 'dart:io';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';

/// MQTT client service for OwnTracks protocol
///
/// Handles connection, subscription, and publishing to MQTT broker
/// with TLS support and automatic reconnection.
class MqttService {
  final SettingsRepository _settingsRepository;
  final EndpointStateRepository _stateRepository;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _messageSubscription;

  final StreamController<({String topic, String payload})> _messageController =
      StreamController<({String topic, String payload})>.broadcast();

  /// Stream of received messages
  Stream<({String topic, String payload})> get messages => _messageController.stream;

  /// Check if currently connected
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  MqttService(this._settingsRepository, this._stateRepository);

  /// Connect to MQTT broker
  Future<bool> connect() async {
    try {
      _stateRepository.setConnecting();

      final host = _settingsRepository.getMqttHost();
      final port = _settingsRepository.getMqttPort();
      final clientId = _settingsRepository.getMqttClientId();
      final username = _settingsRepository.getMqttUsername();
      final password = _settingsRepository.getMqttPassword();
      final useTls = _settingsRepository.getMqttUseTls();

      if (host.isEmpty) {
        AppLogger.e('MQTT host not configured');
        _stateRepository.setError('MQTT host not configured');
        return false;
      }

      AppLogger.i('Connecting to MQTT broker at $host:$port (TLS: $useTls)');

      // Create client
      _client = MqttServerClient(host, clientId);
      _client!.port = port;
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 60;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected = _onConnected;
      _client!.autoReconnect = true;

      // Configure TLS if enabled
      if (useTls) {
        _client!.secure = true;
        _client!.securityContext = SecurityContext.defaultContext;
      }

      // Set up connection message
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      if (username.isNotEmpty) {
        connMessage.authenticateAs(username, password);
      }

      _client!.connectionMessage = connMessage;

      // Connect
      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        AppLogger.i('MQTT connected successfully');
        _stateRepository.setConnected();

        // Subscribe to updates
        _messageSubscription = _client!.updates!.listen(_onMessage);

        return true;
      } else {
        AppLogger.e('MQTT connection failed: ${_client!.connectionStatus}');
        _stateRepository.setError('Connection failed: ${_client!.connectionStatus}');
        _client = null;
        return false;
      }
    } catch (e) {
      AppLogger.e('MQTT connection error: $e');
      _stateRepository.setError('Connection error: $e');
      _client = null;
      return false;
    }
  }

  /// Disconnect from MQTT broker
  Future<void> disconnect() async {
    AppLogger.i('Disconnecting from MQTT broker');
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _client?.disconnect();
    _client = null;
    _stateRepository.setDisconnected();
  }

  /// Subscribe to a topic
  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    if (!isConnected) {
      AppLogger.w('Cannot subscribe to $topic - not connected');
      return;
    }

    AppLogger.i('Subscribing to topic: $topic');
    _client!.subscribe(topic, qos);
  }

  /// Unsubscribe from a topic
  void unsubscribe(String topic) {
    if (!isConnected) {
      AppLogger.w('Cannot unsubscribe from $topic - not connected');
      return;
    }

    AppLogger.i('Unsubscribing from topic: $topic');
    _client!.unsubscribe(topic);
  }

  /// Publish a message to a topic
  Future<bool> publish(
    String topic,
    String payload, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) async {
    if (!isConnected) {
      AppLogger.w('Cannot publish to $topic - not connected');
      return false;
    }

    try {
      AppLogger.d('Publishing to $topic: $payload');
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      _client!.publishMessage(topic, qos, builder.payload!, retain: retain);
      return true;
    } catch (e) {
      AppLogger.e('Error publishing message: $e');
      return false;
    }
  }

  /// Handle incoming messages
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );

      AppLogger.d('Received message on $topic: $payload');
      _messageController.add((topic: topic, payload: payload));
    }
  }

  /// Handle connection established
  void _onConnected() {
    AppLogger.i('MQTT connection established');
    _stateRepository.setConnected();
  }

  /// Handle disconnection
  void _onDisconnected() {
    AppLogger.w('MQTT disconnected');
    _stateRepository.setDisconnected();
  }

  /// Clean up resources
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.close();
    _client?.disconnect();
  }
}
