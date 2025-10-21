import 'package:owntrack/data/services/battery_service.dart';

/// Stub implementation for non-web platforms
class BatteryServiceWeb {
  static Future<bool> isSupported() async => false;

  static Future<BatteryInfo> getBatteryInfo() async {
    return const BatteryInfo(
      level: 85,
      state: BatteryState.discharging,
    );
  }

  static void addBatteryListeners(Function(BatteryInfo) onBatteryChange) {
    // No-op on non-web platforms
  }
}
