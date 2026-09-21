import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:owntrack/app.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store.dart';
import 'package:owntrack/data/datasources/outbox/outbox_store_factory.dart';
import 'package:owntrack/data/repositories/message_queue_repository.dart';
import 'package:owntrack/data/repositories/settings_repository.dart';
import 'package:owntrack/data/services/secrets/secret_store.dart';
import 'package:owntrack/domain/providers/app_providers.dart';
import 'package:owntrack/presentation/screens/settings/credential_conflict_screen.dart';

typedef ApplicationDependencies = ({
  SettingsLocalDataSource dataSource,
  SettingsRepository settings,
  MessageQueueRepository queue,
});

Future<ApplicationDependencies> initializeApplication({
  SharedPreferences? preferences,
  Future<SecretStore> Function()? openSecrets,
  OutboxStore? outboxStore,
}) async {
  final loadedPreferences =
      preferences ?? await SharedPreferences.getInstance();
  // SharedPreferences updates its cache before a platform write completes.
  // A retry must inspect durable values after failed credential cleanup.
  await loadedPreferences.reload();
  final dataSource = SettingsLocalDataSource(loadedPreferences);
  final secrets = await (openSecrets ?? openPlatformSecretStore)();
  final settings = SettingsRepository(dataSource, secretStore: secrets);
  await settings.migrateSecrets();
  final queue = await MessageQueueRepository.open(
    dataSource,
    store: outboxStore ?? createOutboxStore(),
  );
  return (dataSource: dataSource, settings: settings, queue: queue);
}

/// Initialization errors leave the app recoverable without exposing credentials.
class ApplicationBootstrap extends StatefulWidget {
  final Future<ApplicationDependencies> Function() initialize;
  const ApplicationBootstrap({
    super.key,
    this.initialize = initializeApplication,
  });
  @override
  State<ApplicationBootstrap> createState() => _ApplicationBootstrapState();
}

class _ApplicationBootstrapState extends State<ApplicationBootstrap> {
  late Future<ApplicationDependencies?> _loading;
  CredentialMigrationConflict? _credentialConflict;
  bool _initializing = false;

  Future<ApplicationDependencies?> _load() async {
    _initializing = true;
    _credentialConflict = null;
    try {
      return await widget.initialize();
    } on CredentialMigrationConflict catch (conflict) {
      _credentialConflict = conflict;
      return null;
    } catch (_) {
      AppLogger.e('Application storage initialization failed.');
      return null;
    } finally {
      _initializing = false;
    }
  }

  void _reload() {
    if (_initializing) return;
    setState(() {
      _loading = _load();
    });
  }

  @override
  void initState() {
    super.initState();
    _loading = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ApplicationDependencies?>(
    future: _loading,
    builder: (context, snapshot) {
      final dependencies = snapshot.data;
      if (dependencies != null) {
        return ProviderScope(
          overrides: [
            settingsLocalDataSourceProvider.overrideWithValue(
              dependencies.dataSource,
            ),
            settingsRepositoryProvider.overrideWithValue(dependencies.settings),
            messageQueueRepositoryProvider.overrideWithValue(
              dependencies.queue,
            ),
          ],
          child: const App(),
        );
      }
      final conflict = _credentialConflict;
      if (snapshot.connectionState == ConnectionState.done &&
          conflict != null) {
        return MaterialApp(
          home: CredentialConflictScreen(
            key: ValueKey(conflict),
            conflict: conflict,
            onReload: _reload,
          ),
        );
      }
      return MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: snapshot.connectionState == ConnectionState.done
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Unable to open secure settings or message storage.',
                            ),
                            const Text(
                              'Unlock your device and retry. Existing records have been retained.',
                            ),
                            FilledButton(
                              onPressed: _initializing ? null : _reload,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const CircularProgressIndicator(
                      semanticsLabel: 'Opening saved settings',
                    ),
            ),
          ),
        ),
      );
    },
  );
}
