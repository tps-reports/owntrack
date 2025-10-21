import 'dart:async';

/// Endpoint state enum
enum EndpointState {
  idle,
  connecting,
  connected,
  disconnected,
  error,
}

/// Repository for tracking connection state
class EndpointStateRepository {
  EndpointState _state = EndpointState.idle;
  String? _errorMessage;
  final StreamController<EndpointState> _stateController =
      StreamController<EndpointState>.broadcast();

  /// Stream of state changes
  Stream<EndpointState> get stateStream => _stateController.stream;

  /// Get current state
  EndpointState get state => _state;

  /// Get error message if any
  String? get errorMessage => _errorMessage;

  /// Set state to connecting
  void setConnecting() {
    _state = EndpointState.connecting;
    _errorMessage = null;
    _stateController.add(_state);
  }

  /// Set state to connected
  void setConnected() {
    _state = EndpointState.connected;
    _errorMessage = null;
    _stateController.add(_state);
  }

  /// Set state to disconnected
  void setDisconnected() {
    _state = EndpointState.disconnected;
    _errorMessage = null;
    _stateController.add(_state);
  }

  /// Set state to error
  void setError(String message) {
    _state = EndpointState.error;
    _errorMessage = message;
    _stateController.add(_state);
  }

  /// Set state to idle
  void setIdle() {
    _state = EndpointState.idle;
    _errorMessage = null;
    _stateController.add(_state);
  }

  /// Check if connected
  bool get isConnected => _state == EndpointState.connected;

  /// Check if connecting
  bool get isConnecting => _state == EndpointState.connecting;

  /// Dispose resources
  void dispose() {
    _stateController.close();
  }
}
