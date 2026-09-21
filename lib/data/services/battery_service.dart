import 'dart:async';

import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/core/utils/platform_utils.dart';

// Conditional import: use web implementation on web, stub on other platforms
import 'package:owntrack/data/services/battery_service_stub.dart'
    if (dart.library.js_interop) 'package:owntrack/data/services/battery_service_web.dart';

/// Battery state
enum BatteryState { full, charging, discharging, unknown }

/// Battery information
class BatteryInfo {
  final int? level; // 0-100
  final BatteryState state;

  const BatteryInfo({required this.level, required this.state});

  bool get isCharging =>
      state == BatteryState.charging || state == BatteryState.full;

  bool get isLowBattery => level != null && level! < 20;

  bool get isCriticalBattery => level != null && level! < 10;
}

/// Battery monitoring service
///
/// Monitors device battery level and charging state.
/// Provides battery information for location messages.
///
/// **Web Platform Notes:**
/// - Uses Battery Status API when available (with feature detection)
/// - Falls back to default values if API is not supported
/// - Some browsers have deprecated the API for privacy reasons
class BatteryService {
  BatteryInfo? _lastBatteryInfo;
  Timer? _batteryTimer;
  bool _disposed = false;
  int _generation = 0;

  final StreamController<BatteryInfo> _batteryController =
      StreamController<BatteryInfo>.broadcast();

  /// Stream of battery updates
  Stream<BatteryInfo> get batteryUpdates => _batteryController.stream;

  /// Last known battery info
  BatteryInfo? get lastBatteryInfo => _lastBatteryInfo;

  /// Start monitoring battery
  void startMonitoring() {
    if (_disposed || _batteryTimer != null) return;
    _updateBatteryInfo();

    // Check battery every 5 minutes (fallback polling)
    _batteryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateBatteryInfo();
    });
  }

  /// Stop monitoring battery
  void stopMonitoring() {
    _generation++;
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  /// Update battery information
  Future<void> _updateBatteryInfo() async {
    final generation = _generation;
    try {
      final batteryInfo = await _getBatteryInfo();
      if (_disposed || generation != _generation) return;
      _lastBatteryInfo = batteryInfo;
      _batteryController.add(batteryInfo);

      AppLogger.d(
        'Battery update: ${batteryInfo.level}%, '
        'state: ${batteryInfo.state}',
      );
    } catch (e) {
      AppLogger.e('Error updating battery info: $e');
    }
  }

  /// Get current battery information
  Future<BatteryInfo> _getBatteryInfo() async {
    if (PlatformUtils.isWeb) return BatteryServiceWeb.getBatteryInfo();
    return const BatteryInfo(level: null, state: BatteryState.unknown);
  }

  /// Null means that the operating system has not supplied a battery reading.
  int? get batteryLevel => _lastBatteryInfo?.level;

  /// Check if device is charging
  bool get isCharging => _lastBatteryInfo?.isCharging ?? false;

  /// Check if battery is low
  bool get isLowBattery => _lastBatteryInfo?.isLowBattery ?? false;

  /// Clean up resources
  void dispose() {
    _disposed = true;
    stopMonitoring();
    _batteryController.close();
  }
}
