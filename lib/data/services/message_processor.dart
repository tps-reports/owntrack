import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:owntrack/core/constants/app_constants.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/encryption_service.dart';
import 'package:owntrack/data/services/http_service.dart';
import 'package:owntrack/data/services/mqtt_service.dart';

/// Message processor service
///
/// Coordinates message sending/receiving between MQTT and HTTP modes,
/// handles encryption, manages the message queue, and implements retry logic.
class MessageProcessor {
  final SettingsRepository _settingsRepository;
  final MessageQueueRepository _queueRepository;
  final MqttService _mqttService;
  final HttpService _httpService;
  final EncryptionService _encryptionService;

  Timer? _queueProcessorTimer;
  bool _isProcessing = false;

  final StreamController<Map<String, dynamic>> _incomingMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming messages (decrypted and parsed)
  Stream<Map<String, dynamic>> get incomingMessages =>
      _incomingMessageController.stream;

  /// Maximum retry attempts before giving up
  static const int maxRetries = 5;

  /// Retry delay in seconds (exponential backoff)
  static const int baseRetryDelay = 5;

  MessageProcessor(
    this._settingsRepository,
    this._queueRepository,
    this._mqttService,
    this._httpService,
    this._encryptionService,
  );

  /// Start the message processor
  Future<void> start() async {
    AppLogger.i('Starting message processor');

    final connectionMode = _settingsRepository.getConnectionMode();

    // Connect based on mode
    bool connected = false;
    if (connectionMode == AppConstants.connectionModeMqtt) {
      connected = await _mqttService.connect();
      if (connected) {
        _subscribeToMqttTopics();
        _mqttService.messages.listen(_handleMqttMessage);
      }
    } else if (connectionMode == AppConstants.connectionModeHttp) {
      connected = await _httpService.connect();
      if (connected) {
        _httpService.messages.listen(_handleHttpMessage);
      }
    }

    if (connected) {
      // Start processing queued messages
      _startQueueProcessor();
    }
  }

  /// Stop the message processor
  Future<void> stop() async {
    AppLogger.i('Stopping message processor');

    _queueProcessorTimer?.cancel();
    _queueProcessorTimer = null;
    _isProcessing = false;

    final connectionMode = _settingsRepository.getConnectionMode();
    if (connectionMode == AppConstants.connectionModeMqtt) {
      await _mqttService.disconnect();
    } else if (connectionMode == AppConstants.connectionModeHttp) {
      await _httpService.disconnect();
    }
  }

  /// Send a message (queued for reliable delivery)
  Future<void> sendMessage(Map<String, dynamic> message, {String? topic}) async {
    try {
      // Encrypt if enabled
      final encrypted = _encryptionService.isEnabled
          ? await _encryptionService.encryptMessage(message)
          : message;

      if (encrypted == null) {
        AppLogger.e('Failed to encrypt message');
        return;
      }

      final payload = json.encode(encrypted);
      final connectionMode = _settingsRepository.getConnectionMode();

      if (connectionMode == AppConstants.connectionModeMqtt) {
        // For MQTT, we need a topic
        final topicToUse = topic ?? _buildDefaultTopic();
        await _queueRepository.enqueue(topicToUse, payload);
      } else {
        // For HTTP, topic is optional (stored as empty string)
        await _queueRepository.enqueue('', payload);
      }

      AppLogger.d('Message queued for delivery');
    } catch (e) {
      AppLogger.e('Error sending message: $e');
    }
  }

  /// Subscribe to MQTT topics based on configuration
  void _subscribeToMqttTopics() {
    final deviceId = _settingsRepository.getDeviceId();
    final trackerId = _settingsRepository.getTrackerId();

    if (deviceId.isEmpty) {
      AppLogger.w('Device ID not set, cannot subscribe to topics');
      return;
    }

    // Subscribe to user's own topic for receiving commands/waypoints
    final userTopic = 'owntracks/$deviceId/$trackerId';
    _mqttService.subscribe('$userTopic/+');

    // Subscribe to shared topics
    _mqttService.subscribe('owntracks/+/+');

    AppLogger.i('Subscribed to MQTT topics');
  }

  /// Handle incoming MQTT message
  void _handleMqttMessage(({String topic, String payload}) message) async {
    try {
      AppLogger.d('Processing MQTT message from ${message.topic}');
      final parsed = json.decode(message.payload) as Map<String, dynamic>;

      // Decrypt if encrypted
      final decrypted = _encryptionService.isEnabled
          ? await _encryptionService.decryptMessage(parsed)
          : parsed;

      if (decrypted != null) {
        _incomingMessageController.add(decrypted);
      }
    } catch (e) {
      AppLogger.e('Error handling MQTT message: $e');
    }
  }

  /// Handle incoming HTTP message
  void _handleHttpMessage(Map<String, dynamic> message) async {
    try {
      AppLogger.d('Processing HTTP message');

      // Decrypt if encrypted
      final decrypted = _encryptionService.isEnabled
          ? await _encryptionService.decryptMessage(message)
          : message;

      if (decrypted != null) {
        _incomingMessageController.add(decrypted);
      }
    } catch (e) {
      AppLogger.e('Error handling HTTP message: $e');
    }
  }

  /// Start processing queued messages
  void _startQueueProcessor() {
    // Process queue every 5 seconds
    _queueProcessorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _processQueue();
    });

    // Initial processing
    _processQueue();
  }

  /// Process queued messages with retry logic
  Future<void> _processQueue() async {
    if (_isProcessing || _queueRepository.isEmpty) {
      return;
    }

    _isProcessing = true;

    try {
      final message = _queueRepository.peek();
      if (message == null) {
        return;
      }

      // Check if max retries exceeded
      if (message.retryCount >= maxRetries) {
        AppLogger.w('Message ${message.id} exceeded max retries, removing');
        await _queueRepository.dequeue(message.id);
        return;
      }

      final connectionMode = _settingsRepository.getConnectionMode();
      bool success = false;

      if (connectionMode == AppConstants.connectionModeMqtt) {
        // Map qos integer to MqttQos enum
        final qosLevel = message.qos == 0
            ? mqtt.MqttQos.atMostOnce
            : message.qos == 2
                ? mqtt.MqttQos.exactlyOnce
                : mqtt.MqttQos.atLeastOnce;

        success = await _mqttService.publish(
          message.topic,
          message.payload,
          qos: qosLevel,
        );
      } else if (connectionMode == AppConstants.connectionModeHttp) {
        success = await _httpService.publish(message.payload);
      }

      if (success) {
        AppLogger.d('Message ${message.id} sent successfully');
        await _queueRepository.dequeue(message.id);
      } else {
        // Increment retry count
        AppLogger.w('Message ${message.id} failed, will retry (attempt ${message.retryCount + 1})');
        await _queueRepository.incrementRetry(message.id);

        // Exponential backoff
        final delay = baseRetryDelay * (1 << message.retryCount);
        AppLogger.d('Waiting ${delay}s before next retry');
        await Future.delayed(Duration(seconds: delay));
      }
    } catch (e) {
      AppLogger.e('Error processing queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Build default MQTT topic for publishing
  String _buildDefaultTopic() {
    final deviceId = _settingsRepository.getDeviceId();
    final trackerId = _settingsRepository.getTrackerId();
    return 'owntracks/$deviceId/$trackerId';
  }

  /// Clean up resources
  void dispose() {
    _queueProcessorTimer?.cancel();
    _incomingMessageController.close();
  }
}
