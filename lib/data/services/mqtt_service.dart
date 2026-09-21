import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/mqtt/client_factory.dart';

class MqttService {
  final SettingsRepository _settingsRepository;
  final EndpointStateRepository _stateRepository;
  final MqttClient Function(String, String) _clientFactory;
  MqttClient? _client;
  bool _disposed = false;
  int _generation = 0;
  Future<bool>? _connecting;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _messages;
  StreamSubscription<MqttPublishMessage>? _published;
  final _pending = <int, Completer<bool>>{};
  final _controller =
      StreamController<({String topic, String payload})>.broadcast();
  Stream<({String topic, String payload})> get messages => _controller.stream;
  bool get isConnected =>
      !_disposed &&
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  MqttService(
    this._settingsRepository,
    this._stateRepository, {
    MqttClient Function(String, String)? clientFactory,
  }) : _clientFactory = clientFactory ?? createMqttClient;

  Future<bool> connect() {
    if (_disposed) return Future.value(false);
    if (isConnected) return Future.value(true);
    if (_connecting != null) return _connecting!;
    final operation = _connect();
    _connecting = operation;
    return operation.whenComplete(() {
      if (identical(_connecting, operation)) _connecting = null;
    });
  }

  bool _ownsClient(MqttClient? client, int generation) =>
      !_disposed &&
      client != null &&
      generation == _generation &&
      identical(_client, client);

  Future<void> _cancelSubscriptions() async {
    final messages = _messages;
    final published = _published;
    _messages = null;
    _published = null;
    await Future.wait([
      if (messages != null) messages.cancel(),
      if (published != null) published.cancel(),
    ]);
  }

  Future<bool> _connect() async {
    final generation = ++_generation;
    MqttClient? client;
    try {
      _stateRepository.setConnecting();
      final previousClient = _client;
      _client = null;
      _failPending();
      await _cancelSubscriptions();
      previousClient?.disconnect();
      if (_disposed || generation != _generation) return false;
      final host = _settingsRepository.getMqttHost();
      if (host.isEmpty) throw const FormatException('MQTT host not configured');
      final id = _settingsRepository.getMqttClientId();
      client = _clientFactory(host, id);
      _client = client;
      client.port = _settingsRepository.getMqttPort();
      client.logging(on: false);
      client.connectTimeoutPeriod = 10000;
      client.keepAlivePeriod = 60;
      // The processor owns reconnect timing and subscriptions.
      client.autoReconnect = false;
      configureMqttTransport(client, _settingsRepository.getMqttUseTls());
      client.onDisconnected = () {
        if (!_ownsClient(client, generation)) return;
        _failPending();
        unawaited(_cancelSubscriptions());
        _stateRepository.setDisconnected();
      };
      final message = MqttConnectMessage()
          .withClientIdentifier(id)
          .startClean();
      final username = _settingsRepository.getMqttUsername();
      if (username.isNotEmpty) {
        message.authenticateAs(username, _settingsRepository.getMqttPassword());
      }
      client.connectionMessage = message;
      await client.connect().timeout(const Duration(seconds: 15));
      if (!_ownsClient(client, generation)) {
        client.disconnect();
        return false;
      }
      if (!isConnected) throw StateError('Broker rejected the connection.');
      _messages = client.updates?.listen((updates) {
        if (!_ownsClient(client, generation) || !isConnected) return;
        for (final update in updates) {
          final message = update.payload;
          if (message is! MqttPublishMessage ||
              message.payload.message.length > 1024 * 1024) {
            _stateRepository.setError('Invalid or oversized MQTT message.');
            continue;
          }
          _controller.add((
            topic: update.topic,
            payload: MqttPublishPayload.bytesToStringAsString(
              message.payload.message,
            ),
          ));
        }
      });
      _published = client.published?.listen((message) {
        if (!_ownsClient(client, generation) || !isConnected) return;
        final pending = _pending.remove(
          message.variableHeader?.messageIdentifier,
        );
        pending?.complete(true);
      });
      _stateRepository.setConnected();
      return true;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _generation++;
        _client = null;
        _failPending();
        _stateRepository.setError(
          'MQTT connection failed. Check host, port, credentials and TLS.',
        );
        AppLogger.w('MQTT connection failed.');
        await _cancelSubscriptions();
      }
      client?.disconnect();
      return false;
    }
  }

  void _failPending() {
    for (final pending in _pending.values) {
      pending.complete(false);
    }
    _pending.clear();
  }

  Future<void> disconnect() async {
    _generation++;
    _connecting = null;
    final client = _client;
    _client = null;
    _failPending();
    if (!_disposed) _stateRepository.setDisconnected();
    await _cancelSubscriptions();
    client?.disconnect();
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) {
    if (isConnected) _client!.subscribe(topic, qos);
  }

  void unsubscribe(String topic) {
    if (isConnected) _client!.unsubscribe(topic);
  }

  Future<bool> publish(
    String topic,
    String payload, {
    MqttQos qos = MqttQos.atLeastOnce,
    bool retain = false,
  }) async {
    if (!isConnected) return false;
    final client = _client!;
    final generation = _generation;
    try {
      final builder = MqttClientPayloadBuilder()..addString(payload);
      final id = client.publishMessage(
        topic,
        qos,
        builder.payload!,
        retain: retain,
      );
      // QoS 0 cannot prove broker acceptance. Durable delivery uses QoS 1 or 2.
      if (qos == MqttQos.atMostOnce ||
          !_ownsClient(client, generation) ||
          !isConnected) {
        return false;
      }
      final pending = Completer<bool>();
      _pending[id] = pending;
      try {
        return await pending.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => false,
        );
      } finally {
        if (identical(_pending[id], pending)) _pending.remove(id);
      }
    } catch (_) {
      if (_ownsClient(client, generation)) {
        _stateRepository.setError(
          'MQTT delivery failed; message retained for retry.',
        );
      }
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _connecting = null;
    _failPending();
    unawaited(_cancelSubscriptions());
    _client?.disconnect();
    _client = null;
    _controller.close();
  }
}
