import 'package:owntrack/data/services/battery_service.dart';

/// Battery readings are unavailable through this adapter on native platforms.
class BatteryServiceWeb {
  static Future<BatteryInfo> getBatteryInfo() async =>
      const BatteryInfo(level: null, state: BatteryState.unknown);
}
