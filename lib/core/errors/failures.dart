import 'package:equatable/equatable.dart';

/// Base class for all failures
abstract class Failure extends Equatable {
  final String message;
  final Exception? exception;

  const Failure(this.message, [this.exception]);

  @override
  List<Object?> get props => [message, exception];
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.exception]);
}

/// Database-related failures
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.exception]);
}

/// Location-related failures
class LocationFailure extends Failure {
  const LocationFailure(super.message, [super.exception]);
}

/// Permission-related failures
class PermissionFailure extends Failure {
  const PermissionFailure(super.message, [super.exception]);
}

/// MQTT-related failures
class MqttFailure extends Failure {
  const MqttFailure(super.message, [super.exception]);
}

/// HTTP-related failures
class HttpFailure extends Failure {
  const HttpFailure(super.message, [super.exception]);
}

/// Encryption-related failures
class EncryptionFailure extends Failure {
  const EncryptionFailure(super.message, [super.exception]);
}

/// Serialization-related failures
class SerializationFailure extends Failure {
  const SerializationFailure(super.message, [super.exception]);
}

/// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.exception]);
}

/// Generic server failure
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.exception]);
}

/// Validation failure
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.exception]);
}
