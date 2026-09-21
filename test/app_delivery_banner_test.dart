import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/app.dart';
import 'package:owntrack/core/router/app_router.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/services/message_processor.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

class _Queue extends Mock implements MessageQueueRepository {}

class _Processor extends Mock implements MessageProcessor {}

void main() {
  testWidgets(
    'large delivery banner leaves room for navigation and opens outbox once',
    (tester) async {
      tester.view.physicalSize = const Size(480, 320);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final queue = _Queue();
      when(queue.getAllMessages).thenReturn([]);
      when(() => queue.changes).thenAnswer((_) => const Stream.empty());
      when(queue.refresh).thenAnswer((_) async {});
      final processor = _Processor();
      when(processor.currentDestination).thenAnswer((_) async => 'current');
      goRouter.go(AppRoutes.settings);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationRuntimeProvider.overrideWith((ref) async {}),
            deliveryErrorProvider.overrideWith(
              (ref) => Stream.value(
                'Queued messages blocked. Restore the original connection and encryption settings to deliver them. Open Outbox to export or discard selected records.',
              ),
            ),
            queueSizeProvider.overrideWith((ref) => Stream.value(1)),
            messageQueueRepositoryProvider.overrideWithValue(queue),
            messageProcessorProvider.overrideWithValue(processor),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Settings'), findsOneWidget);
      await tester.ensureVisible(find.text('Open Outbox'));
      await tester.tap(find.text('Open Outbox'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Outbox open'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Outbox open'))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      goRouter.go(AppRoutes.home);
    },
  );
}
