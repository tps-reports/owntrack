import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:owntrack/app.dart';
import 'package:owntrack/core/utils/app_logger.dart';
import 'package:owntrack/data/datasources/local/preferences/settings_local_datasource.dart';
import 'package:owntrack/domain/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  AppLogger.i('OwnTracks application starting...');

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  AppLogger.i('SharedPreferences initialized');

  // Create settings local data source
  final settingsLocalDataSource = SettingsLocalDataSource(prefs);

  // Run app with Riverpod and override the settings data source
  runApp(
    ProviderScope(
      overrides: [
        settingsLocalDataSourceProvider.overrideWithValue(settingsLocalDataSource),
      ],
      child: const App(),
    ),
  );
}
