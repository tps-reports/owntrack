import 'dart:async';

import 'package:owntrack/core/utils/app_logger.dart';

/// Battery state
enum BatteryState {
  full,
  charging,
  discharging,
  unknown,
}

/// Battery information
class BatteryInfo {
  final int level; // 0-100
  final BatteryState state;

  const BatteryInfo({
    required this.level,
    required this.state,
  });

  bool get isCharging =>
      state == BatteryState.charging || state == BatteryState.full;

  bool get isLowBattery => level < 20;

  bool get isCriticalBattery => level < 10;
}

/// Battery monitoring service
///
/// Monitors device battery level and charging state.
/// Provides battery information for location messages.
class BatteryService {
  BatteryInfo? _lastBatteryInfo;
  Timer? _batteryTimer;

  final StreamController<BatteryInfo> _batteryController =
      StreamController<BatteryInfo>.broadcast();

  /// Stream of battery updates
  Stream<BatteryInfo> get batteryUpdates => _batteryController.stream;

  /// Last known battery info
  BatteryInfo? get lastBatteryInfo => _lastBatteryInfo;

  /// Start monitoring battery
  void startMonitoring() {
    AppLogger.i('Starting battery monitoring');

    // Get initial battery state
    _updateBatteryInfo();

    // Check battery every 5 minutes
    _batteryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updateBatteryInfo();
    });
  }

  /// Stop monitoring battery
  void stopMonitoring() {
    AppLogger.i('Stopping battery monitoring');
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  /// Update battery information
  Future<void> _updateBatteryInfo() async {
    try {
      // In a real implementation, you would use battery_plus package
      // or platform channels to get actual battery information.
      // For now, we'll simulate it.

      final batteryInfo = await _getBatteryInfo();
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
    // TODO: Implement actual battery monitoring using battery_plus package
    // or platform channels. For now, return simulated data.

    // Simulated battery data
    return const BatteryInfo(
      level: 85,
      state: BatteryState.discharging,
    );
  }

  /// Get current battery level (0-100)
  int get batteryLevel => _lastBatteryInfo?.level ?? 100;

  /// Check if device is charging
  bool get isCharging => _lastBatteryInfo?.isCharging ?? false;

  /// Check if battery is low
  bool get isLowBattery => _lastBatteryInfo?.isLowBattery ?? false;

  /// Clean up resources
  void dispose() {
    _batteryTimer?.cancel();
    _batteryController.close();
  }
}
