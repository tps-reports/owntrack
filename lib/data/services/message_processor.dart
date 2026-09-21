import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/encryption_service.dart';
import 'package:owntrack/data/services/http_service.dart';
import 'package:owntrack/data/services/mqtt_service.dart';

/// Owns receive subscriptions and retries. Only transport acknowledgements remove
/// durable messages. Retries are bounded in frequency, never by discarding data.
class MessageProcessor {
  final SettingsRepository _settingsRepository;
  final MessageQueueRepository _queueRepository;
  final MqttService _mqttService;
  final HttpService _httpService;
  final EncryptionService _encryptionService;
  Timer? _timer;
  StreamSubscription<dynamic>? _subscription;
  bool _active = false;
  bool _disposed = false;
  int _generation = 0;
  String? _connectedIdentity;
  String? _connectedMode;
  Future<void>? _processing;
  String? lastError;
  DateTime? lastDelivered;
  final _status = StreamController<String?>.broadcast();
  final _incoming = StreamController<Map<String, dynamic>>.broadcast();
  Stream<String?> get statusChanges => _status.stream;
  Stream<Map<String, dynamic>> get incomingMessages => _incoming.stream;

  MessageProcessor(
    this._settingsRepository,
    this._queueRepository,
    this._mqttService,
    this._httpService,
    this._encryptionService,
  );

  void _report(String? error) {
    if (_disposed) return;
    lastError = error;
    if (error != null) AppLogger.w(error);
    _status.add(error);
  }

  Future<String> _identity() async {
    final settings = _settingsRepository;
    final mode = settings.getConnectionMode();
    final parts = [
      mode,
      if (mode == AppConstants.connectionModeHttp)
        settings.getHttpUrl()
      else ...[
        settings.getMqttHost(),
        settings.getMqttPort(),
        settings.getMqttUseTls(),
        settings.getMqttUsername(),
        settings.getMqttClientId(),
      ],
      settings.getDeviceId(),
      settings.getTrackerId(),
      settings.getEncryptionKey(),
    ];
    final hash = await Sha256().hash(utf8.encode(jsonEncode(parts)));
    return base64UrlEncode(hash.bytes);
  }

  Future<String> currentDestination() => _identity();

  /// A manual retry keeps destination isolation and wakes only records for the
  /// currently configured connection. Existing in-flight work completes first.
  Future<void> retryDelivery() async {
    if (_disposed) throw StateError('Message delivery has been disposed.');
    await _processing;
    if (_disposed) throw StateError('Message delivery has been disposed.');
    await _queueRepository.retryDestination(await _identity());
    await start();
  }

  Future<void> start() async {
    if (_disposed) throw StateError('Message delivery has been disposed.');
    _active = true;
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_process());
    });
    await _process();
  }

  Future<void> _disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    final mode = _connectedMode ?? _settingsRepository.getConnectionMode();
    _connectedMode = null;
    _connectedIdentity = null;
    if (mode == AppConstants.connectionModeMqtt) {
      await _mqttService.disconnect();
    } else {
      await _httpService.disconnect();
    }
  }

  Future<void> stop() async {
    _active = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
    await _disconnect();
    await _processing;
  }

  Future<void> sendMessage(
    Map<String, dynamic> message, {
    String? topic,
  }) async {
    if (_disposed) throw StateError('Message delivery has been disposed.');
    final destination = await _identity();
    final encrypted = await _encryptionService.encryptMessage(message);
    if (encrypted == null) {
      throw StateError('Encryption failed. Check the encryption key.');
    }
    if (destination != await _identity()) {
      throw StateError('Connection settings changed. Retry publication.');
    }
    final mqttMode =
        _settingsRepository.getConnectionMode() ==
        AppConstants.connectionModeMqtt;
    await _queueRepository.enqueue(
      mqttMode ? topic ?? _defaultTopic() : '',
      jsonEncode(encrypted),
      destination: destination,
    );
    if (_active) unawaited(_process());
  }

  String _defaultTopic() =>
      'owntracks/${_settingsRepository.getDeviceId()}/${_settingsRepository.getTrackerId()}';

  Future<void> _receive(
    Map<String, dynamic> message,
    int generation, {
    String? topic,
  }) async {
    try {
      final decoded = await _encryptionService.decryptMessage(message);
      if (_disposed || !_active || generation != _generation) return;
      if (decoded == null || decoded['_type'] is! String) {
        _report(
          'Incoming message rejected: invalid envelope or encryption key.',
        );
        return;
      }
      // Commands are never executed here. Routing only accepts supported data.
      _incoming.add({...decoded, 'topic': ?topic});
    } catch (_) {
      _report('Incoming message could not be decoded.');
    }
  }

  void _receiveMqtt(({String topic, String payload}) message, int generation) {
    try {
      if (message.payload.length > 1024 * 1024) throw const FormatException();
      final decoded = jsonDecode(message.payload);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      unawaited(_receive(decoded, generation, topic: message.topic));
    } on FormatException {
      _report('Incoming MQTT message rejected: invalid or oversized JSON.');
    }
  }

  Future<void> _process() {
    if (_processing != null) return _processing!;
    final operation = _run();
    _processing = operation;
    return operation.whenComplete(() {
      _processing = null;
    });
  }

  Future<void> _run() async {
    final generation = _generation;
    bool current() => !_disposed && _active && generation == _generation;
    try {
      if (!current()) return;
      final identity = await _identity();
      if (!current()) return;
      final mode = _settingsRepository.getConnectionMode();
      if (_connectedIdentity != identity ||
          !(mode == AppConstants.connectionModeMqtt
              ? _mqttService.isConnected
              : _httpService.isConnected)) {
        if (_connectedIdentity != null || _subscription != null) {
          await _disconnect();
        }
        if (!current()) return;
        final connected = mode == AppConstants.connectionModeMqtt
            ? await _mqttService.connect()
            : await _httpService.connect();
        if (!current()) {
          if (mode == AppConstants.connectionModeMqtt) {
            await _mqttService.disconnect();
          } else {
            await _httpService.disconnect();
          }
          return;
        }
        if (!connected) {
          _report(
            'Delivery is offline. Check connection settings; queued messages are retained.',
          );
          return;
        }
        _connectedMode = mode;
        _connectedIdentity = identity;
        if (mode == AppConstants.connectionModeMqtt) {
          _subscription = _mqttService.messages.listen(
            (message) => _receiveMqtt(message, generation),
          );
          _mqttService.subscribe('${_defaultTopic()}/+');
          _mqttService.subscribe('owntracks/+/+');
        } else {
          _subscription = _httpService.messages.listen((message) {
            unawaited(_receive(message, generation));
          });
        }
      }
      await _queueRepository.refresh();
      var blocked = false;
      var deliveryFailed = false;
      for (final message in _queueRepository.getAllMessages()) {
        if (!current() || identity != await _identity()) return;
        // A previous send can wait for an acknowledgement while this screen or
        // another session discards a later record. Revalidate durable membership
        // after that wait and before beginning the next transmission.
        await _queueRepository.refresh();
        if (!current()) return;
        if (!_queueRepository.getAllMessages().any(
          (pending) => pending.id == message.id,
        )) {
          continue;
        }
        if (message.destination != identity) {
          blocked = true;
          continue;
        }
        if (message.retryAt > DateTime.now().millisecondsSinceEpoch ~/ 1000) {
          continue;
        }
        final success = mode == AppConstants.connectionModeMqtt
            ? await _mqttService.publish(
                message.topic,
                message.payload,
                qos: message.qos == 2
                    ? mqtt.MqttQos.exactlyOnce
                    : mqtt.MqttQos.atLeastOnce,
              )
            : await _httpService.publish(message.payload);
        if (!current()) return;
        if (success) {
          await _queueRepository.dequeue(message.id);
          lastDelivered = DateTime.now();
        } else {
          deliveryFailed = true;
          final exponent = message.retryCount.clamp(0, 6);
          await _queueRepository.incrementRetry(
            message.id,
            retryAt:
                DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                5 * (1 << exponent),
          );
          _report('Delivery failed; message retained for retry.');
          _connectedIdentity = null;
          await _disconnect();
          break;
        }
      }
      if (current() && !deliveryFailed) {
        _report(
          blocked
              ? 'Queued messages blocked: destination or encryption settings differ. Restore the original settings to deliver them, or open Outbox to export or discard selected records. Legacy records require export.'
              : null,
        );
      }
    } catch (_) {
      _report(
        'Message delivery or storage failed. Queued records have been retained.',
      );
    }
  }

  void dispose() {
    _disposed = true;
    _active = false;
    _generation++;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    _incoming.close();
    _status.close();
  }
}
