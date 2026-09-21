import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/core/router/app_router.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/theme/app_theme.dart';

/// Main application widget
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(applicationRuntimeProvider);
    final deliveryError = ref.watch(deliveryErrorProvider).asData?.value;
    final queued = ref.watch(queueSizeProvider).asData?.value ?? 0;
    return MaterialApp.router(
      title: 'OwnTracks',
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            if (deliveryError != null || queued > 0)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              deliveryError ??
                                  '$queued messages queued for delivery',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            ListenableBuilder(
                              listenable: goRouter.routerDelegate,
                              builder: (context, _) {
                                final open =
                                    goRouter.state.topRoute?.path ==
                                    AppRoutes.outbox;
                                return TextButton(
                                  onPressed: open
                                      ? null
                                      : () => goRouter.push(AppRoutes.outbox),
                                  child: Text(
                                    open ? 'Outbox open' : 'Open Outbox',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
    );
  }
}
