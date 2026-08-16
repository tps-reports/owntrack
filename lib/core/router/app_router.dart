import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:owntrack/presentation/screens/map/map_screen.dart';
import 'package:owntrack/presentation/screens/settings/settings_screen.dart';

/// Application routes
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String map = '/map';
  static const String contacts = '/contacts';
  static const String waypoints = '/waypoints';
  static const String regions = '/regions';
  static const String settings = '/settings';
  static const String status = '/status';
  static const String welcome = '/welcome';
}

/// Application router configuration
final goRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const MapScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.map,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const MapScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const SettingsScreen(),
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
