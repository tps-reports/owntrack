import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:owntrack/app.dart';
import 'package:owntrack/core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  AppLogger.i('OwnTracks application starting...');

  // Run app with Riverpod
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
