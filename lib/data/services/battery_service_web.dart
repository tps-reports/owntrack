import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/services/battery_service.dart';
import 'package:web/web.dart' as web;

/// Web-specific battery implementation using Battery Status API
///
/// Uses the browser's Battery Status API when available.
/// Falls back to default values if not supported.
///
/// See: https://developer.mozilla.org/en-US/docs/Web/API/Battery_Status_API
class BatteryServiceWeb {
  static JSObject? _batteryManager;
  static bool _isSupported = false;
  static bool _initialized = false;

  /// Check if Battery Status API is supported
  static Future<bool> isSupported() async {
    if (_initialized) {
      return _isSupported;
    }

    try {
      final navigator = web.window.navigator;

      // Check if getBattery method exists on navigator
      final hasGetBattery = navigator.has('getBattery');

      if (!hasGetBattery) {
        AppLogger.w('Battery Status API not supported in this browser');
        _isSupported = false;
        _initialized = true;
        return false;
      }

      // Try to get the battery manager
      final getBatteryFunction = navigator['getBattery'] as JSFunction;
      final promise = getBatteryFunction.callAsFunction(navigator) as JSPromise;

      _batteryManager = await promise.toDart as JSObject;
      _isSupported = true;
      _initialized = true;

      AppLogger.i('Battery Status API is supported and initialized');
      return true;
    } catch (e) {
      AppLogger.w('Battery Status API not available: $e');
      _isSupported = false;
      _initialized = true;
      return false;
    }
  }

  /// Get current battery information from the Battery Status API
  static Future<BatteryInfo> getBatteryInfo() async {
    // Check if supported first
    final supported = await isSupported();

    if (!supported || _batteryManager == null) {
      // Return default values if not supported
      return const BatteryInfo(
        level: 100,
        state: BatteryState.unknown,
      );
    }

    try {
      // Read properties from battery manager
      final level = (_batteryManager!['level'] as JSNumber).toDartDouble;
      final charging = (_batteryManager!['charging'] as JSBoolean).toDart;

      // Convert level from 0.0-1.0 to 0-100
      final batteryLevel = (level * 100).round().clamp(0, 100);

      // Determine battery state
      BatteryState state;
      if (batteryLevel == 100 && charging) {
        state = BatteryState.full;
      } else if (charging) {
        state = BatteryState.charging;
      } else {
        state = BatteryState.discharging;
      }

      AppLogger.d('Web battery: $batteryLevel%, charging: $charging');

      return BatteryInfo(
        level: batteryLevel,
        state: state,
      );
    } catch (e) {
      AppLogger.e('Error reading battery status: $e');
      return const BatteryInfo(
        level: 100,
        state: BatteryState.unknown,
      );
    }
  }

  /// Add listeners for battery change events
  static void addBatteryListeners(Function(BatteryInfo) onBatteryChange) async {
    final supported = await isSupported();

    if (!supported || _batteryManager == null) {
      return;
    }

    try {
      // Create event listeners for battery changes
      final levelChangeCallback = ((JSAny? event) {
        getBatteryInfo().then((info) => onBatteryChange(info));
      }).toJS;

      final chargingChangeCallback = ((JSAny? event) {
        getBatteryInfo().then((info) => onBatteryChange(info));
      }).toJS;

      // Add event listeners
      _batteryManager!.callMethod('addEventListener'.toJS, 'levelchange'.toJS, levelChangeCallback);
      _batteryManager!.callMethod('addEventListener'.toJS, 'chargingchange'.toJS, chargingChangeCallback);

      AppLogger.d('Battery event listeners added');
    } catch (e) {
      AppLogger.e('Error adding battery listeners: $e');
    }
  }
}
