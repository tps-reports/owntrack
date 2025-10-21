import 'package:flutter_test/flutter_test.dart';
import 'package:owntrack/data/services/battery_service.dart';

void main() {
  group('BatteryService', () {
    late BatteryService service;

    setUp(() {
      service = BatteryService();
    });

    tearDown(() {
      service.dispose();
    });

    group('BatteryInfo', () {
      test('should have correct properties', () {
        const info = BatteryInfo(
          level: 85,
          state: BatteryState.discharging,
        );

        expect(info.level, equals(85));
        expect(info.state, equals(BatteryState.discharging));
        expect(info.isCharging, isFalse);
        expect(info.isLowBattery, isFalse);
        expect(info.isCriticalBattery, isFalse);
      });

      test('should detect low battery', () {
        const info = BatteryInfo(
          level: 15,
          state: BatteryState.discharging,
        );

        expect(info.isLowBattery, isTrue);
        expect(info.isCriticalBattery, isFalse);
      });

      test('should detect critical battery', () {
        const info = BatteryInfo(
          level: 5,
          state: BatteryState.discharging,
        );

        expect(info.isLowBattery, isTrue);
        expect(info.isCriticalBattery, isTrue);
      });

      test('should detect charging', () {
        const info = BatteryInfo(
          level: 50,
          state: BatteryState.charging,
        );

        expect(info.isCharging, isTrue);
      });

      test('should detect full battery as charging', () {
        const info = BatteryInfo(
          level: 100,
          state: BatteryState.full,
        );

        expect(info.isCharging, isTrue);
      });
    });

    group('monitoring', () {
      test('should start and stop monitoring', () {
        service.startMonitoring();
        service.stopMonitoring();
        expect(service.batteryLevel, isA<int>());
      });

      test('should provide battery level', () {
        expect(service.batteryLevel, isA<int>());
        expect(service.batteryLevel, greaterThanOrEqualTo(0));
        expect(service.batteryLevel, lessThanOrEqualTo(100));
      });

      test('should provide charging status', () {
        expect(service.isCharging, isA<bool>());
      });

      test('should provide low battery status', () {
        expect(service.isLowBattery, isA<bool>());
      });
    });

    group('battery updates stream', () {
      test('should have broadcast stream', () {
        final subscription1 = service.batteryUpdates.listen((_) {});
        final subscription2 = service.batteryUpdates.listen((_) {});

        expect(subscription1, isNotNull);
        expect(subscription2, isNotNull);

        subscription1.cancel();
        subscription2.cancel();
      });
    });
  });
}
