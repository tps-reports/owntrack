import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/services/message_processor.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/settings/outbox_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore implements OutboxStore {
  String? value;
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> compareAndSet(String? expected, String next) async {
    if (failWrites) throw StateError('Disk full');
    if (value != expected) return false;
    value = next;
    return true;
  }

  @override
  Future<void> close() async {}
}

class _MockProcessor extends Mock implements MessageProcessor {}

void main() {
  late _MemoryStore store;
  late MessageQueueRepository queue;
  late _MockProcessor processor;

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    store = _MemoryStore();
    queue = await MessageQueueRepository.open(
      SettingsLocalDataSource(await SharedPreferences.getInstance()),
      store: store,
    );
    processor = _MockProcessor();
    when(processor.currentDestination).thenAnswer((_) async => 'current');
    when(processor.retryDelivery).thenAnswer((_) async {});
    when(() => processor.lastError).thenReturn(null);
  }

  Future<void> open(
    WidgetTester tester, {
    Future<ShareResult> Function(ShareParams)? share,
    double textScale = 1,
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      final closing = queue.close();
      await tester.pump();
      await closing;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messageQueueRepositoryProvider.overrideWithValue(queue),
          messageProcessorProvider.overrideWithValue(processor),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: OutboxScreen(share: share),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, int id) async {
    final row = find.byKey(ValueKey('outbox-message-$id'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('shows truthful recovery statuses without location previews', (
    tester,
  ) async {
    await initialize();
    await queue.enqueue('owntracks/private/phone', '{"lat":42.4321}');
    await queue.enqueue(
      'secret-topic',
      'private-ciphertext',
      destination: 'old',
    );
    final current = await queue.enqueue('a', '{}', destination: 'current');
    await queue.incrementRetry(current, retryAt: 4102444800);
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await open(tester);

    expect(find.textContaining('Legacy message'), findsOneWidget);
    expect(
      find.textContaining('Restore the original connection'),
      findsOneWidget,
    );
    expect(find.textContaining('Waiting to retry'), findsOneWidget);
    expect(find.textContaining('Retry attempts: 1'), findsOneWidget);
    expect(find.textContaining('42.4321'), findsNothing);
    expect(find.textContaining('private-ciphertext'), findsNothing);
    expect(find.textContaining('secret-topic'), findsNothing);
  });

  testWidgets('export requires privacy confirmation and preserves payload', (
    tester,
  ) async {
    await initialize();
    final id = await queue.enqueue('a', '{"lat":42.4321}', destination: 'old');
    ShareParams? shared;
    await open(
      tester,
      share: (params) async {
        shared = params;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    await select(tester, id);
    await tapAction(tester, 'Export selected');
    expect(shared, isNull);
    expect(find.textContaining('private location history'), findsOneWidget);
    await tester.tap(find.text('Continue to export'));
    await tester.pumpAndSettle();

    expect(shared, isNotNull);
    final exported = jsonDecode(await shared!.files!.single.readAsString());
    expect(exported['messages'].single['payload'], '{"lat":42.4321}');
    expect(shared!.files!.single.mimeType, 'application/json');
    expect(shared!.fileNameOverrides!.single, endsWith('.json'));
    expect(shared!.sharePositionOrigin!.isEmpty, isFalse);
    expect(queue.getAllMessages().single.id, id);
  });

  testWidgets('cancelling export does not open sharing or remove messages', (
    tester,
  ) async {
    await initialize();
    final id = await queue.enqueue('a', '{}');
    var shared = false;
    await open(
      tester,
      share: (params) async {
        shared = true;
        return const ShareResult('', ShareResultStatus.success);
      },
    );
    await select(tester, id);
    await tapAction(tester, 'Export selected');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(shared, isFalse);
    expect(queue.size, 1);
  });

  testWidgets('share failure keeps records and displays a recoverable error', (
    tester,
  ) async {
    await initialize();
    final id = await queue.enqueue('a', '{"lat":42.4321}');
    await open(
      tester,
      share: (params) async {
        throw StateError('Sensitive plugin detail: 42.4321');
      },
    );
    await select(tester, id);
    await tapAction(tester, 'Export selected');
    await tester.tap(find.text('Continue to export'));
    await tester.pumpAndSettle();

    expect(queue.size, 1);
    expect(find.textContaining('Unable to export'), findsOneWidget);
    expect(find.textContaining('42.4321'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Export selected'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'discard removes confirmed IDs and preserves a concurrent arrival',
    (tester) async {
      await initialize();
      final first = await queue.enqueue('a', 'first');
      await open(tester);
      await select(tester, first);
      await tapAction(tester, 'Discard selected');
      final second = await queue.enqueue('a', 'second');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard permanently'));
      await tester.pumpAndSettle();

      expect(queue.getAllMessages().map((message) => message.id), [second]);
      expect(find.textContaining('1 message discarded'), findsOneWidget);
    },
  );

  testWidgets('failed discard remains visible and can be retried', (
    tester,
  ) async {
    await initialize();
    final id = await queue.enqueue('a', 'first');
    await open(tester);
    await select(tester, id);
    await tapAction(tester, 'Discard selected');
    store.failWrites = true;
    await tester.tap(find.text('Discard permanently'));
    await tester.pumpAndSettle();

    expect(queue.size, 1);
    expect(find.textContaining('Unable to discard'), findsOneWidget);
    store.failWrites = false;
    await tapAction(tester, 'Discard selected');
    await tester.tap(find.text('Discard permanently'));
    await tester.pumpAndSettle();
    expect(queue.isEmpty, isTrue);
  });

  testWidgets('retry calls delivery and surfaces its connection failure', (
    tester,
  ) async {
    await initialize();
    await queue.enqueue('a', '{}', destination: 'current');
    when(() => processor.lastError).thenReturn('Connection unavailable.');
    await open(tester);
    await tapAction(tester, 'Retry delivery');
    verify(processor.retryDelivery).called(1);
    expect(find.text('Connection unavailable.'), findsOneWidget);
    expect(queue.size, 1);
  });

  testWidgets('refresh failure is visible and reloads after storage recovers', (
    tester,
  ) async {
    await initialize();
    await queue.enqueue('a', '{}');
    store.failWrites = true;
    await open(tester);
    expect(find.textContaining('Unable to refresh'), findsOneWidget);
    store.failWrites = false;
    await tester.tap(find.byTooltip('Refresh outbox'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to refresh'), findsNothing);
    expect(find.text('Message 1'), findsOneWidget);
  });

  testWidgets('queue stream updates and large text fits a narrow viewport', (
    tester,
  ) async {
    await initialize();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, textScale: 2);
    expect(find.text('No queued messages'), findsOneWidget);
    final id = await queue.enqueue('a', '{}', destination: 'current');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('outbox-message-$id')),
      250,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Message $id'), findsOneWidget);
  });
}
