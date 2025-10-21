import 'dart:async';

import 'package:dio/dio.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';

/// HTTP client service for OwnTracks protocol
///
/// Handles HTTP POST for location updates and GET polling for
/// receiving messages from the server.
class HttpService {
  final SettingsRepository _settingsRepository;
  final EndpointStateRepository _stateRepository;
  final Dio _dio;

  Timer? _pollTimer;
  bool _isPolling = false;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of received messages
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Check if currently connected (polling)
  bool get isConnected => _isPolling;

  HttpService(
    this._settingsRepository,
    this._stateRepository, {
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Start HTTP connection (begin polling)
  Future<bool> connect() async {
    try {
      _stateRepository.setConnecting();

      final url = _settingsRepository.getHttpUrl();
      if (url.isEmpty) {
        AppLogger.e('HTTP URL not configured');
        _stateRepository.setError('HTTP URL not configured');
        return false;
      }

      AppLogger.i('Starting HTTP connection to $url');

      // Validate URL is reachable
      try {
        await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 5)));
      } catch (e) {
        AppLogger.e('HTTP endpoint not reachable: $e');
        _stateRepository.setError('Endpoint not reachable: $e');
        return false;
      }

      // Start polling
      _isPolling = true;
      _stateRepository.setConnected();
      _startPolling();

      AppLogger.i('HTTP connection established');
      return true;
    } catch (e) {
      AppLogger.e('HTTP connection error: $e');
      _stateRepository.setError('Connection error: $e');
      _isPolling = false;
      return false;
    }
  }

  /// Stop HTTP connection (stop polling)
  Future<void> disconnect() async {
    AppLogger.i('Stopping HTTP connection');
    _isPolling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _stateRepository.setDisconnected();
  }

  /// Publish a message via HTTP POST
  Future<bool> publish(String payload) async {
    if (!_isPolling) {
      AppLogger.w('Cannot publish - not connected');
      return false;
    }

    final url = _settingsRepository.getHttpUrl();
    if (url.isEmpty) {
      AppLogger.e('HTTP URL not configured');
      return false;
    }

    try {
      AppLogger.d('Publishing via HTTP POST: $payload');

      final response = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.d('HTTP POST successful');
        return true;
      } else {
        AppLogger.e('HTTP POST failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.e('Error publishing via HTTP: $e');
      return false;
    }
  }

  /// Start polling for messages
  void _startPolling() {
    // Poll every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isPolling) return;
      await _poll();
    });

    // Initial poll
    _poll();
  }

  /// Poll the server for new messages
  Future<void> _poll() async {
    if (!_isPolling) return;

    final url = _settingsRepository.getHttpUrl();
    if (url.isEmpty) return;

    try {
      final response = await _dio.get(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        // Parse response
        final data = response.data;
        if (data is Map<String, dynamic>) {
          _messageController.add(data);
          AppLogger.d('Received message via HTTP: $data');
        } else if (data is List) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              _messageController.add(item);
              AppLogger.d('Received message via HTTP: $item');
            }
          }
        }
      }
    } catch (e) {
      // Polling errors are expected when no data is available
      // Only log if it's not a timeout
      if (e is! DioException || e.type != DioExceptionType.receiveTimeout) {
        AppLogger.w('HTTP poll error: $e');
      }
    }
  }

  /// Clean up resources
  void dispose() {
    _pollTimer?.cancel();
    _messageController.close();
    _dio.close();
  }
}
