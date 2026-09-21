import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/repositories/endpoint_state_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/http_endpoint.dart';

/// OwnTracks HTTP sends POSTs and receives messages in their responses.
class HttpService {
  final SettingsRepository _settingsRepository;
  final EndpointStateRepository _stateRepository;
  final Dio _dio;
  bool _ready = false;
  bool _disposed = false;
  CancelToken _cancelToken = CancelToken();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// HTTP has no persistent connection. This means configured and ready to send;
  /// endpointState only reports connected after an actual successful response.
  bool get isConnected => _ready && !_disposed;

  HttpService(this._settingsRepository, this._stateRepository, {Dio? dio})
    : _dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  Future<bool> connect() async {
    if (_disposed) return false;
    try {
      HttpEndpoint.parse(_settingsRepository.getHttpUrl());
      if (_cancelToken.isCancelled) _cancelToken = CancelToken();
      _ready = true;
      _stateRepository.setIdle();
      return true;
    } on FormatException catch (error) {
      _ready = false;
      _stateRepository.setError(error.message);
      return false;
    }
  }

  Future<void> disconnect() async {
    _ready = false;
    _cancelToken.cancel();
    if (!_disposed) _stateRepository.setDisconnected();
  }

  Future<bool> publish(String payload) async {
    if (!isConnected) return false;
    final token = _cancelToken;
    try {
      final endpoint = HttpEndpoint.parse(_settingsRepository.getHttpUrl());
      final response = await _dio.post<Object?>(
        endpoint.uri.toString(),
        data: payload,
        cancelToken: token,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (endpoint.authorization != null)
              'Authorization': endpoint.authorization,
            if (endpoint.username != null) 'X-Limit-U': endpoint.username,
            'X-Limit-D': _settingsRepository.getDeviceId(),
          },
          followRedirects: false,
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (_disposed || token.isCancelled) return false;
      final status = response.statusCode;
      if (status == null || status < 200 || status >= 300) {
        _stateRepository.setError('Location delivery rejected (HTTP $status).');
        return false;
      }
      _stateRepository.setConnected();
      try {
        _emitResponse(response.data);
      } on FormatException {
        // The server accepted the outgoing message. Retrying it because the
        // response is malformed would duplicate an already accepted location.
        _stateRepository.setError(
          'Location delivered, but the server response was invalid.',
        );
      }
      return true;
    } catch (_) {
      if (!_disposed && !token.isCancelled) {
        AppLogger.w('HTTP location delivery failed');
        _stateRepository.setError(
          'Location delivery failed. Check endpoint, credentials, network and TLS.',
        );
      }
      return false;
    }
  }

  void _emitResponse(Object? data) {
    if (data == null || data == '') return;
    if (data is String) {
      if (utf8.encode(data).length > 1024 * 1024) {
        throw const FormatException('Response too large');
      }
      data = jsonDecode(data);
    }
    final items = data is List ? data : [data];
    final validated = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item is! Map<String, dynamic> || item['_type'] is! String) {
        throw const FormatException('Invalid response message');
      }
      validated.add(item);
    }
    for (final message in validated) {
      _messageController.add(message);
    }
  }

  void dispose() {
    _disposed = true;
    _ready = false;
    _cancelToken.cancel();
    _messageController.close();
    _dio.close(force: true);
  }
}
