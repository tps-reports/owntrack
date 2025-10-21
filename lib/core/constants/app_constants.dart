/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'OwnTracks';
  static const String packageName = 'com.cf.fivex.owntrack';

  // Database
  static const String databaseName = 'owntrack.db';
  static const int databaseVersion = 1;

  // Preferences Keys
  static const String prefKeyMonitoringMode = 'monitoring_mode';
  static const String prefKeyMqttHost = 'mqtt_host';
  static const String prefKeyMqttPort = 'mqtt_port';
  static const String prefKeyMqttUseTls = 'mqtt_use_tls';
  static const String prefKeyMqttUsername = 'mqtt_username';
  static const String prefKeyMqttPassword = 'mqtt_password';
  static const String prefKeyMqttClientId = 'mqtt_client_id';
  static const String prefKeyHttpUrl = 'http_url';
  static const String prefKeyConnectionMode = 'connection_mode';
  static const String prefKeyEncryptionKey = 'encryption_key';
  static const String prefKeyDeviceId = 'device_id';
  static const String prefKeyTrackerId = 'tracker_id';

  // Location
  static const int monitoringModeQuiet = -1;
  static const int monitoringModeManual = 0;
  static const int monitoringModeSignificant = 1;
  static const int monitoringModeMove = 2;

  // Defaults
  static const int defaultMqttPort = 1883;
  static const int defaultMqttTlsPort = 8883;
  static const Duration defaultLocationUpdateInterval = Duration(minutes: 5);
  static const double defaultLocationAccuracyThreshold = 50.0; // meters

  // MQTT
  static const Duration mqttKeepAlivePeriod = Duration(seconds: 60);
  static const Duration mqttConnectionTimeout = Duration(seconds: 30);
  static const int mqttQos = 1;

  // Message Types
  static const String messageTypeLocation = 'location';
  static const String messageTypeTransition = 'transition';
  static const String messageTypeWaypoint = 'waypoint';
  static const String messageTypeConfiguration = 'configuration';
  static const String messageTypeCmd = 'cmd';
  static const String messageTypeLwt = 'lwt';
  static const String messageTypeCard = 'card';

  // Connection Modes
  static const String connectionModeMqtt = 'mqtt';
  static const String connectionModeHttp = 'http';

  // App Groups (iOS)
  static const String appGroup = 'group.com.cf.fivex.owntrack';

  // Notification
  static const String notificationChannelId = 'owntracks_location_service';
  static const String notificationChannelName = 'Location Tracking';
  static const int foregroundServiceNotificationId = 1;
}
